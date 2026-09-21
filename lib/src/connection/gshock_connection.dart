import 'dart:typed_data';

import '../constants/casio_constants.dart';
import '../dispatcher/message_dispatcher.dart';
import '../exceptions.dart';
import '../io/connection_protocol.dart';
import '../io/step_counter_io.dart';
import '../model/watch_info.dart';
import '../util/bytes.dart';
import '../util/logger.dart';
import 'gshock_scanner.dart';

/// Logical BLE connection to a G-Shock watch.
///
/// Implements handle -> UUID mapping, write normalization, notification
/// routing (including DRSP/Convoy bypass) and JSON action dispatch. Raw BLE
/// operations are delegated to a [BleTransport] adapter.
class GshockConnection implements ConnectionProtocol {
  static const Map<int, String> _defaultHandlesMap = <int, String>{
    0x04: CasioConstants.casioGetDeviceName,
    0x06: CasioConstants.casioAppearance,
    0x09: CasioConstants.txPowerLevelCharacteristicUuid,
    0x0C: CasioConstants.casioReadRequestForAllFeaturesCharacteristicUuid,
    0x0D: CasioConstants.casioNotificationCharacteristicUuid,
    0x0E: CasioConstants.casioAllFeaturesCharacteristicUuid,
    0x11: CasioConstants.casioDataRequestSpCharacteristicUuid,
    0x14: CasioConstants.casioConvoyCharacteristicUuid,
    0xFF: CasioConstants.serialNumberString,
    0x17: CasioConstants.casioSetConfigurationCharacteristicUuid,
    0x19: CasioConstants.casioGetConfigurationCharacteristicUuid,
  };

  GshockConnection({
    this.address,
    required this.transport,
    this.scanner,
    void Function(String? reason)? onDisconnected,
  }) : handlesMap = initHandlesMap() {
    if (onDisconnected != null) {
      this.onDisconnected = onDisconnected;
    }
  }

  String? address;
  final BleTransport transport;
  final GshockScanner? scanner;
  final Map<int, String> handlesMap;
  Set<String> characteristicsMap = <String>{};

  void Function(String? reason)? _onDisconnected;

  /// Optional callback invoked when the remote device disconnects.
  void Function(String? reason)? get onDisconnected => _onDisconnected;
  set onDisconnected(void Function(String? reason)? callback) {
    _onDisconnected = callback;
    transport.onDisconnected = callback;
  }

  // Handles that require write-without-response.
  static const Set<int> noResponseHandles = <int>{0x0C, 0x0D, 0x14, 0x17};

  static Map<int, String> initHandlesMap() =>
      Map<int, String>.unmodifiable(_defaultHandlesMap);

  /// Routes a notification for [uuid] to the correct IO handler.
  void handleNotification(String uuid, Uint8List data) {
    if (uuid == CasioConstants.casioDataRequestSpCharacteristicUuid) {
      StepCounterIO.onDrspReceived(data);
      return;
    }
    if (uuid == CasioConstants.casioConvoyCharacteristicUuid) {
      StepCounterIO.onReceived(data);
      return;
    }
    MessageDispatcher.onReceived(data);
  }

  Future<Map<String, bool>> initCharacteristicsMap() async {
    final discovered = await transport.discoverCharacteristics();
    characteristicsMap = discovered.keys.toSet();
    return discovered;
  }

  Future<bool> connect({
    bool Function(String name)? watchFilter,
    Duration? timeout,
  }) async {
    try {
      if (address == null) {
        final found = await scanner?.scan(
          watchFilter: watchFilter,
          timeout: timeout,
        );
        if (found == null) {
          gshockLogger.info([
            'No G-Shock device found or name matches excluded watches.',
          ]);
          return false;
        }
        address = found.address;
        if (found.name != null && found.name!.isNotEmpty) {
          watchInfo.setNameAndModel(found.name!);
        }
      }

      final addr = address;
      if (addr == null) return false;

      final connected = await transport.connect(addr);
      if (!connected || !transport.isConnected) {
        gshockLogger.info(['Failed to connect to $addr']);
        return false;
      }

      watchInfo.setAddress(addr);
      final discovered = await initCharacteristicsMap();

      for (final entry in discovered.entries) {
        if (!entry.value) continue;
        try {
          await transport.subscribe(
            entry.key,
            (data) => handleNotification(entry.key, data),
          );
          gshockLogger.info(['Subscribed to notifications: ${entry.key}']);
        } catch (e) {
          gshockLogger.debug(['subscribe failed for ${entry.key}: $e']);
        }
      }

      return true;
    } catch (e) {
      gshockLogger.info(['[GShock Connect] Connection failed: $e']);
      return false;
    }
  }

