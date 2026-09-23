import 'dart:io';
import 'dart:typed_data';

import '../adapters/linux_bluez/bluez_transport.dart';
import 'package:gshock_api_dart/gshock_api_dart.dart';

/// Example showing how to fetch and configure reminders and events on Casio G-Shock.
///
/// Usage:
///   dart run example/reminders_simple.dart [--mock] [--address AA:BB:CC:DD:EE:FF]
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
        } else if (code == 0x30) {
          final slot = data.length > 1 ? data[1] : 1;
          transport.emit(
            CasioConstants.casioNotificationCharacteristicUuid,
            Uint8List.fromList(<int>[
              0x30,
              slot,
              ...'Doctor Appointment'.codeUnits,
              0x00,
            ]),
          );
        } else if (code == 0x31) {
          final slot = data.length > 1 ? data[1] : 1;
          transport.emit(
            CasioConstants.casioNotificationCharacteristicUuid,
            Uint8List.fromList(<int>[
              0x31,
              slot,
              0x01 | 0x04,
              0x26, 0x10, 0x15, // 2026-10-15 BCD start
              0x26, 0x10, 0x15, // 2026-10-15 BCD end
              0x02, // MONDAY
            ]),
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

    // 1. Fetch all 5 reminder slots from the watch
    stdout.writeln('\n--- Current Reminders ---');
    final reminders = await api.getReminders();
    for (var i = 0; i < reminders.length; i++) {
      final rem = reminders[i];
      final title = rem['title'] ?? '(empty)';
      final time = rem['time'] as Map<String, Object?>?;
      stdout.writeln(
        'Slot #$i: "$title" (enabled: ${time?['enabled']}, repeat: ${time?['repeat_period']})',
      );
    }

    // 2. Set an annual reminder event
    stdout.writeln('\n--- Setting New Reminder ---');
    final anniversary = Event(
      title: 'Anniversary',
      startDate: const EventDate(year: 2026, month: '10', day: 25),
      endDate: const EventDate(year: 2026, month: '10', day: 25),
      repeatPeriod: RepeatPeriod.yearly,
      enabled: true,
    );

    stdout.writeln('Writing anniversary reminder to watch...');
    await api.setReminders(<Map<String, Object?>>[anniversary.toJson()]);
    stdout.writeln('Reminder successfully written!');
  } finally {
    await connection.disconnect();
    watchInfo.reset();
    stdout.writeln('\nDisconnected.');
  }
}
