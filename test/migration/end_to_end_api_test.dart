import 'package:gshock_api_dart/gshock_api_dart.dart';
import 'package:test/test.dart';

import 'fake_watch.dart';
import 'golden/python_reference.dart';
import 'helpers.dart';

/// End-to-end migration verification: every public [GshockApi] method is
/// driven through the full stack (facade -> protocol -> dispatcher ->
/// connection -> FakeWatch simulator) for the three protocol families
/// (standard GW-B5600, analogue MTG-B3000/MTG-B1000, MIP GW-BX5600).
///
/// Each test asserts BOTH the value returned to the caller AND the exact
/// bytes/handles put on the wire, so passing this file means the Dart
/// library issues the same BLE traffic the Python implementation would.
void main() {
  setUp(resetMigrationState);
  tearDown(resetMigrationState);

  group('standard watch (CASIO GW-B5600)', () {
    late FakeWatch watch;
    late GshockConnection connection;
    late GshockApi api;

    setUp(() async {
      watch = FakeWatch();
      connection = await watch.connect();
      api = GshockApi(connection);
    });

    test('getWatchName', () async {
      watch.respondWatchName();
      final name = await api.getWatchName();
      expect(name, 'CASIO GW-B5600');
      expect(watch.writesTo(0x0C).single.data, <int>[0x23]);
    });

    test('getPressedButton', () async {
      watch.respondButton(WatchButton.lowerLeft);
      expect(await api.getPressedButton(), WatchButton.lowerLeft);
      expect(watch.writesTo(0x0C).single.data, <int>[0x10]);
    });

    test('getWorldCities returns the raw notification payload', () async {
      watch.respondWorldCities('LONDON');
      final bytes = await api.getWorldCities(2);
      expect(bytes, <int>[0x1F, 0x00, ...'LONDON'.codeUnits, 0x00]);
      expect(watch.writesTo(0x0C).single.data, <int>[0x1F, 0x02]);
    });

    test('getDstForWorldCities reads and returns raw payload', () async {
      watch.respondDstForWorldCities();
      final bytes = await api.getDstForWorldCities(0);
      expect(bytes[0], 0x1E);
      expect(watch.writesTo(0x0C).single.data, <int>[0x1E, 0x00]);
    });

    test('getDstWatchState reads and returns raw payload', () async {
      watch.respondDstWatchState();
      final bytes = await api.getDstWatchState(DtsState.zero);
      expect(bytes[0], 0x1D);
      expect(bytes[3], 0x01);
      expect(watch.writesTo(0x0C).single.data, <int>[0x1D, 0x00]);
    });

    test('getHomeTime parses the city name', () async {
      watch.respondWorldCities('LONDON');
      expect(await api.getHomeTime(), 'LONDON');
      expect(watch.writesTo(0x0C).single.data, <int>[0x1F, 0x00]);
    });

    test(
      'setTime writes the DST/world-city preamble and the time frame',
      () async {
        watch
          ..respondDstWatchState()
          ..respondDstForWorldCities()
          ..respondWorldCities('LONDON')
          ..respondHomeTime('LONDON');

        const seconds = 1778000000.0;
        await api.setTime(
          currentTime: seconds,
          offset: 0,
          timezone: 'Europe/London',
        );

        // The standard time-set preamble reads DST states, DST cities and
        // world cities for every slot, then writes each back.
        final reads = watch.writesTo(0x0C).map((w) => w.data[0]).toList();
        expect(reads, containsAll(<int>[0x1D, 0x1E, 0x1F]));

        // The final time frame goes to 0x0E and equals the pure encoder
        // applied to the same instant.
        final timeWrites = watch.writesTo(0x0E);
        final timeFrame = timeWrites.last.data;
        expect(timeFrame.first, 0x09);
        expect(
          timeFrame.sublist(1),
          TimeEncoderPure.encodeCurrentTime(
            DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round()),
          ),
        );
      },
    );

    test('getAlarms', () async {
      watch.respondAlarms(count: 5);
      final alarms = await api.getAlarms();
      expect(alarms.length, 5);
      expect(alarms.first['enabled'], isTrue);
      expect(alarms.first['hour'], 6);
      // GET_ALARMS issues both alarm request codes.
      final reads = watch.writesTo(0x0C).map((w) => w.data[0]).toList();
      expect(reads, containsAll(<int>[0x15, 0x16]));
    });

    test('setAlarms writes the golden alarm frames', () async {
      final alarms = <Map<String, Object?>>[
        <String, Object?>{
          'enabled': true,
          'hasHourlyChime': false,
          'hour': 7,
          'minute': 25,
        },
        <String, Object?>{
          'enabled': false,
          'hasHourlyChime': true,
          'hour': 8,
          'minute': 30,
        },
        <String, Object?>{
          'enabled': true,
          'hasHourlyChime': false,
          'hour': 9,
          'minute': 35,
        },
        <String, Object?>{
          'enabled': false,
          'hasHourlyChime': false,
          'hour': 10,
          'minute': 40,
        },
        <String, Object?>{
          'enabled': true,
          'hasHourlyChime': true,
          'hour': 11,
          'minute': 45,
        },
      ];
      await api.setAlarms(alarms);
      final writes = watch.allWritesByHandle()
        ..retainWhere((w) => w.$1 == 0x0E);
      // Golden: 0x15 frame, 0x16 frame, hourly-chime frame.
      expect(writes.length, pythonAlarmsSetActions.length);
      for (var i = 0; i < writes.length; i++) {
        expect(
          writes[i].$2,
          pythonAlarmsSetActions[i].data,
          reason: 'setAlarms write $i diverges from Python',
        );
      }
    });

    test('getTimer', () async {
      watch.respondTimer(3665);
      expect(await api.getTimer(), 3665);
      expect(watch.writesTo(0x0C).single.data, <int>[0x18]);
    });

    test('setTimer writes the golden frame', () async {
      await api.setTimer(3665);
      expect(
        watch.writesTo(0x0E).single.data,
        pythonTimerSetActions.single.data,
      );
    });

    test('getWatchCondition', () async {
      watch.respondWatchCondition(batteryRaw: 9, temperature: 21);
      final condition = await api.getWatchCondition();
      expect(
        condition['battery_level_percent'],
        pythonConditionDecoded['battery_level_percent'],
      );
      expect(condition['temperature'], 21);
      expect(watch.writesTo(0x0C).single.data, <int>[0x28]);
    });

    test('getTimeAdjustment', () async {
      watch.respondTimeAdjustment(pythonTimeAdjustmentEncoded);
      expect(await api.getTimeAdjustment(), isTrue);
      expect(watch.writesTo(0x0C).single.data, <int>[0x11]);
    });

    test('setTimeAdjustment writes request + golden set frame', () async {
      watch.respondTimeAdjustment(pythonTimeAdjustmentEncoded);
      await api.getTimeAdjustment();
      await api.setTimeAdjustment(true, 25);
      expect(watch.writesTo(0x0C).single.data, <int>[0x11]);
      expect(watch.writesTo(0x0E).single.data, pythonTimeAdjustmentEncoded);
    });

    test('getBasicSettings', () async {
      watch.respondSettings(pythonSettingsEncoded);
      final settings = await api.getBasicSettings();
      expect(settings['time_format'], pythonSettingsDecoded['time_format']);
      expect(settings['button_tone'], pythonSettingsDecoded['button_tone']);
      expect(settings['auto_light'], pythonSettingsDecoded['auto_light']);
      expect(
        settings['power_saving_mode'],
        pythonSettingsDecoded['power_saving_mode'],
      );
      expect(settings['date_format'], pythonSettingsDecoded['date_format']);
      expect(settings['language'], pythonSettingsDecoded['language']);
      expect(
        settings['light_duration'],
        pythonSettingsDecoded['light_duration'],
      );
      expect(watch.writesTo(0x0C).single.data, <int>[0x13]);
    });

    test('getSettings merges settings and time adjustment', () async {
      watch
        ..respondSettings(pythonSettingsEncoded)
        ..respondTimeAdjustment(pythonTimeAdjustmentEncoded);
      final settings = await api.getSettings();
      expect(settings['time_format'], '24h');
      expect(settings['time_adjustment'], isTrue);
      expect(settings['time_adjustment_minutes_after_hour'], '25');
    });

    test('setSettings writes the golden settings frame', () async {
      await api.setSettings(<String, Object?>{
        'time_format': '24h',
        'button_tone': true,
        'auto_light': false,
        'power_saving_mode': true,
        'light_duration': '4s',
        'date_format': 'DD:MM',
        'language': 'French',
      });
      expect(watch.writesTo(0x0E).single.data, pythonSettingsEncoded);
    });

    test('getReminders reads all five event slots', () async {
      watch.respondReminders();
      final reminders = await api.getReminders();
      expect(reminders.length, 5);
      // 5 slots x (title 0x30 + time 0x31) read requests.
      final reads = watch.writesTo(0x0C).map((w) => w.data[0]).toList();
      expect(reads.where((c) => c == 0x30).length, 5);
      expect(reads.where((c) => c == 0x31).length, 5);
      final first = reminders.first;
      expect(first['title'], 'Standup');
      final time = (first['time'] as Map).cast<String, Object?>();
      expect(time['repeat_period'], 'WEEKLY');
    });

    test('setReminders writes title and time frames per event', () async {
      await api.setReminders(<Map<String, Object?>>[
        <String, Object?>{
          'title': 'Standup',
          'time': <String, Object?>{
            'enabled': true,
            'repeat_period': 'WEEKLY',
            'start_date': <String, Object?>{
              'year': 2025,
              'month': 'MAY',
              'day': 16,
            },
            'end_date': <String, Object?>{
              'year': 2025,
              'month': 'MAY',
              'day': 17,
            },
            'days_of_week': <String>['MONDAY', 'FRIDAY'],
          },
        },
      ]);
      final writes = watch.writesTo(0x0E);
      expect(writes.length, pythonEventsSetActions.length);
      for (var i = 0; i < writes.length; i++) {
        expect(
          writes[i].data,
          pythonEventsSetActions[i].data,
          reason: 'setReminders write $i diverges from Python',
        );
      }
    });

    test(
      'getAppInfo writes the request and replies with the response frame',
      () async {
        watch.respondAppInfo();
        expect(await api.getAppInfo(), 'OK');
        expect(watch.writesTo(0x0C).single.data, <int>[0x22]);
        // The library answers the 0xFF trigger with the app-info response.
        expect(
          watch.writesTo(0x0E).last.data,
          pythonAppInfoResponse.single.data,
        );
      },
    );

    test('sendAppNotification writes the XOR-255 buffer to 0x0D', () async {
      final notification = AppNotification(
        type: NotificationType.calendar,
        timestamp: '20250516T233000',
        app: 'Calendar',
        title: 'Meeting',
        text: 'Discuss project',
        shortText: 'Meet',
      );
      await api.sendAppNotification(notification);
      final write = watch.writesTo(0x0D).single;
      expect(write.withResponse, isFalse);
      expect(
        write.data,
        Bytes.fromCasioCmd(pythonNotificationXor),
        reason: 'notification bytes diverge from the Python XOR buffer',
      );
    });

    test('getStepCount drives the full DRSP/Convoy flow', () async {
      final counterWatch = FakeWatch(
        advertisedName: 'CASIO ABL-100WE',
        stepCounterPayload: pythonStepCounterPayload,
      );
      final counterConnection = await counterWatch.connect();
      final counterApi = GshockApi(counterConnection);

      final data = await counterApi.getStepCount();

      expect(data.currentDaySteps, pythonStepCounterParsed['currentDaySteps']);
      expect(data.hourlySteps, pythonStepCounterParsed['hourlySteps']);
      expect(data.dailyHistory, pythonStepCounterParsed['dailyHistory']);
      expect(data.warnings, pythonStepCounterParsed['warnings']);

      // DRSP transaction: start (0x00) ... end (0x04) on handle 0x11.
      final drspWrites = counterWatch.writesTo(0x11);
      expect(drspWrites.length, 2);
      expect(drspWrites.first.data[0], 0x00);
      expect(drspWrites.first.data[1], 0x11);
      expect(drspWrites.last.data[0], 0x04);
    });

    test('getStepCount(peek: true) skips the transaction end', () async {
      final counterWatch = FakeWatch(
        advertisedName: 'CASIO ABL-100WE',
        stepCounterPayload: pythonStepCounterPayload,
      );
      final counterConnection = await counterWatch.connect();
      final counterApi = GshockApi(counterConnection);

      await counterApi.getStepCount(peek: true);
      expect(counterWatch.writesTo(0x11).length, 1);
    });
  });

  group('analogue watch (CASIO MTG-B3000)', () {
    late FakeWatch watch;
    late GshockApi api;

    setUp(() async {
      watch = FakeWatch(advertisedName: 'CASIO MTG-B3000');
      final connection = await watch.connect();
      api = GshockApi(connection);
    });

    test(
      'model resolves to the analogue protocol with 12-byte settings',
      () async {
        expect(watchInfo.model, WatchModel.mtgB3000);
        expect(watchInfo.protocol, isA<AnalogueProtocol>());
        expect(watchInfo.settingsSize, 12);
      },
    );

    test('setTimer writes the 15-byte MTG-B3000 frame', () async {
      await api.setTimer(600);
      expect(
        watch.writesTo(0x0E).single.data,
        pythonTimerMtgB3000SetActions.single.data,
      );
      expect(watch.writesTo(0x0E).single.data.length, 15);
    });

    test('setAlarms writes only the first alarm frame', () async {
      await api.setAlarms(<Map<String, Object?>>[
        <String, Object?>{
          'enabled': true,
          'hasHourlyChime': false,
          'hour': 7,
          'minute': 25,
        },
        <String, Object?>{
          'enabled': true,
          'hasHourlyChime': false,
          'hour': 8,
          'minute': 30,
        },
      ]);
      final writes = watch.writesTo(0x0E);
      expect(writes.length, pythonAlarmsMtgB3000Actions.length);
      for (var i = 0; i < writes.length; i++) {
        expect(writes[i].data, pythonAlarmsMtgB3000Actions[i].data);
      }
    });

    test('getBasicSettings decodes the 12-byte analogue frame', () async {
      watch.respondSettings(pythonSettingsMtgB3000Encoded);
      final settings = await api.getBasicSettings();
      expect(
        settings['button_tone'],
        pythonSettingsMtgB3000Decoded['button_tone'],
      );
      expect(
        settings['power_saving_mode'],
        pythonSettingsMtgB3000Decoded['power_saving_mode'],
      );
      expect(
        settings['light_duration'],
        pythonSettingsMtgB3000Decoded['light_duration'],
      );
    });

    test('setSettings writes the 12-byte analogue frame', () async {
      await api.setSettings(<String, Object?>{
        'time_format': '24h',
        'button_tone': true,
        'auto_light': false,
        'power_saving_mode': true,
        'light_duration': '4s',
        'date_format': 'DD:MM',
        'language': 'French',
      });
      expect(watch.writesTo(0x0E).single.data, pythonSettingsMtgB3000Encoded);
    });

    test('getWatchCondition uses the 280000 analogue request', () async {
      watch.respondWatchCondition();
      await api.getWatchCondition();
      expect(watch.writesTo(0x0C).single.data, <int>[0x28, 0x00, 0x00]);
    });

    test('setTime uses home-time reads (0x24) in the preamble', () async {
      watch
        ..respondDstWatchState()
        ..respondDstForWorldCities()
        ..respondWorldCities('LONDON')
        ..respondHomeTime('LONDON');

      const seconds = 1778000000.0;
      await api.setTime(currentTime: seconds, offset: 0, timezone: 'UTC');

      // MTG-B3000 reads home times for worldCitiesCount slots (2 slots).
      final homeReads = watch
          .writesTo(0x0C)
          .where((w) => w.data[0] == 0x24)
          .length;
      expect(homeReads, watchInfo.worldCitiesCount);
      // And still writes the time frame (before the second-dial sequence).
      final timeWrites = watch.writesTo(0x0E).where((w) => w.data[0] == 0x09);
      expect(timeWrites, isNotEmpty);
    });
  });

  group('analogue watch with second dial (CASIO MTG-B1000)', () {
    test('setTime brackets the second-dial reset sequence', () async {
      final watch = FakeWatch(advertisedName: 'CASIO MTG-B1000')
        ..respondDstWatchState()
        ..respondDstForWorldCities()
        ..respondWorldCities('TOKYO')
        ..respondHomeTime('TOKYO');
      final connection = await watch.connect();
      final api = GshockApi(connection);

      await api.setTime(currentTime: 1778000000.0, offset: 0, timezone: 'UTC');

      final allFeaturesWrites = watch
          .allWritesByHandle()
          .where((w) => w.$1 == 0x0E)
          .map((w) => w.$2)
          .toList(growable: false);
      expect(
        allFeaturesWrites,
        containsAll(<List<int>>[
          <int>[0x21, 0x00, 0x01],
          <int>[0x21, 0x01, 0x01],
        ]),
        reason: 'second-dial 21 00 01 ... 21 01 01 sequence missing',
      );
    });
  });

  group('MIP watch (CASIO GW-BX5600)', () {
    late FakeWatch watch;
    late GshockApi api;

    setUp(() async {
      watch = FakeWatch(advertisedName: 'CASIO GW-BX5600');
      final connection = await watch.connect();
      api = GshockApi(connection);
    });

    test('model resolves to the MIP protocol', () async {
      expect(watchInfo.model, WatchModel.gwBx5600);
      expect(watchInfo.protocol, isA<MipProtocol>());
      expect(watchInfo.hasNewTimeFormat, isTrue);
    });

    test('setTime drives the 4-step SP flow over handles 0x17/0x19', () async {
      const seconds = 1778000000.0;
      await api.setTime(currentTime: seconds, offset: 0, timezone: 'UTC');

      // Steps 1-3: three SP requests on 0x17...
      final spRequests = watch.writesTo(0x17);
      expect(spRequests.length, 3);
      expect(spRequests[0].data[0], 0x05);
      expect(spRequests[1].data[0], 0x03);
      expect(spRequests[2].data[0], 0x06);

      // ...three SP data responses on 0x19...
      final spWrites = watch.writesTo(0x19);
      expect(spWrites.length, 3);
      expect(spWrites[0].data.length, 101); // step 1 write-back
      expect(spWrites[1].data.length, 94); // step 2: 28 + city records
      expect(spWrites[2].data.length, 1 + 6 * 22); // step 3: city names

      // ...and the final time command on 0x0E.
      final now = DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round());
      final timeFrame = watch.writesTo(0x0E).last.data;
      expect(timeFrame.first, 0x09);
      // MIP weekday encoding: 1..7, no decrement.
      expect(timeFrame[8], now.weekday == 7 ? 7 : now.weekday);
      expect(timeFrame.length, 11);
    });

    test('setTime with null time uses the current clock', () async {
      await api.setTime(timezone: 'UTC');
      final spRequests = watch.writesTo(0x17);
      expect(spRequests.length, 3);
      expect(watch.writesTo(0x0E), isNotEmpty);
    });
  });
}
