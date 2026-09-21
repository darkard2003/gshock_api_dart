import 'dart:typed_data';

import 'package:gshock_api_dart/gshock_api_dart.dart';
import 'package:test/test.dart';

void main() {
  group('Optimized Bytes and Hex conversions', () {
    test('fromCasioCmd parses even and odd length hex strings correctly', () {
      expect(Bytes.fromCasioCmd(''), equals(Uint8List(0)));
      expect(
        Bytes.fromCasioCmd('A3010C'),
        equals(Uint8List.fromList([0xA3, 0x01, 0x0C])),
      );
      expect(
        Bytes.fromCasioCmd('a3010c'),
        equals(Uint8List.fromList([0xA3, 0x01, 0x0C])),
      );
      expect(
        Bytes.fromCasioCmd(' 1F02 '),
        equals(Uint8List.fromList([0x1F, 0x02])),
      );
      expect(Bytes.fromCasioCmd('A'), equals(Uint8List.fromList([0x0A])));
      expect(
        Bytes.fromCasioCmd('A3010'),
        equals(Uint8List.fromList([0xA3, 0x01, 0x00])),
      );
    });

    test('toHexString formats with 0x prefix and uppercase hex bytes', () {
      expect(Bytes.toHexString([]), equals('0x'));
      expect(Bytes.toHexString([0x01, 0x2A, 0xFF]), equals('0x01 2A FF'));
      expect(Bytes.toHexString([0, 9, 10, 15, 16]), equals('0x00 09 0A 0F 10'));
    });
  });

  group('Model enhancements: Alarm and Settings', () {
    test('Alarm fromJson, equality, hashCode, and toString', () {
      final json = <String, Object?>{
        'hour': 7,
        'minute': 30,
        'enabled': true,
        'hasHourlyChime': false,
      };
      final alarm1 = Alarm.fromJson(json);
      final alarm2 = const Alarm(
        hour: 7,
        minute: 30,
        enabled: true,
        hasHourlyChime: false,
      );
      final alarm3 = const Alarm(
        hour: 8,
        minute: 30,
        enabled: true,
        hasHourlyChime: false,
      );

      expect(alarm1, equals(alarm2));
      expect(alarm1.hashCode, equals(alarm2.hashCode));
      expect(alarm1 == alarm3, isFalse);
      expect(alarm1.toString(), contains('Alarm(hour: 7, minute: 30'));
      expect(alarm1.toJson(), equals(json));
    });

    test('Settings fromJson, equality, hashCode, and toString', () {
      final json = <String, Object?>{
        'time_format': '24h',
        'date_format': 'DD:MM',
        'language': 'English',
        'auto_light': true,
        'light_duration': '2s',
        'power_saving_mode': true,
        'button_tone': false,
        'time_adjustment': true,
        'time_adjustment_minutes_after_hour': 25,
      };

      final s1 = Settings.fromJson(json);
      final s2 = s1.copyWith();
      final s3 = s1.copyWith(language: 'French');

      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));
      expect(s1 == s3, isFalse);
      expect(s1.toString(), contains('Settings(timeFormat: 24h'));
      expect(s1.toJson(), equals(json));
    });
  });

  group('GshockLogger zero-allocation and single message API', () {
    test('logs single message string directly without list wrapping', () {
      final logs = <String>[];
      final testLogger = GshockLogger(
        level: GshockLogLevel.debug,
        sink: (level, message) => logs.add('[${level.name}] $message'),
      );

      testLogger.info('Hello watch');
      testLogger.debug('Debug frame: 0x01');
      testLogger.warn('Low battery');
      testLogger.error('Connection dropped');

      expect(
        logs,
        equals([
          '[info] Hello watch',
          '[debug] Debug frame: 0x01',
          '[warning] Low battery',
          '[error] Connection dropped',
        ]),
      );
    });

    test(
      'silent logger with null sink does not throw or evaluate formatting',
      () {
        final silentLogger = GshockLogger();
        expect(() => silentLogger.info('test message'), returnsNormally);
        expect(() => silentLogger.error(['legacy', 'list']), returnsNormally);
      },
    );
  });

  group('GShockException with cause and stackTrace', () {
    test('preserves cause and formats message with cause in toString', () {
      final cause = FormatException('Bad hex');
      final stack = StackTrace.current;
      final ex = GShockConnectionException('Failed write', cause, stack);

      expect(ex.message, equals('Failed write'));
      expect(ex.cause, equals(cause));
      expect(ex.stackTrace, equals(stack));
      expect(
        ex.toString(),
        contains('Failed write (cause: FormatException: Bad hex)'),
      );
    });
  });

  group('MessageDispatcher direct actions and Map messages', () {
    test(
      'sendToWatch handles raw action strings and Maps without decoding errors',
      () async {
        // Direct action string
        await expectLater(
          MessageDispatcher.sendToWatch('NON_EXISTENT_ACTION'),
          completes,
        );
        // Map with action
        await expectLater(
          MessageDispatcher.sendToWatch(<String, Object?>{'action': 'UNKNOWN'}),
          completes,
        );
        // Legacy JSON string
        await expectLater(
          MessageDispatcher.sendToWatch('{"action": "UNKNOWN"}'),
          completes,
        );
      },
    );
  });

  group('IO Completer lifecycle and try-finally cleanup', () {
    test('AlarmsIO cleans up result even if connection throws', () async {
      final failingConn = FailingConnection();
      await expectLater(
        failingConn.sendMessage('test'),
        throwsA(isA<GShockConnectionException>()),
      );
      await expectLater(
        AlarmsIO.request(failingConn),
        throwsA(isA<GShockConnectionException>()),
      );
      expect(AlarmsIO.result, isNull);
    });

    test('TimerIO cleans up result even if connection throws', () async {
      final failingConn = FailingConnection();
      await expectLater(
        TimerIO.request(failingConn),
        throwsA(isA<GShockConnectionException>()),
      );
      expect(TimerIO.result, isNull);
    });

    test('SettingsIO cleans up result even if connection throws', () async {
      final failingConn = FailingConnection();
      await expectLater(
        SettingsIO.request(failingConn),
        throwsA(isA<GShockConnectionException>()),
      );
      expect(SettingsIO.result, isNull);
    });

    test('WatchNameIO cleans up result even if connection throws', () async {
      final failingConn = FailingConnection();
      await expectLater(
        WatchNameIO.request(failingConn),
        throwsA(isA<GShockConnectionException>()),
      );
      expect(WatchNameIO.result, isNull);
    });
  });

  group('AlwaysConnectedWatchFilter trimming consistency', () {
    test('normalizes untrimmed watch names and prevents throttling bypass', () {
      final filter = AlwaysConnectedWatchFilter();
      const rawName = ' CASIO DW-H5600 ';
      const cleanName = 'CASIO DW-H5600';

      // First connection is allowed
      final allowed1 = filter.connectionFilter(rawName);
      expect(allowed1, isTrue);

      // Verify the timestamp is saved under the trimmed key
      expect(filter.lastConnectedTimes.containsKey(cleanName), isTrue);

      // Immediate second connection with clean or raw name is throttled
      final allowed2 = filter.connectionFilter(rawName);
      expect(allowed2, isFalse);

      final allowed3 = filter.connectionFilter(cleanName);
      expect(allowed3, isFalse);
    });
  });

  group(
    'Model value objects: Event, EventDate, AppNotification, StepCounterData',
    () {
      test('EventDate fromJson, toJson, equality, hashCode, and toString', () {
        final json = <String, Object?>{'year': 2026, 'month': '9', 'day': 19};
        final d1 = EventDate.fromJson(json);
        const d2 = EventDate(year: 2026, month: '9', day: 19);
        const d3 = EventDate(year: 2026, month: '10', day: 19);

        expect(d1, equals(d2));
        expect(d1.hashCode, equals(d2.hashCode));
        expect(d1.equals(d2), isTrue);
        expect(d1 == d3, isFalse);
        expect(d1.toJson(), equals(json));
        expect(d1.toString(), equals('year: 2026, month: 9, day: 19'));
      });

      test('Event fromJson, toJson, equality, hashCode, and toString', () {
        final eventJson = <String, Object?>{
          'title': 'Anniversary',
          'time': <String, Object?>{
            'start_date': {'year': 2026, 'month': '10', 'day': 25},
            'end_date': {'year': 2026, 'month': '10', 'day': 25},
            'repeat_period': 'YEARLY',
            'days_of_week': ['SATURDAY'],
            'enabled': true,
          },
        };

        final ev1 = Event.fromJson(eventJson);
        expect(ev1.title, equals('Anniversary'));
        expect(ev1.repeatPeriod, equals(RepeatPeriod.yearly));
        expect(ev1.enabled, isTrue);
        expect(
          ev1.startDate,
          equals(const EventDate(year: 2026, month: '10', day: 25)),
        );

        final ev2 = Event.fromJson(eventJson);
        expect(ev1, equals(ev2));
        expect(ev1.hashCode, equals(ev2.hashCode));
        expect(ev1.toString(), contains('Event(title: Anniversary'));

        final serialized = ev1.toJson();
        expect(serialized['title'], equals('Anniversary'));
        final timeMap = serialized['time'] as Map<String, Object?>;
        expect(timeMap['repeatPeriod'], equals(RepeatPeriod.yearly));
        expect(timeMap['enabled'], isTrue);
      });

      test(
        'AppNotification fromJson, toJson, equality, hashCode, and toString',
        () {
          final notif = AppNotification(
            type: NotificationType.email,
            timestamp: '2026-09-19T20:00:00Z',
            app: 'com.google.android.gm',
            title: 'Meeting Notes',
            text: 'Review the plan',
            shortText: 'Review',
          );

          final json = notif.toJson();
          expect(json['type'], equals(NotificationType.email.value));
          expect(json['title'], equals('Meeting Notes'));

          final parsed = AppNotification.fromJson(json);
          expect(parsed, equals(notif));
          expect(parsed.hashCode, equals(notif.hashCode));
          expect(parsed.toDict()['app'], equals('com.google.android.gm'));
          expect(
            parsed.toString(),
            contains('AppNotification(type: NotificationType.email'),
          );
        },
      );

      test('StepCounterData toJson and toString', () {
        final now = DateTime(2026, 9, 19, 12, 0);
        final data = StepCounterData(
          timestamp: now,
          currentDaySteps: 8520,
          totalDistanceMeters: 6200,
          warnings: <String>['low battery'],
        );

        final json = data.toJson();
        expect(json['currentDaySteps'], equals(8520));
        expect(json['totalDistanceMeters'], equals(6200));
        expect(json['warnings'], equals(['low battery']));
        expect(data.toString(), contains('StepCounterData('));
        expect(data.toString(), contains('currentDaySteps: 8520'));
      });
    },
  );

  group('TimeEncoderPure direct buffer allocation', () {
    test('encodeCurrentTime produces byte-accurate 10-byte payload', () {
      final dt = DateTime(2026, 9, 19, 14, 30, 45, 500);
      final bytes = TimeEncoderPure.encodeCurrentTime(dt);

      expect(bytes.length, equals(10));
      expect(bytes[0], equals(2026 & 0xFF));
      expect(bytes[1], equals((2026 >> 8) & 0xFF));
      expect(bytes[2], equals(9));
      expect(bytes[3], equals(19));
      expect(bytes[4], equals(14));
      expect(bytes[5], equals(30));
      expect(bytes[6], equals(45));
      expect(bytes[7], equals(dt.weekday - 1)); // 0-indexed day of week
      expect(bytes[9], equals(0x01)); // Flag
    });
  });

  group('Connection and Timezone memoization', () {
    test('GshockConnection handlesMap is unmodifiable and static', () {
      final handles = GshockConnection.initHandlesMap();
      expect(handles.length, equals(11));
      expect(handles[0x04], equals(CasioConstants.casioGetDeviceName));
      expect(
        handles[0x0E],
        equals(CasioConstants.casioAllFeaturesCharacteristicUuid),
      );
      expect(() => handles[0x99] = 'test', throwsUnsupportedError);
    });

    test('GshockConnection direct Uint8List write preserves buffer without reallocation', () async {
      final mock = MockTransport();
      final conn = GshockConnection(
        address: 'AA:BB:CC:DD:EE:FF',
        transport: mock,
      );
      await conn.connect();

      final originalBytes = Uint8List.fromList([0x1D, 0x00]);
      await conn.write(0x0E, originalBytes);

      expect(mock.writes.length, equals(1));
      expect(
        mock.writes.first.uuid,
        equals(CasioConstants.casioAllFeaturesCharacteristicUuid),
      );
      expect(identical(mock.writes.first.data, originalBytes), isTrue);
    });

    test('CasioTimeZone caches seasonal offsets for same year', () {
      final zone = CasioTimeZone('NEW YORK', 'America/New_York', 0x01);
      final dur1 = zone.getDstDuration();
      final dur2 = zone.getDstDuration();

      expect(dur1, equals(const Duration(hours: 1)));
      expect(dur2, equals(dur1));
      expect(zone.offset, equals(-300 ~/ 15)); // UTC-5 in 15-min intervals
    });
  });
}

class FailingConnection implements ConnectionProtocol {
  @override
  Future<void> write(int handle, Object data) async {
    throw GShockConnectionException('Simulated BLE write failure');
  }

  @override
  Future<void> request(Object code) async {
    throw GShockConnectionException('Simulated BLE request failure');
  }

  @override
  Future<void> sendMessage(Object message) async {
    throw GShockConnectionException('Simulated BLE message failure');
  }
}
