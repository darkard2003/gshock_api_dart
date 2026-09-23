import 'dart:typed_data';

/// {@category Connection & Transport}
///
/// Representation of a discovered Bluetooth Low Energy peripheral.
class BleDevice {
  /// Creates a discovered device descriptor with [name] and [address].
  const BleDevice({required this.name, required this.address});

  /// The advertised name of the watch (e.g. `'CASIO GW-B5600'`), or `null` if unadvertised.
  final String? name;

  /// The MAC address (Linux/Android) or peripheral UUID (iOS/macOS).
  final String address;
}

/// {@category Connection & Transport}
///
/// Abstract scanner interface for discovering nearby Casio G-Shock watches.
///
/// Implementations filter advertised devices by Casio service UUID ([casioServiceUuid])
/// and match watch name prefixes.
abstract class GshockScanner {
  /// Scans for a nearby Casio G-Shock device.
  ///
  /// - [deviceAddress]: Specific MAC address or peripheral identifier to search for.
  /// - [watchFilter]: Optional predicate returning `true` for allowed watch names.
  /// - [maxRetries]: Maximum scan retry attempts.
  /// - [timeout]: Maximum duration to scan before aborting.
  Future<BleDevice?> scan({
    String? deviceAddress,
    bool Function(String name)? watchFilter,
    int? maxRetries,
    Duration? timeout,
  });
}

/// Standard Casio BLE primary service UUID used for advertisement filtering.
const String casioServiceUuid = '00001804-0000-1000-8000-00805f9b34fb';

/// In-memory [GshockScanner] test double for unit testing.
class MockScanner implements GshockScanner {
  /// Creates a mock scanner pre-configured with [device].
  MockScanner({this.device});

  /// Device to return, or `null` to simulate "not found".
  BleDevice? device;

  @override
  Future<BleDevice?> scan({
    String? deviceAddress,
    bool Function(String name)? watchFilter,
    int? maxRetries,
    Duration? timeout,
  }) async {
    final found = device;
    if (found == null) return null;
    if (deviceAddress != null) {
      return found.address == deviceAddress ? found : null;
    }
    if (watchFilter != null && !watchFilter(found.name ?? '')) {
      return null;
    }
    return found;
  }
}

/// {@category Connection & Transport}
///
/// Swappable low-level BLE transport abstraction implemented by platform adapters.
///
/// Decouples the pure-Dart library from specific platform BLE packages.
/// Available implementations:
/// - `FlutterBluePlusTransport` in `adapters/flutter_blue_plus/` (Flutter iOS/Android/macOS/Windows).
/// - `BluezTransport` in `adapters/linux_bluez/` (native Linux D-Bus).
/// - [MockTransport] (in-memory test double).
abstract class BleTransport {
  /// Connects to the peripheral at [address].
  Future<bool> connect(String address);

  /// Disconnects from the remote peripheral.
  Future<void> disconnect();

  /// Whether the transport currently maintains an active BLE link.
  bool get isConnected;

  /// The advertised or discovered name of the connected peripheral.
  String? get deviceName;

  /// Optional callback invoked when the peripheral disconnects.
  void Function(String? reason)? onDisconnected;

  /// Discovers all available characteristics on the peripheral.
  ///
  /// Returns a map of characteristic UUID -> whether it supports notify or indicate.
  Future<Map<String, bool>> discoverCharacteristics();

  /// Subscribes to notification/indication data on the characteristic identified by [uuid].
  Future<void> subscribe(String uuid, void Function(Uint8List) onData);

  /// Writes [data] to the characteristic identified by [uuid].
  ///
  /// When [withResponse] is `false`, performs a write-without-response.
  Future<void> write(String uuid, Uint8List data, {required bool withResponse});
}
