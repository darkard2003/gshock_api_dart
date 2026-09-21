import 'dart:io';
import 'dart:typed_data';

import 'package:gshock_api_dart/gshock_api_dart.dart';

/// Minimal example: Connects to a Casio G-Shock watch, synchronizes the current
/// clock time, reads battery status, and disconnects.
///
/// Usage:
///   dart run example/sync_time_simple.dart [--mock] [--address AA:BB:CC:DD:EE:FF]
Future<void> main(List<String> args) async {
  final isMock = args.contains('--mock');
  final address =
      args.contains('--address') && args.indexOf('--address') + 1 < args.length
      ? args[args.indexOf('--address') + 1]
      : null;

  stdout.writeln('Connecting to G-Shock watch...');

  final targetAddress = address ?? (isMock ? 'AA:BB:CC:DD:EE:FF' : null);

  // 1. Setup transport (BluezTransport for Linux CLI, FlutterBluePlus for mobile, Mock for tests)
  final BleTransport transport = isMock
      ? MockTransport()
      : BluezTransport(deviceAddress: targetAddress);

  final connection = GshockConnection(
    address: targetAddress,
    transport: transport,
    scanner: isMock ? null : const BluezScanner(),
  );

  // 2. Configure mock responses if running without hardware
  if (isMock) {
    watchInfo.setNameAndModel('CASIO GW-B5600');
    (transport as MockTransport).onWrite = (uuid, data) {
      if (uuid ==
              CasioConstants.casioReadRequestForAllFeaturesCharacteristicUuid &&
          data.isNotEmpty) {
        final code = data[0];
        if (code == 0x23) {
          transport.emit(
            CasioConstants.casioNotificationCharacteristicUuid,
            Uint8List.fromList(<int>[
              0x23,
              ...'CASIO GW-B5600'.codeUnits,
              0x00,
            ]),
          );
        } else if (code == 0x28) {
          transport.emit(
            CasioConstants.casioNotificationCharacteristicUuid,
            Uint8List.fromList(<int>[0x28, 9, 21]),
          );
        } else if (code == 0x1D) {
          transport.emit(
            CasioConstants.casioNotificationCharacteristicUuid,
            Uint8List.fromList(<int>[0x1D, 0x00, 0x00, 0x01, 0x00]),
          );
        } else if (code == 0x1E) {
          transport.emit(
            CasioConstants.casioNotificationCharacteristicUuid,
            Uint8List.fromList(<int>[0x1E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]),
          );
        } else if (code == 0x1F || code == 0x24) {
          transport.emit(
            CasioConstants.casioNotificationCharacteristicUuid,
            Uint8List.fromList(<int>[code, 0x00, ...'LONDON'.codeUnits, 0x00]),
          );
        }
      }
    };
  }

  // 3. Connect to the watch
  final connected = await connection.connect(
    timeout: const Duration(seconds: 60),
  );

  if (!connected) {
    stderr.writeln('Failed to find or connect to watch.');
    return;
  }

  try {
    // 3. Create the API facade
    final api = GshockApi(connection);

    final name = await api.getWatchName();
    stdout.writeln('Connected to: $name');

    // 4. Synchronize time
    stdout.writeln('Setting watch time to current clock...');
    await api.setTime();
    stdout.writeln('Time successfully synchronized!');

    // 5. Check battery and temperature condition
    final condition = await api.getWatchCondition();
    stdout.writeln('Watch condition: $condition');
  } finally {
    // 6. Disconnect cleanly
    await connection.disconnect();
    watchInfo.reset();
    stdout.writeln('Disconnected.');
  }
}