  Future<void> disconnect() async {
    if (transport.isConnected) {
      await transport.disconnect();
    }
  }

  @override
  Future<void> write(int handle, Object data) async {
    try {
      final uuid = handlesMap[handle];
      if (uuid == null || !characteristicsMap.contains(uuid)) {
        gshockLogger.info([
          'write failed: handle $handle not in characteristics map',
        ]);
        if (handle == 0x0D) {
          gshockLogger.info(['Your watch does not support notifications...']);
        }
        return;
      }

      final withResponse = !noResponseHandles.contains(handle);
      final Uint8List cmdData;
      if (data is Uint8List) {
        cmdData = data;
      } else if (data is String) {
        cmdData = Bytes.fromCasioCmd(data);
      } else if (data is List<int>) {
        cmdData = Uint8List.fromList(data);
      } else {
        cmdData = Uint8List.fromList((data as List).cast<int>());
      }

      await transport.write(uuid, cmdData, withResponse: withResponse);
    } catch (e, st) {
      if (e is GShockIgnorableException) rethrow;
      final hexHandle =
          '0x${handle.toRadixString(16).padLeft(2, '0').toUpperCase()}';
      throw GShockConnectionException(
        'Unable to write to watch handle $hexHandle: $e',
        e,
        st,
      );
    }
  }

  @override
  Future<void> request(Object code) async {
    await write(0x0C, code);
  }

  @override
  Future<void> sendMessage(Object message) async {
    await MessageDispatcher.sendToWatch(message);
  }
}

/// Deterministic in-memory transport for tests and non-BLE platforms.
class MockTransport implements BleTransport {
  MockTransport({Set<String>? availableUuids})
    : _availableUuids = availableUuids ?? _defaultUuids();

  final Set<String> _availableUuids;

  final List<MockWrite> writes = <MockWrite>[];
  final Map<String, void Function(Uint8List)> _subscriptions =
      <String, void Function(Uint8List)>{};
  void Function(String uuid, Uint8List data)? onWrite;

  @override
  void Function(String? reason)? onDisconnected;

  bool _connected = false;
  String? _address;
  String? _name;

  /// Simulates a remote disconnection event.
  void simulateDisconnect([String? reason]) {
    _connected = false;
    onDisconnected?.call(reason);
  }

  static Set<String> _defaultUuids() => <String>{
    CasioConstants.casioGetDeviceName,
    CasioConstants.casioAppearance,
    CasioConstants.txPowerLevelCharacteristicUuid,
    CasioConstants.casioReadRequestForAllFeaturesCharacteristicUuid,
    CasioConstants.casioNotificationCharacteristicUuid,
    CasioConstants.casioAllFeaturesCharacteristicUuid,
    CasioConstants.casioDataRequestSpCharacteristicUuid,
    CasioConstants.casioConvoyCharacteristicUuid,
    CasioConstants.serialNumberString,
    CasioConstants.casioSetConfigurationCharacteristicUuid,
    CasioConstants.casioGetConfigurationCharacteristicUuid,
  };

  @override
  Future<bool> connect(String address) async {
    _address = address;
    _connected = true;
    return true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  bool get isConnected => _connected;

  @override
  String? get deviceName => _name;

  void setDeviceName(String name) => _name = name;

  @override
  Future<Map<String, bool>> discoverCharacteristics() async {
    return <String, bool>{for (final uuid in _availableUuids) uuid: true};
  }

  @override
  Future<void> subscribe(String uuid, void Function(Uint8List) onData) async {
    _subscriptions[uuid] = onData;
  }

  @override
  Future<void> write(
    String uuid,
    Uint8List data, {
    required bool withResponse,
  }) async {
    writes.add(MockWrite(uuid: uuid, data: data, withResponse: withResponse));
    onWrite?.call(uuid, data);
  }

  /// Emits a notification on [uuid].
  void emit(String uuid, List<int> data) {
    _subscriptions[uuid]?.call(Uint8List.fromList(data));
  }

  void clearWrites() => writes.clear();

  String? get address => _address;
}

/// A recorded write.
class MockWrite {
  const MockWrite({
    required this.uuid,
    required this.data,
    required this.withResponse,
  });

  final String uuid;
  final Uint8List data;
  final bool withResponse;

  @override
  String toString() =>
      'MockWrite($uuid, ${Bytes.toHexString(data)}, withResponse=$withResponse)';
}
