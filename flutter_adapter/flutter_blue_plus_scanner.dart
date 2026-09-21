import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:gshock_api_dart/gshock_api_dart.dart';

/// Concrete [GshockScanner] implementation backed by `flutter_blue_plus`.
///
/// Scans for Casio G-Shock watches advertising the Casio service UUID
/// (`00001804-0000-1000-8000-00805f9b34fb`) or names beginning with "CASIO".
class FlutterBluePlusScanner implements GshockScanner {
  const FlutterBluePlusScanner();

  @override
  Future<BleDevice?> scan({
    String? deviceAddress,
    bool Function(String name)? watchFilter,
    int? maxRetries = 3,
    Duration? timeout = const Duration(seconds: 10),
  }) async {
    // If an explicit address is provided, return directly without scanning
    if (deviceAddress != null && deviceAddress.isNotEmpty) {
      try {
        final dev = BluetoothDevice.fromId(deviceAddress);
        return BleDevice(
          name: dev.platformName.isNotEmpty ? dev.platformName : null,
          address: deviceAddress,
        );
      } catch (_) {
        return BleDevice(name: null, address: deviceAddress);
      }
    }

    final retries = maxRetries ?? 3;
    final scanTimeout = timeout ?? const Duration(seconds: 10);

    for (var attempt = 0; attempt < retries; attempt++) {
      try {
        // Ensure Bluetooth is turned on
        if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
          final state = await FlutterBluePlus.adapterState
              .where((s) => s == BluetoothAdapterState.on)
              .first
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () => BluetoothAdapterState.unavailable,
              );
          if (state != BluetoothAdapterState.on) {
            gshockLogger.warning(['Bluetooth adapter is not enabled']);
            return null;
          }
        }

        final completer = Completer<BleDevice?>();
        late StreamSubscription<List<ScanResult>> sub;

        sub = FlutterBluePlus.scanResults.listen((results) {
          for (final r in results) {
            final name = r.device.platformName.isNotEmpty
                ? r.device.platformName
                : r.advertisementData.advName;

            if (name.isEmpty) continue;

            if (watchFilter != null && !watchFilter(name)) {
              continue;
            }

            // Standard Casio watch name check
            if (name.toUpperCase().startsWith('CASIO') || watchFilter != null) {
              if (!completer.isCompleted) {
                completer.complete(
                  BleDevice(name: name, address: r.device.remoteId.str),
                );
              }
              break;
            }
          }
        });

        // Start scanning with Casio service UUID filter
        await FlutterBluePlus.startScan(
          withServices: [Guid(casioServiceUuid)],
          timeout: scanTimeout,
        );

        final device = await completer.future.timeout(
          scanTimeout,
          onTimeout: () => null,
        );

        await FlutterBluePlus.stopScan();
        await sub.cancel();

        if (device != null) {
          return device;
        }
      } catch (e) {
        gshockLogger.warning(['Scan attempt $attempt failed: $e']);
      }
    }

    return null;
  }
}
