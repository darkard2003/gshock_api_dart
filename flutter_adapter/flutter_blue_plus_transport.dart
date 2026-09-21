import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:gshock_api_dart/gshock_api_dart.dart';

/// Concrete [BleTransport] implementation backed by `flutter_blue_plus`.
///
/// Drop this file into your Flutter project or copy it into your app's
/// Bluetooth service layer.
class FlutterBluePlusTransport implements BleTransport {
  FlutterBluePlusTransport({BluetoothDevice? device}) {
    _device = device;
  }

  BluetoothDevice? _device;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSub;
  final Map<String, BluetoothCharacteristic> _characteristics =
      <String, BluetoothCharacteristic>{};
  final Map<String, StreamSubscription<List<int>>> _subscriptions =
      <String, StreamSubscription<List<int>>>{};

  bool _connected = false;

  @override
  void Function(String? reason)? onDisconnected;

  @override
  bool get isConnected => _connected && (_device?.isConnected ?? false);

  @override
  String? get deviceName => _device?.platformName;

  /// The underlying [BluetoothDevice] instance.
  BluetoothDevice? get device => _device;

  @override
  Future<bool> connect(String address) async {
    try {
      final dev = _device ?? BluetoothDevice.fromId(address);
      _device = dev;

      // Listen for remote disconnection events (e.g. watch button press, link loss, idle timeout)
      await _connectionStateSub?.cancel();
      _connectionStateSub = dev.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          if (_connected) {
            _connected = false;
            final reason = dev.disconnectReason?.description;
            gshockLogger.info([
              'Watch disconnected: ${reason ?? "remote connection terminated"}',
            ]);
            onDisconnected?.call(reason);
          }
        }
      });

      // Connect with 15s timeout
      await dev.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      // Request MTU 512 on Android (iOS negotiates MTU automatically)
      if (Platform.isAndroid) {
        try {
          await dev.requestMtu(512);
        } catch (_) {
          // Ignorable: some Android devices or Casio watches reject MTU changes
        }
      }

      _connected = true;
      return true;
    } catch (e) {
      _connected = false;
      throw GShockConnectionException('Failed to connect to $address: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    try {
      await _connectionStateSub?.cancel();
      _connectionStateSub = null;

      for (final sub in _subscriptions.values) {
        await sub.cancel();
      }
      _subscriptions.clear();
      _characteristics.clear();

      if (_device != null) {
        await _device!.disconnect();
      }
    } catch (e) {
      gshockLogger.warning(['Disconnect error: $e']);
    }
  }

  @override
  Future<Map<String, bool>> discoverCharacteristics() async {
    final dev = _device;
    if (dev == null) {
      throw GShockConnectionException('No device configured for discovery');
    }

    try {
      final services = await dev.discoverServices();
      final result = <String, bool>{};

      for (final service in services) {
        for (final char in service.characteristics) {
          final uuid = char.characteristicUuid.str128.toLowerCase();
          _characteristics[uuid] = char;
          final canNotify = char.properties.notify || char.properties.indicate;
          result[uuid] = canNotify;
        }
      }

      return result;
    } catch (e) {
      throw GShockConnectionException('Failed to discover characteristics: $e');
    }
  }

  @override
  Future<void> subscribe(String uuid, void Function(Uint8List) onData) async {
    final normUuid = uuid.toLowerCase();
    final char = _characteristics[normUuid];
    if (char == null) {
      throw GShockConnectionException(
        'Characteristic $uuid not found for subscription',
      );
    }

    try {
      await char.setNotifyValue(true);
      await _subscriptions[normUuid]?.cancel();

      _subscriptions[normUuid] = char.onValueReceived.listen(
        (data) => onData(Uint8List.fromList(data)),
        onError: (Object error) {
          gshockLogger.warning(['Notification error on $uuid: $error']);
        },
      );
    } catch (e) {
      throw GShockConnectionException(
        'Failed to subscribe to characteristic $uuid: $e',
      );
    }
  }

  @override
  Future<void> write(
    String uuid,
    Uint8List data, {
    required bool withResponse,
  }) async {
    final normUuid = uuid.toLowerCase();
    final char = _characteristics[normUuid];
    if (char == null) {
      throw GShockConnectionException(
        'Characteristic $uuid not found for write',
      );
    }

    try {
      await char.write(data, withoutResponse: !withResponse, timeout: 15);
    } catch (e) {
      throw GShockConnectionException('Failed write to $uuid: $e');
    }
  }
}
