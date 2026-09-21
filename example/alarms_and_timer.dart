import 'dart:io';
import 'dart:typed_data';

import 'package:gshock_api_dart/gshock_api_dart.dart';

/// Example showing how to read and configure watch alarms and countdown timer.
///
/// Usage:
///   dart run example/alarms_and_timer.dart [--mock] [--address AA:BB:CC:DD:EE:FF]
Future<void> main(List<String> args) async {
  final isMock = args.contains('--mock');
  final address =
      args.contains('--address') && args.indexOf('--address') + 1 < args.length
      ? args[args.indexOf('--address') + 1]
      : null;

  stdout.writeln('Connecting to G-Shock watch...');

  final targetAddress = address ?? (isMock ? 'AA:BB:CC:DD:EE:FF' : null);

  final BleTransport transport = isMock
      ? MockTransport()
      : BluezTransport(deviceAddress: targetAddress);

  final connection = GshockConnection(
    address: targetAddress,
    transport: transport,
    scanner: isMock ? null : const BluezScanner(),
  );

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
        } else if (code == 0x15) {
          // Primary alarm: 0x15, 0x40 (flags), 0x40 (const), hour, min
          transport.emit(
            CasioConstants.casioNotificationCharacteristicUuid,
            Uint8List.fromList(<int>[
              0x15,
              0x40, 0x40, 6, 30, // Alarm 1: 06:30
            ]),
          );
        } else if (code == 0x16) {
          // Secondary alarms (4 alarms): 0x16, then 4 x (flag, constant, hour, min)
          transport.emit(
            CasioConstants.casioNotificationCharacteristicUuid,
            Uint8List.fromList(<int>[
              0x16,
              0x40, 0x40, 7, 00, // Alarm 2: 07:00
              0x00, 0x40, 8, 15, // Alarm 3: 08:15
              0x00, 0x40, 9, 45, // Alarm 4: 09:45
              0x00, 0x40, 18, 00, // Alarm 5: 18:00
            ]),
          );
        } else if (code == 0x18) {
          // Timer: 18 00 00 00 05 00 (300 seconds)
          transport.emit(
            CasioConstants.casioNotificationCharacteristicUuid,
            Uint8List.fromList(<int>[0x18, 0x00, 0x00, 0x00, 0x05, 0x00]),
          );
        }
      }
    };
  }

  final connected = await connection.connect(
    timeout: const Duration(seconds: 15),
  );

  if (!connected) {
    stderr.writeln('Could not connect to watch.');
    return;
  }

  try {
    final api = GshockApi(connection);
    final name = await api.getWatchName();
    stdout.writeln('Connected: $name');

    // 1. Read existing alarms from watch
    stdout.writeln('\n--- Alarms ---');
    final alarms = await api.getAlarms();
    for (var i = 0; i < alarms.length; i++) {
      final a = alarms[i];
      stdout.writeln(
        'Alarm #$i: ${a['hour'].toString().padLeft(2, '0')}:${a['minute'].toString().padLeft(2, '0')} '
        '(enabled: ${a['enabled']}, chime: ${a['hasHourlyChime']})',
      );
    }

    // 2. Configure new alarms
    final newAlarms = <Map<String, Object?>>[
      const Alarm(
        hour: 7,
        minute: 0,
        enabled: true,
        hasHourlyChime: true,
      ).toJson(),
      const Alarm(hour: 8, minute: 30, enabled: false).toJson(),
    ];
    stdout.writeln('Writing updated alarm settings...');
    await api.setAlarms(newAlarms);
    stdout.writeln('Alarms updated.');

    // 3. Read and update countdown timer
    stdout.writeln('\n--- Timer ---');
    final timerSeconds = await api.getTimer();
    stdout.writeln(
      'Current timer: ${timerSeconds ~/ 60}m ${timerSeconds % 60}s ($timerSeconds total seconds)',
    );

    const newTimerSeconds = 600; // 10 minutes
    stdout.writeln(
      'Setting countdown timer to 10 minutes ($newTimerSeconds s)...',
    );
    await api.setTimer(newTimerSeconds);
    stdout.writeln('Timer configured successfully.');
  } finally {
    await connection.disconnect();
    watchInfo.reset();
    stdout.writeln('\nDisconnected from watch.');
  }
}
