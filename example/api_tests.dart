import 'dart:io';

import '../adapters/linux_bluez/bluez_transport.dart';
import 'package:gshock_api_dart/gshock_api_dart.dart';

void prompt() {
  stdout.writeln(
    '========================================================================',
  );
  stdout.writeln(
    'Press and hold lower-left button on your watch for 3 seconds to start...',
  );
  stdout.writeln(
    '========================================================================\n',
  );
}

Future<void> main(List<String> args) async {
  final isMock = args.contains('--mock');
  final isDestructive = args.contains('--destructive');

  String? targetAddress;
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--address') {
      targetAddress = args[i + 1];
    }
  }

  prompt();

  final GshockConnection connection;
  if (isMock) {
    stdout.writeln('[MOCK MODE] Initializing simulated watch...');
    final transport = MockTransport();
    connection = GshockConnection(
      address: targetAddress ?? 'AA:BB:CC:DD:EE:FF',
      transport: transport,
    );

    watchInfo.setNameAndModel('CASIO GW-B5600');
    await connection.connect();

    // Seed mock responses for interactive inspection
    transport.emit(CasioConstants.casioNotificationCharacteristicUuid, <int>[
      0x23,
      ...'CASIO GW-B5600'.codeUnits,
      0x00,
    ]);
  } else {
    stdout.writeln('Connecting via Linux BlueZ transport (or pass --mock)...');
    final transport = BluezTransport(deviceAddress: targetAddress);
    final scanner = const BluezScanner();
    connection = GshockConnection(
      address: targetAddress,
      transport: transport,
      scanner: scanner,
    );

    final connected = await connection.connect(
      timeout: const Duration(seconds: 15),
    );
    if (!connected) {
      stderr.writeln('Failed to connect to watch before timeout.');
      exitCode = 1;
      return;
    }
  }

  stdout.writeln('Connected successfully!\n');
  final api = GshockApi(connection);

  try {
    stdout.writeln('--- Watch Capabilities & Information ---');
    stdout.writeln('Model: ${watchInfo.model.name}');
    stdout.writeln('World Cities Count: ${watchInfo.worldCitiesCount}');
    stdout.writeln('Alarm Count: ${watchInfo.alarmCount}');
    stdout.writeln('Has Step Counter: ${watchInfo.hasStepCounter}');
    stdout.writeln('Has Second Dial: ${watchInfo.hasSecondDial}\n');

    if (isMock) {
      stdout.writeln('[Mock inspection complete]');
    } else {
      final name = await api.getWatchName();
      stdout.writeln('Watch Name: $name');

      final condition = await api.getWatchCondition();
      stdout.writeln('Watch Condition: $condition');

      final button = await api.getPressedButton();
      stdout.writeln('Initiated by button: $button');

      if (watchInfo.hasStepCounter) {
        try {
          final stepsToday = await api.getStepCountToday();
          stdout.writeln('Steps Today: $stepsToday');
        } catch (_) {}
      }

      if (isDestructive) {
        stdout.writeln(
          '\n[DESTRUCTIVE] Setting watch time to current clock...',
        );
        await api.setTime();
        stdout.writeln('Time synchronized.');
      } else {
        stdout.writeln(
          '\nNote: Destructive operations (setTime, setAlarms) skipped. Pass --destructive to enable.',
        );
      }
    }
  } finally {
    await connection.disconnect();
    api.reset();
    stdout.writeln('Disconnected.');
  }
}
