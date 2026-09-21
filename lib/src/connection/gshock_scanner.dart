import 'dart:typed_data';

/// A discovered BLE device.
class BleDevice {
  const BleDevice({required this.name, required this.address});

  final String? name;
  final String address;
}

/// Scanner interface. Adapters (mock / flutter_blue_plus) implement this.
abstract class GshockScanner {
  Future<BleDevice?> scan({
    String? deviceAddress,
    bool Function(String name)? watchFilter,
    int? maxRetries,
    Duration? timeout,
  });
}

/// Standard BLE service UUID preserved from Python (sic).
const String casioServiceUuid = '00001804-0000-1000-8000-00805f9b34fb';

/// In-memory scanner for tests and non-BLE platforms.
class MockScanner implements GshockScanner {
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

/// Low-level BLE transport abstraction implemented by platform adapters.
abstract class BleTransport {
  Future<bool> connect(String address);
  Future<void> disconnect();
  bool get isConnected;
  String? get deviceName;

  /// Optional callback invoked when the remote device disconnects.
  void Function(String? reason)? onDisconnected;

  /// Returns a map of characteristic UUID -> whether it supports notify/indicate.
  Future<Map<String, bool>> discoverCharacteristics();

  Future<void> subscribe(String uuid, void Function(Uint8List) onData);

  Future<void> write(String uuid, Uint8List data, {required bool withResponse});
}
