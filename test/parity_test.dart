import 'dart:typed_data';

import 'package:gshock_api_dart/gshock_api_dart.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() {
    watchInfo.reset();
    alarmsInst.clear();
  });

  group('StandardProtocol.extractKey', () {
    test('ignores zero key and returns other first bytes', () {
      final protocol = StandardProtocol();
      expect(
        protocol.extractKey(Uint8List.fromList(<int>[0, 5, 0, 0])),
        isNull,
      );
      expect(
        protocol.extractKey(Uint8List.fromList(<int>[0x11, 0x0F, 0x0F])),
        0x11,
      );
    });
  });

  group('TimeIO', () {
    test('deterministic time encoding', () {
      final dt = DateTime(2026, 5, 30, 8, 45, 30, 123, 456);
      final encoded = TimeEncoderPure.encodeCurrentTime(dt);
      expect(encoded.length, 10);
      expect(encoded[0], 0xEA);
      expect(encoded[1], 0x07);
      expect(encoded[2], 5);
      expect(encoded[3], 30);
      expect(encoded[4], 8);
      expect(encoded[5], 45);
      expect(encoded[6], 30);
      expect(encoded[7], 5);
      final expectedNanoByte = (123456000 * 256 ~/ 1000000000) & 0xFF;
      expect(encoded[8], expectedNanoByte);
      expect(encoded[9], 1);
    });

    test('legacy encoder matches pure encoder', () {
      final dt = DateTime(2026, 5, 30, 8, 45, 30, 123, 456);
      expect(
        TimeEncoder.prepareCurrentTime(dt),
        equals(TimeEncoderPure.encodeCurrentTime(dt)),
      );
    });

    test('prepareWatchCommands uses current-time protocol at 0x0E', () {
      final commands = TimeIOFunctional.prepareWatchCommands(
        '{"value": {}}',
        1779979200.0,
      );
      expect(commands.length, 1);
      final command = commands.first as WriteAction;
      expect(command.handle, 0x000E);
      expect(command.data[0], Protocol.currentTime.value);
      expect(command.data.length, 11);
    });
  });

  group('Alarms', () {
    test('prepareWatchCommands issues two reads', () {
      final commands = AlarmsIOFunctional.prepareWatchCommands();
      expect(commands.length, 2);
      expect((commands[0] as WriteAction).handle, 0x000C);
      expect((commands[1] as WriteAction).handle, 0x000C);
      expect((commands[0] as WriteAction).data, <int>[0x15]);
      expect((commands[1] as WriteAction).data, <int>[0x16]);
    });

    test('MTG-B3000 first-alarm frame', () {
      const alarmMsg =
          '{"value": [{"enabled": true, "hasHourlyChime": false, "hour": 7, "minute": 25}]}';
      final commands = AlarmsIOFunctional.prepareWatchCommandsSetMtgB3000(
        alarmMsg,
      );
      expect(commands.length, 1);
      final command = commands.first as WriteAction;
      expect(command.handle, 0x000E);
      expect(command.data, <int>[0x15, 0x40, 0x40, 7, 25]);
    });

    test('secondary alarm slices accumulated state (D6 quirk)', () {
      alarmsInst.alarms.addAll(<Map<String, Object?>>[
        <String, Object?>{
          'enabled': true,
          'hasHourlyChime': false,
          'hour': 1,
          'minute': 2,
        },
        <String, Object?>{
          'enabled': true,
          'hasHourlyChime': false,
          'hour': 3,
          'minute': 4,
        },
        <String, Object?>{
          'enabled': false,
          'hasHourlyChime': true,
          'hour': 5,
          'minute': 6,
        },
      ]);
      final bytes = alarmsInst.fromJsonAlarmSecondaryAlarms(alarmsInst.alarms);
      expect(bytes[0], 0x16);
      // Two remaining alarms -> 1 header + 2 * 4 bytes.
      expect(bytes.length, 9);
      expect(bytes.sublist(1, 5), <int>[0x40, 0x40, 3, 4]);
    });
  });

  group('SettingsIO', () {
    test('encode/decode round-trip', () {
      watchInfo.setNameAndModel('CASIO GW-B5600');
      final settingsDict = <String, Object?>{
        'time_format': '24h',
        'button_tone': true,
        'auto_light': false,
        'power_saving_mode': true,
        'light_duration': '4s',
        'date_format': 'DD:MM',
        'language': 'French',
      };

      final encoded = SettingsIOFunctional.encode(settingsDict);
      expect(encoded.length, 12);
      expect(encoded[0], 0x13);

      final decoded = SettingsIOFunctional.decode(encoded);
      expect(decoded['time_format'], '24h');
      expect(decoded['button_tone'], true);
      expect(decoded['auto_light'], false);
      expect(decoded['power_saving_mode'], true);
      expect(decoded['light_duration'], '4s');
      expect(decoded['date_format'], 'DD:MM');
      expect(decoded['language'], 'French');
    });

    test('prepareWatchCommands reads 0x13', () {
      final commands = SettingsIOFunctional.prepareWatchCommands();
      expect(commands.length, 1);
      expect((commands[0] as WriteAction).handle, 0x000C);
      expect((commands[0] as WriteAction).data, <int>[0x13]);
    });

    test('MTG-B3000 uses 3s long duration', () {
      watchInfo.model = WatchModel.mtgB3000;
      final settingsDict = <String, Object?>{
        'time_format': '24h',
        'button_tone': true,
        'auto_light': false,
        'power_saving_mode': true,
        'light_duration': '3s',
        'date_format': 'DD:MM',
        'language': 'French',
      };
      final encoded = SettingsIOFunctional.encode(settingsDict);
      expect(encoded[2], 1);
      expect(SettingsIOFunctional.decode(encoded)['light_duration'], '3s');
    });
  });

  group('TimerIO', () {
    test('encode/decode', () {
      const seconds = 3665;
      final encoded = TimerIOFunctional.encode(seconds);
      expect(encoded[0], 0x18);
      expect(encoded[1], 1);
      expect(encoded[2], 1);
      expect(encoded[3], 5);
      expect(TimerIOFunctional.decode(encoded), seconds);
    });

    test('commands', () {
      final commands = TimerIOFunctional.prepareWatchCommands();
      expect(commands.length, 1);
      expect((commands[0] as WriteAction).handle, 0x000C);
      expect((commands[0] as WriteAction).data, <int>[0x18]);
    });

    test('MTG-B3000 15-byte frame', () {
      final encoded = TimerIOFunctional.encodeMtgB3000(600);
      expect(encoded.length, 15);
      expect(encoded[0], 0x18);
      expect(encoded[1], 0);
      expect(encoded[2], 10);
      expect(encoded[3], 0);
      expect(encoded.sublist(4), List<int>.filled(11, 0));

      final commands = TimerIOFunctional.prepareWatchCommandsSetMtgB3000(
        '{"value": 600}',
      );
      expect((commands.first as WriteAction).data, encoded);
    });
  });

  group('TimeAdjustmentIO', () {
    test('encode/decode', () {
      const originalHex = '0x11 0F 0F 0F 06 00 50 00 04 00 01 00 80 10 D2';
      final encoded = TimeAdjustmentIOFunctional.encode(originalHex, true, 25);
      final decoded = TimeAdjustmentIOFunctional.decode(encoded);
      expect(decoded['timeAdjustment'], 'True');
      expect(decoded['minutesAfterHour'], '25');
    });
  });

  group('DST commands', () {
    test('DST for world cities reads 0x1E', () {
      final commands = DstForWorldCitiesIOFunctional.prepareWatchCommands();
      expect(commands.length, 1);
      expect((commands[0] as WriteAction).handle, 0x000C);
      expect((commands[0] as WriteAction).data, <int>[0x1E]);
    });

    test('DST watch state reads 0x1D', () {
      final commands = DstWatchStateIOFunctional.prepareWatchCommands();
      expect(commands.length, 1);
      expect((commands[0] as WriteAction).handle, 0x000C);
      expect((commands[0] as WriteAction).data, <int>[0x1D]);
    });
  });

  group('AppInfoIO', () {
    test('commands', () {
      final commands = AppInfoIOFunctional.prepareWatchCommands();
      expect(commands.length, 1);
      expect((commands[0] as WriteAction).handle, 0x000C);
      expect((commands[0] as WriteAction).data, <int>[0x22]);
    });

    test('response to 0xFF trigger', () {
      final trigger = Uint8List.fromList(<int>[
        0x22,
        ...List<int>.filled(10, 0xFF),
        0x00,
      ]);
      final response = AppInfoIOFunctional.prepareWatchResponse(trigger);
      expect(response.length, 1);
      final command = response.first as WriteAction;
      expect(command.handle, 0xE);
      expect(command.data[0], 0x22);
      expect(command.data.length, 12);
    });
  });

  group('WorldCitiesIO', () {
    test('commands', () {
      final commands = WorldCitiesIOFunctional.prepareWatchCommands();
      expect(commands.length, 1);
      expect((commands[0] as WriteAction).handle, 0x000C);
      expect((commands[0] as WriteAction).data, <int>[0x1F]);
    });

    test('encodeAndPad pads to 19 bytes', () {
      final padded = WorldCitiesIO.encodeAndPad('LONDON', 2);
      expect(padded.length, 19);
      expect(padded[0], 0x1F);
      expect(padded[1], 2);
      expect(String.fromCharCodes(padded.sublist(2, 8)), 'LONDON');
    });

    test('parseCity uppercases last segment', () {
      expect(WorldCitiesIO.parseCity('America/New_York'), 'NEW_YORK');
    });
  });

  group('ButtonPressedIO', () {
    test('decodes lower-left', () {
      final leftPress = Uint8List.fromList(<int>[
        0x10,
        0x17,
        0x62,
        0x07,
        0x38,
        0x85,
        0xCD,
        0x7F,
        0x01,
        ...List<int>.filled(10, 0),
      ]);
      expect(
        ButtonPressedIOFunctional.decode(leftPress),
        WatchButton.lowerLeft,
      );
    });
  });

  group('WatchConditionIO', () {
    test('commands', () {
      final commands = WatchConditionIOFunctional.prepareWatchCommands();
      expect(commands.length, 1);
      expect((commands[0] as WriteAction).handle, 0x000C);
      expect((commands[0] as WriteAction).data, <int>[0x28]);
    });
  });

  group('WatchNameIO', () {
    test('decodes ASCII after command byte', () {
      final payload = Uint8List.fromList(<int>[
        0x23,
        ...'G-SHOCK'.codeUnits,
        0,
      ]);
      expect(WatchNameIOFunctional.decode(payload), 'G-SHOCK');
    });
  });

  group('WatchInfo', () {
    test('exact lookup and protocol selection', () {
      watchInfo.setNameAndModel('CASIO GW-BX5600');
      expect(watchInfo.model, WatchModel.gwBx5600);
      expect(watchInfo.hasNewTimeFormat, true);
      expect(watchInfo.protocol, isA<MipProtocol>());

      watchInfo.setNameAndModel('CASIO MTG-B1000');
      expect(watchInfo.model, WatchModel.mtgB1000);
      expect(watchInfo.hasSecondDial, true);
      expect(watchInfo.protocol, isA<AnalogueProtocol>());

      watchInfo.setNameAndModel('CASIO ABL-100WE');
      expect(watchInfo.model, WatchModel.abl100);
      expect(watchInfo.hasStepCounter, true);
      expect(watchInfo.protocol, isA<StandardProtocol>());

      watchInfo.setNameAndModel('CASIO F-B100W');
      expect(watchInfo.model, WatchModel.fB100);
      expect(watchInfo.hasStepCounter, true);

      watchInfo.setNameAndModel('CASIO GW-B5600');
      expect(watchInfo.model, WatchModel.gw);
      expect(watchInfo.worldCitiesCount, 6);
      expect(watchInfo.protocol, isA<StandardProtocol>());
    });

    test('reset clears capability state', () {
      watchInfo.setNameAndModel('CASIO MTG-B3000');
      expect(watchInfo.model, WatchModel.mtgB3000);
      watchInfo.reset();
      expect(watchInfo.model, WatchModel.generic);
      expect(watchInfo.hasSecondDial, false);
    });

    test('exact model map contains no generic prefix surprises', () {
      expect(exactModelMap['GW-B5600'], WatchModel.gw);
      expect(exactModelMap['MTG-B3000'], WatchModel.mtgB3000);
      expect(exactModelMap['F-B100W'], WatchModel.fB100);
    });
  });

  group('StepCounterIO', () {
    test('parses synthetic 400-byte payload', () {
      final payload = Uint8List(400);
      payload[0] = 0x26;
      payload[1] = 1;
      payload[2] = 8;
      payload[3] = 17;

      for (var i = 0; i < 144; i++) {
        final offset = 6 + i * 2;
        final value = 10 + i;
        payload[offset] = value & 0xFF;
        payload[offset + 1] = (value >> 8) & 0xFF;
      }
      for (var i = 0; i < 14; i++) {
        final offset = 318 + i * 4;
        final value = 5000 + i;
        payload[offset] = value & 0xFF;
        payload[offset + 1] = (value >> 8) & 0xFF;
        payload[offset + 2] = (value >> 16) & 0xFF;
        payload[offset + 3] = (value >> 24) & 0xFF;
      }
      const steps = 12345;
      payload[374] = steps & 0xFF;
      payload[375] = (steps >> 8) & 0xFF;
      payload[376] = (steps >> 16) & 0xFF;
      payload[377] = (steps >> 24) & 0xFF;

      final parsed = StepCounterIOFunctional.parse(payload);
      expect(parsed, isNotNull);
      expect(parsed!.dayOfWeek, 3);
      expect(parsed.month, 1);
      expect(parsed.dayOfMonth, 8);
      expect(parsed.currentDaySteps, 12345);
      expect(parsed.hourlySteps.length, 13);
      expect(parsed.hourlySteps[0], 60);
      expect(parsed.dailyHistory.length, 7);
      expect(parsed.dailyHistory[0], 5000);
      expect(parsed.raw, payload.toList());
      expect(parsed.warnings, isEmpty);
      expect(parsed.distanceMeters, 0);
      expect(parsed.pendingDistanceMeters, 0);
    });

    test('rejects impossible calendar metadata', () {
      final payload = Uint8List(400);
      payload[0] = 0x26;
      payload[1] = 0x13;
      payload[2] = 0x01;
      payload[3] = 0x22;
      payload[4] = 0x16;
      payload[5] = 0x01;

      for (var i = 0; i < 144; i++) {
        final offset = 6 + i * 2;
        payload[offset] = 0xFE;
        payload[offset + 1] = 0xFF;
      }

      final parsed = StepCounterIOFunctional.parse(payload);
      expect(parsed, isNotNull);
      expect(parsed!.dayOfWeek, isNull);
      expect(parsed.month, 13);
      expect(parsed.dayOfMonth, 1);
      expect(
        parsed.warnings.any((w) => w.contains('invalid BCD timestamp')),
        isTrue,
      );
    });

    test('unavailable record', () {
      final unavailable = StepCounterData.unavailable();
      expect(unavailable.currentDaySteps, isNull);
      expect(unavailable.hourlySteps, isEmpty);
    });

    test('protocol peek=false closes the DRSP transaction', () async {
      watchInfo.setNameAndModel('CASIO ABL-100WE');
      final transport = MockTransport();
      final connection = GshockConnection(
        address: 'AA:BB',
        transport: transport,
      );
      await connection.connect();

      final future = watchInfo.protocol.getStepCount(connection);
      await Future<void>.delayed(Duration.zero);

      final payload = Uint8List(10);
      payload[0] = 0x26;
      transport.emit(CasioConstants.casioDataRequestSpCharacteristicUuid, <int>[
        0x00,
        0x11,
        payload.length,
        0,
        0,
      ]);
      transport.emit(CasioConstants.casioConvoyCharacteristicUuid, payload);
      await future;

      final endWrites = transport.writes.where(
        (w) =>
            w.uuid == CasioConstants.casioDataRequestSpCharacteristicUuid &&
            w.data.length == 5 &&
            w.data[0] == 0x04,
      );
      expect(endWrites, isNotEmpty);
    });
  });

  group('CasioTimeZoneHelper', () {
    test('world city coordinates and lookup', () {
      final coords = CasioTimeZoneHelper.getWorldCityCoordinates(
        'Europe/Madrid',
      );
      expect(coords.exact, isTrue);
      expect(coords.lat, closeTo(41.4548, 0.0001));
      expect(coords.lon, closeTo(2.2502, 0.0001));

      final tzEntry = CasioTimeZoneHelper.findTimeZone('Europe/London');
      expect(tzEntry.name, 'LONDON');
      expect(tzEntry.zoneName, 'Europe/London');
    });

    test('timezone table has 49 entries', () {
      expect(CasioTimeZoneHelper.timeZoneTable.length, 49);
    });
  });

  group('GwBx5600TimeIO', () {
    test('world city records are 66 bytes with expected header', () {
      final records = GwBx5600TimeIO.buildWorldCityRecords();
      expect(records.length, 66);
      expect(records[0], 0x14);
      expect(records[1], 0x00);
      expect(records[2], 0x24);
      expect(records[3], 0x00);
      expect(records[4], 0x01);
    });
  });

  group('AppNotificationIO', () {
    test('encode/decode round-trip', () {
      final notification = AppNotification(
        type: NotificationType.calendar,
        timestamp: '20250516T233000',
        app: 'Calendar',
        title: 'Meeting',
        text: 'Discuss project',
      );

      final encoded = AppNotificationIO.encodeNotificationPacket(notification);
      final xorEncoded = AppNotificationIO.xorEncodeBuffer(encoded);
      final decodedBytes = AppNotificationIO.xorDecodeBuffer(xorEncoded);
      final decoded = AppNotificationIO.decodeNotificationPacket(decodedBytes);

      expect(decoded.type, NotificationType.calendar);
      expect(decoded.timestamp, '20250516T233000');
      expect(decoded.app, 'Calendar');
      expect(decoded.title, 'Meeting');
      expect(decoded.text, 'Discuss project');
    });

    test('truncates text fields by UTF-8 byte length', () {
      final notification = AppNotification(
        type: NotificationType.generic,
        timestamp: '0',
        app: 'App',
        title: 'Title',
        text: 'x' * 300,
        shortText: 'y' * 60,
      );
      expect(notification.text.codeUnits.length, lessThanOrEqualTo(193));
      expect(notification.shortText.codeUnits.length, lessThanOrEqualTo(40));
    });
  });

  group('Event', () {
    test('toJson includes start/end dates', () {
      final event = Event(
        title: 'Test',
        startDate: const EventDate(year: 2025, month: 'MAY', day: 16),
        repeatPeriod: RepeatPeriod.daily,
        enabled: true,
      );
      final json = event.toJson();
      expect(json['title'], 'Test');
      final time = json['time'] as Map<String, Object?>;
      expect((time['start_date'] as Map)['year'], 2025);
      expect((time['end_date'] as Map)['day'], 16);
    });

    test('encodes weekly reminder frames', () {
      const message =
          '{"value":[{"title":"Test","time":{"enabled":true,'
          '"repeat_period":"WEEKLY",'
          '"start_date":{"year":2025,"month":"MAY","day":16},'
          '"end_date":{"year":2025,"month":"MAY","day":17},'
          '"days_of_week":["MONDAY","FRIDAY"]}}]}';
      final commands = EventsIOFunctional.prepareWatchCommandsSet(message);
      expect(commands.length, 2);

      final titleCommand = commands[0] as WriteAction;
      expect(titleCommand.data[0], 0x30);
      expect(titleCommand.data[1], 1);
      expect(titleCommand.data.length, 20);

      final timeCommand = commands[1] as WriteAction;
      expect(timeCommand.data[0], 0x31);
      expect(timeCommand.data[1], 1);
      expect(timeCommand.data.length, 11);
      // enabled (0x01) | weekly (0x04)
      expect(timeCommand.data[2], 0x05);
    });
  });

  group('HomeTimeIO', () {
    test('parses city name after two header bytes', () {
      final data = Uint8List.fromList(<int>[
        0x24,
        0x00,
        ...'LONDON'.codeUnits,
        0x00,
      ]);
      expect(HomeTimeIOFunctional.parseHomeCity(data), 'LONDON');
    });
  });

  group('MessageDispatcher', () {
    test('registry sizes', () {
      expect(MessageDispatcher.watchSenders.length, 11);
      expect(
        MessageDispatcher.dataReceivedMessages.length,
        greaterThanOrEqualTo(20),
      );
    });
  });

  group('GshockConnection + MockTransport', () {
    test('round-trips a watch-name read', () async {
      final transport = MockTransport();
      final connection = GshockConnection(
        address: 'AA:BB',
        transport: transport,
      );
      final connected = await connection.connect();
      expect(connected, isTrue);

      final future = WatchNameIO.request(connection);
      await Future<void>.delayed(Duration.zero);

      transport.emit(CasioConstants.casioNotificationCharacteristicUuid, <int>[
        0x23,
        ...'G-SHOCK'.codeUnits,
        0x00,
      ]);

      expect(await future, 'G-SHOCK');

      // The trigger write used handle 0x0C (write-without-response).
      final trigger = transport.writes.first;
      expect(
        trigger.uuid,
        CasioConstants.casioReadRequestForAllFeaturesCharacteristicUuid,
      );
      expect(trigger.data, <int>[0x23]);
      expect(trigger.withResponse, isFalse);
    });

    test('routes a condition notification', () async {
      watchInfo.setNameAndModel('CASIO GW-B5600');
      final transport = MockTransport();
      final connection = GshockConnection(
        address: 'AA:BB',
        transport: transport,
      );
      await connection.connect();

      final future = WatchConditionIO.request(connection);
      await Future<void>.delayed(Duration.zero);

      // 0x28, battery raw 9 (lower limit), temperature 21.
      transport.emit(CasioConstants.casioNotificationCharacteristicUuid, <int>[
        0x28,
        9,
        21,
      ]);

      final condition = await future;
      expect(condition['battery_level_percent'], 0);
      expect(condition['temperature'], 21);
    });
  });

  group('CancelableResult', () {
    test('maps timeout to GShockConnectionException', () async {
      final result = CancelableResult<int>(
        timeout: const Duration(milliseconds: 10),
      );
      await expectLater(
        result.getResult(),
        throwsA(isA<GShockConnectionException>()),
      );
    });
  });

  group('AlwaysConnectedWatchFilter', () {
    test('throttles always-connected watches after first connection', () {
      final filter = AlwaysConnectedWatchFilter();
      expect(filter.connectionFilter('CASIO DW-H5600'), isTrue);
      expect(filter.connectionFilter('CASIO DW-H5600'), isFalse);
      expect(filter.connectionFilter('CASIO GW-B5600'), isTrue);
    });
  });
}
