import 'dart:convert';
import 'dart:typed_data';

import 'package:gshock_api_dart/gshock_api_dart.dart';
import 'package:test/test.dart';

import 'golden/python_reference.dart';
import 'helpers.dart';

/// Byte-level golden tests: every encoder/decoder compared against outputs
/// computed by *executing* the Python reference implementation
/// (see `tool/golden/generate_python_goldens.py`).
///
/// Passing this file means the Dart wire format is byte-identical to Python's.
void main() {
  setUp(resetMigrationState);
  tearDown(resetMigrationState);

  group('time encoding (TimeEncoderPure)', () {
    test('golden timestamps encode byte-identically', () {
      final cases = <String, DateTime>{
        '2026-05-30T08:45:30.123456': DateTime(
          2026,
          5,
          30,
          8,
          45,
          30,
          123,
          456,
        ),
        '2030-12-31T23:59:59.999999': DateTime(
          2030,
          12,
          31,
          23,
          59,
          59,
          999,
          999,
        ),
        '2000-01-01T00:00:00': DateTime(2000, 1, 1),
      };
      for (final entry in cases.entries) {
        expect(
          TimeEncoderPure.encodeCurrentTime(entry.value),
          pythonTimeEncodings[entry.key],
          reason: 'encodeCurrentTime(${entry.key}) diverges from Python',
        );
      }
    });

    test(
      'wire layout: little-endian year, weekday-1, flag (10-byte payload)',
      () {
        // encodeCurrentTime returns the 10-byte payload without the 0x09
        // command byte (prepareWatchCommands prepends it).
        final bytes = TimeEncoderPure.encodeCurrentTime(
          DateTime(2026, 5, 30, 8, 45, 30, 123, 456),
        );
        expect(bytes.length, 10);
        expect(bytes[0], 2026 & 0xFF); // year low byte
        expect(bytes[1], (2026 >> 8) & 0xFF); // year high byte
        expect(bytes[2], 5); // month
        expect(bytes[3], 30); // day
        expect(bytes[6], 30); // seconds
        expect(
          bytes[7],
          6 - 1,
        ); // Saturday: DateTime.weekday (Mon=1..Sat=6) - 1
        final expectedNanoByte = (123456000 * 256 ~/ 1000000000) & 0xFF;
        expect(bytes[8], expectedNanoByte); // nanos byte
        expect(bytes[9], 0x01); // always-set flag
      },
    );

    test('legacy encoder agrees with the pure encoder (fixed DateTime)', () {
      final dt = DateTime(2026, 5, 30, 8, 45, 30, 123, 456);
      expect(
        TimeEncoder.prepareCurrentTime(dt),
        TimeEncoderPure.encodeCurrentTime(dt),
      );
    });
  });

  group('alarms', () {
    test('SET_ALARMS write sequence matches Python (standard)', () {
      // Golden generation values: the Python generator encoded exactly
      // these five alarms.
      final alarmsJson = jsonEncode(<String, Object?>{
        'value': <Map<String, Object?>>[
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
        ],
      });
      expect(
        AlarmsIOFunctional.prepareWatchCommandsSet(alarmsJson),
        _matchesActions(pythonAlarmsSetActions),
        reason: 'SET_ALARMS write sequence diverges from Python',
      );
    });

    test('SET_ALARMS for MTG-B3000 writes only the first alarm', () {
      final alarmsJson = jsonEncode(<String, Object?>{
        'value': <Map<String, Object?>>[
          <String, Object?>{
            'enabled': true,
            'hasHourlyChime': false,
            'hour': 7,
            'minute': 25,
          },
        ],
      });
      expect(
        AlarmsIOFunctional.prepareWatchCommandsSetMtgB3000(alarmsJson),
        _matchesActions(pythonAlarmsMtgB3000Actions),
      );
    });

    test('alarm packet parse matches Python (including hourly chime bit)', () {
      // 0x15 notification: command byte + 4 bytes per alarm, 5 alarms.
      final packet = Uint8List.fromList(<int>[
        0x15,
        ...List<int>.generate(20, (i) => <int>[0x40, 0x40, 7, 25][i % 4]),
      ]);
      final parsed = AlarmsIOFunctional.parsePacket(packet);
      expect(parsed.length, pythonAlarmsParsed.length);
      for (var i = 0; i < parsed.length; i++) {
        expect(parsed[i], pythonAlarmsParsed[i]);
      }
    });
  });

  group('settings', () {
    final settingsDict = <String, Object?>{
      'time_format': '24h',
      'button_tone': true,
      'auto_light': false,
      'power_saving_mode': true,
      'light_duration': '4s',
      'date_format': 'DD:MM',
      'language': 'French',
    };

    test('settings encode/decode match Python (GW-B5600 model context)', () {
      // GW-B5600 longLightDuration is '4s', matching the golden generation.
      watchInfo.setNameAndModel('CASIO GW-B5600');
      final encoded = SettingsIOFunctional.encode(settingsDict);
      expect(encoded, pythonSettingsEncoded);
      expect(SettingsIOFunctional.decode(encoded), pythonSettingsDecoded);
    });

    test('settings encode/decode match Python (MTG-B3000, 12-byte frames)', () {
      watchInfo.setNameAndModel('CASIO MTG-B3000');
      final encoded = SettingsIOFunctional.encodeMtgB3000(settingsDict);
      expect(encoded, pythonSettingsMtgB3000Encoded);
      expect(
        SettingsIOFunctional.decodeMtgB3000(encoded),
        pythonSettingsMtgB3000Decoded,
      );
    });
  });

  group('timer', () {
    test('encode 3665s matches Python', () {
      expect(TimerIOFunctional.encode(3665), pythonTimerEncoded);
      expect(
        TimerIOFunctional.decode(Uint8List.fromList(pythonTimerEncoded)),
        pythonTimerDecoded,
      );
    });

    test(
      'SET_TIMER write sequence matches Python (standard and MTG-B3000)',
      () {
        expect(
          TimerIOFunctional.prepareWatchCommandsSet(
            jsonEncode(<String, Object?>{'value': 3665}),
          ),
          _matchesActions(pythonTimerSetActions),
        );
        expect(
          TimerIOFunctional.prepareWatchCommandsSetMtgB3000(
            jsonEncode(<String, Object?>{'value': 600}),
          ),
          _matchesActions(pythonTimerMtgB3000SetActions),
        );
      },
    );

    test('MTG-B3000 timer frame is 15 bytes like Python', () {
      expect(pythonTimerMtgB3000.length, 15);
      expect(TimerIOFunctional.encodeMtgB3000(600), pythonTimerMtgB3000);
    });
  });

  group('time adjustment', () {
    test('encode matches Python (enabling, 25 minutes after hour)', () {
      final encoded = TimeAdjustmentIOFunctional.encode(
        '0x11 0F 0F 0F 06 00 50 00 04 00 01 00 80 10 D2',
        true,
        25,
      );
      expect(encoded, pythonTimeAdjustmentEncoded);
    });

    test('decode matches Python (string-valued map)', () {
      expect(
        TimeAdjustmentIOFunctional.decode(
          Uint8List.fromList(pythonTimeAdjustmentEncoded),
        ),
        pythonTimeAdjustmentDecoded,
      );
    });
  });

  group('world cities', () {
    test('encodeAndPad produces the same 19-byte frame as Python', () {
      final padded = WorldCitiesIO.encodeAndPad('LONDON', 2);
      expect(padded.length, 19);
      expect(padded, pythonWorldCitiesPadded);
      expect(padded[0], 0x1F); // CASIO_WORLD_CITIES
      expect(padded[1], 2); // city number
    });

    test('parseCity matches Python for sample zones', () {
      for (final entry in pythonParsedCity.entries) {
        expect(WorldCitiesIO.parseCity(entry.key), entry.value);
      }
    });
  });

  group('app notifications', () {
    final notification = AppNotification(
      type: NotificationType.calendar,
      timestamp: '20250516T233000',
      app: 'Calendar',
      title: 'Meeting',
      text: 'Discuss project',
      shortText: 'Meet',
    );

    test('packet bytes match Python exactly', () {
      expect(
        AppNotificationIO.encodeNotificationPacket(notification),
        pythonNotificationEncoded,
      );
    });

    test('XOR-255 buffer matches Python string', () {
      final encoded = AppNotificationIO.encodeNotificationPacket(notification);
      expect(AppNotificationIO.xorEncodeBuffer(encoded), pythonNotificationXor);
    });

    test(
      'decode matches Python (short text is dropped by the decode path)',
      () {
        final decoded = AppNotificationIO.decodeNotificationPacket(
          AppNotificationIO.xorDecodeBuffer(pythonNotificationXor),
        );
        expect(
          decoded.type.name.toUpperCase(),
          pythonNotificationDecoded['type'],
        );
        expect(decoded.timestamp, pythonNotificationDecoded['timestamp']);
        expect(decoded.app, pythonNotificationDecoded['app']);
        expect(decoded.title, pythonNotificationDecoded['title']);
        expect(decoded.text, pythonNotificationDecoded['text']);
        // Python's decode does not restore the short-text field.
        expect(decoded.shortText, pythonNotificationDecoded['short_text']);
      },
    );
  });

  group('events / reminders', () {
    test('SET_REMINDERS write sequence matches Python (weekly)', () {
      final eventsJson = jsonEncode(<String, Object?>{
        'value': <Map<String, Object?>>[
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
        ],
      });
      expect(
        EventsIOFunctional.prepareWatchCommandsSet(eventsJson),
        _matchesActions(pythonEventsSetActions),
      );
    });

    test('decodeTime matches Python for a weekly notification frame', () {
      // Notification frame: 0x31, slot, time-period byte, start(3), end(3),
      // day-of-week byte (MONDAY | FRIDAY = 0x02 | 0x20 here).
      final frame = <int>[
        0x31,
        0x01,
        0x01 | 0x04,
        0x25,
        0x05,
        0x16,
        0x25,
        0x05,
        0x17,
        0x02 | 0x20,
      ];
      final hex = Bytes.toHexString(frame).substring(2);
      final decoded = EventsIOFunctional.decodeTime(hex);
      final expected = (jsonDecode(pythonEventsDecodedTimeJson) as Map)
          .cast<String, Object?>();
      expect(decoded, expected);
    });
  });

  group('step counter', () {
    test(
      'parse matches Python on the golden payload (sentinels + warnings)',
      () {
        final data = StepCounterIOFunctional.parse(
          Uint8List.fromList(pythonStepCounterPayload),
        )!;
        expect(
          data.currentDaySteps,
          pythonStepCounterParsed['currentDaySteps'],
        );
        expect(data.month, pythonStepCounterParsed['month']);
        expect(data.dayOfMonth, pythonStepCounterParsed['dayOfMonth']);
        expect(data.hourlySteps, pythonStepCounterParsed['hourlySteps']);
        expect(data.dailyHistory, pythonStepCounterParsed['dailyHistory']);
        expect(data.dailyDistances, pythonStepCounterParsed['dailyDistances']);
        expect(data.distanceMeters, pythonStepCounterParsed['distanceMeters']);
        expect(
          data.totalDistanceMeters,
          pythonStepCounterParsed['totalDistanceMeters'],
        );
        expect(data.bcdTotalSteps, pythonStepCounterParsed['bcdTotalSteps']);
        expect(data.warnings, pythonStepCounterParsed['warnings']);
        expect(data.timestamp, pythonStepCounterParsed['timestamp']);
        expect(data.dayOfWeek, pythonStepCounterParsed['dayOfWeek']);
      },
    );

    test('sentinel buckets map to null like Python', () {
      // The two 0xFFFE hourly buckets are dropped from hourly steps.
      expect(pythonStepCounterParsed['hourlySteps'], isNot(contains(65534)));
      // The 0xFFFFFFFE day is reported as null in the history.
      expect((pythonStepCounterParsed['dailyHistory'] as List)[0], isNull);
    });
  });

  group('GW-BX5600 world-city records', () {
    test('record layout matches Python (UTC-local golden)', () {
      final records = GwBx5600TimeIO.buildWorldCityRecords();
      expect(records.length, pythonGwBx5600Records.length);
      // Each 22-byte record starts with the city write header
      // [0x14, 0x00, 0x24, slot, enabled].
      for (var i = 0; i + 22 <= records.length; i += 22) {
        expect(records.sublist(i, i + 4), <int>[0x14, 0x00, 0x24, i ~/ 22]);
        expect(records[i + 4], 0x01);
      }
      // Exact byte comparison holds when running in the same local
      // timezone the golden was generated in (UTC).
      final localZone = CasioTimeZoneHelper.getLocalCasioTimeZone().zoneName;
      if (localZone == 'UTC') {
        expect(records, pythonGwBx5600Records);
      }
    });
  });

  group('button pressed', () {
    test('decode matches Python', () {
      // Button notifications carry the button code in byte 8.
      final payload = <int>[
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
      ];
      final decoded = ButtonPressedIOFunctional.decode(
        Uint8List.fromList(payload),
      );
      // Dart enum name lowerLeft -> Python LOWER_LEFT; normalize separators.
      expect(
        decoded.name.toUpperCase().replaceAll('_', ''),
        (pythonButtonDecodes['upperLeft'] as String).replaceAll('_', ''),
      );
    });
  });

  group('watch condition', () {
    test('decode matches Python (battery + temperature)', () {
      final decoded = WatchConditionIOFunctional.decode(
        Uint8List.fromList(<int>[0x28, 9, 21]),
      );
      expect(
        decoded['battery_level_percent'],
        pythonConditionDecoded['battery_level_percent'],
      );
      expect(decoded['temperature'], pythonConditionDecoded['temperature']);
    });
  });

  group('app info', () {
    test('0xFF trigger response writes match Python', () {
      final trigger = Uint8List.fromList(<int>[
        0x22,
        ...List<int>.filled(10, 0xFF),
        0x00,
      ]);
      expect(
        AppInfoIOFunctional.prepareWatchResponse(trigger),
        _matchesActions(pythonAppInfoResponse),
      );
    });
  });
}

/// Matcher: a [BleAction] list equals the golden (handle, bytes) sequence.
Matcher _matchesActions(List<GoldenAction> golden) {
  return predicate<List<BleAction>>((actions) {
    if (actions.length != golden.length) return false;
    for (var i = 0; i < actions.length; i++) {
      final action = actions[i];
      if (action is! WriteAction) return false;
      if (action.handle != golden[i].handle) return false;
      final data = action.data;
      if (data.length != golden[i].data.length) return false;
      for (var b = 0; b < data.length; b++) {
        if (data[b] != golden[i].data[b]) return false;
      }
    }
    return true;
  }, 'matches the Python golden action sequence');
}
