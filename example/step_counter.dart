import 'dart:io';
import 'dart:typed_data';

import 'package:gshock_api_dart/gshock_api_dart.dart';

void main(List<String> args) async {
  final isMock = args.contains('--mock');

  stdout.writeln('=== G-Shock Lifelog & Step Counter Example ===');

  final GshockConnection connection;
  if (isMock) {
    stdout.writeln('[MOCK MODE] Loading synthetic step counter fixture...');
    final transport = MockTransport();
    connection = GshockConnection(
      address: 'AA:BB:CC:DD:EE:FF',
      transport: transport,
    );

    watchInfo.setNameAndModel('CASIO ABL-100WE');
    await connection.connect();

    // Create a 400-byte lifelog synthetic payload matching Python test_code.py
    final payload = Uint8List(400);
    payload[0] = 0x26;
    payload[1] = 1; // Month
    payload[2] = 8; // Day
    payload[3] = 17;

    for (var i = 0; i < 144; i++) {
      final offset = 6 + i * 2;
      final val = 10 + (i % 50);
      payload[offset] = val & 0xFF;
      payload[offset + 1] = (val >> 8) & 0xFF;
    }

    for (var i = 0; i < 14; i++) {
      final offset = 318 + i * 4;
      final val = 5000 + i * 250;
      payload[offset] = val & 0xFF;
      payload[offset + 1] = (val >> 8) & 0xFF;
      payload[offset + 2] = (val >> 16) & 0xFF;
      payload[offset + 3] = (val >> 24) & 0xFF;
    }

    // Today's steps at offset 374: 12,345
    payload[374] = 0x39;
    payload[375] = 0x30;
    payload[376] = 0x00;
    payload[377] = 0x00;

    final parsed = StepCounterIOFunctional.parse(payload);
    if (parsed != null) {
      _printStepData(parsed);
    }

    await connection.disconnect();
    watchInfo.reset();
    return;
  }

  stdout.writeln('Connecting to watch...');
  final transport = BluezTransport();
  final scanner = const BluezScanner();
  connection = GshockConnection(transport: transport, scanner: scanner);

  final connected = await connection.connect();
  if (!connected) {
    stderr.writeln('Could not connect to watch.');
    exitCode = 1;
    return;
  }

  final api = GshockApi(connection);
  try {
    final name = await api.getWatchName();
    stdout.writeln('Connected to $name');

    if (!watchInfo.hasStepCounter) {
      stdout.writeln(
        'Watch model ${watchInfo.model} does not support step counting.',
      );
      return;
    }

    final data = await api.getStepCount(peek: true);
    _printStepData(data);
  } finally {
    await connection.disconnect();
    api.reset();
  }
}

void _printStepData(StepCounterData data) {
  stdout.writeln('\n--- Daily Summary ---');
  stdout.writeln('Today\'s Total Steps: ${data.currentDaySteps ?? 0}');
  stdout.writeln('Distance Walked: ${data.distanceMeters} meters');
  if (data.warnings.isNotEmpty) {
    stdout.writeln('Warnings: ${data.warnings.join(", ")}');
  }

  stdout.writeln('\n--- Hourly Distribution ---');
  for (var hour = 0; hour < data.hourlySteps.length; hour++) {
    final count = data.hourlySteps[hour] ?? 0;
    final barLength = (count / 50).clamp(0, 40).toInt();
    final bar = '█' * barLength;
    final hourLabel = hour.toString().padLeft(2, '0');
    stdout.writeln('$hourLabel:00 | $bar ($count steps)');
  }

  stdout.writeln('\n--- 7-Day History ---');
  for (var i = 0; i < data.dailyHistory.length; i++) {
    stdout.writeln('Day -${i + 1}: ${data.dailyHistory[i]} steps');
  }
}
