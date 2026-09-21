import 'dart:convert';
import 'dart:typed_data';

import 'package:gshock_api_dart/gshock_api_dart.dart';
import 'package:test/test.dart';

import 'fake_watch.dart';
import 'helpers.dart';

/// Verifies the message-dispatcher routing tables against the Python
/// `message_dispatcher.py`: the 11 watch senders and 22 notification
/// handlers must be exactly the same set, and JSON messages must route to
/// the same IO write sequences.
void main() {
  setUp(resetMigrationState);
  tearDown(resetMigrationState);

  group('routing tables', () {
    test('watch senders match Python exactly (11 actions)', () {
      expect(MessageDispatcher.watchSenders.keys.toSet(), <String>{
        'GET_ALARMS',
        'SET_ALARMS',
        'SET_REMINDERS',
        'GET_SETTINGS',
        'SET_SETTINGS',
        'GET_TIME_ADJUSTMENT',
        'SET_TIME_ADJUSTMENT',
        'GET_TIMER',
        'SET_TIMER',
        'SET_TIME',
        'GET_HOME_TIME',
      });
    });

    test('notification handlers match Python exactly (22 keys)', () {
      // Keys extracted from Python's data_received_messages:
      // CHARACTERISTICS[...] values.
      expect(MessageDispatcher.dataReceivedMessages.keys.toSet(), <int>{
        0x10, // CASIO_BLE_FEATURES (button pressed)
        0x11, // CASIO_SETTING_FOR_BLE (time adjustment)
        0x13, // CASIO_SETTING_FOR_BASIC (settings)
        0x15, // CASIO_SETTING_FOR_ALM
        0x16, // CASIO_SETTING_FOR_ALM2
        0x18, // CASIO_TIMER
        0x1D, // CASIO_DST_WATCH_STATE
        0x1E, // CASIO_DST_SETTING
        0x1F, // CASIO_WORLD_CITIES
        0x22, // CASIO_APP_INFORMATION
        0x23, // CASIO_WATCH_NAME
        0x24, // CASIO_HOME_TIME
        0x26, // CASIO_ACTIVITY_RECORD (step counter)
        0x28, // CASIO_WATCH_CONDITION
        0x03, // CMD_SET_TIMEMODE
        0x30, // CASIO_REMINDER_TITLE
        0x31, // CASIO_REMINDER_TIME
        0x47, // UNKNOWN
        0x05, // GW_BX5600_SP_DATA_HEADER_05
        0x06, // GW_BX5600_SP_DATA_HEADER_06
        0x0A, // FIND_PHONE
        0xFF, // ERROR
      });
    });

    test('every Python characteristic code is handled or ignorable', () {
      // Coverage guardrail: any characteristic code the watch may notify
      // about must either have a handler or be a known no-op key.
      const handledOrNoop = <int>{
        0x10,
        0x11,
        0x13,
        0x15,
        0x16,
        0x18,
        0x1D,
        0x1E,
        0x1F,
        0x22,
        0x23,
        0x24,
        0x26,
        0x28,
        0x03,
        0x30,
        0x31,
        0x47,
        0x05,
        0x06,
        0x0A,
        0xFF,
      };
      final dartKeys = MessageDispatcher.dataReceivedMessages.keys.toSet();
      expect(
        dartKeys.difference(handledOrNoop),
        isEmpty,
        reason: 'Dart routes keys Python does not',
      );
      // Python-set keys missing in Dart are reported by the exact-set test.
    });
  });

  group('sendToWatch routing', () {
    late FakeWatch watch;
    late GshockConnection connection;

    setUp(() async {
      watch = FakeWatch();
      connection = await watch.connect();
    });

    test('GET_ALARMS writes both alarm request codes to 0x0C', () async {
      // The senders use the IO static connection, exactly like Python's
      // module-level `AlarmsIO.connection`.
      AlarmsIO.connection = connection;
      await MessageDispatcher.sendToWatch('{"action": "GET_ALARMS"}');
      final reads = watch.writesTo(0x0C);
      expect(reads.length, 2);
      expect(reads[0].data, <int>[0x15]);
      expect(reads[1].data, <int>[0x16]);
    });

    test('SET_TIMER writes the timer frame to 0x0E', () async {
      TimerIO.connection = connection;
      await MessageDispatcher.sendToWatch(
        jsonEncode(<String, Object?>{'action': 'SET_TIMER', 'value': 3665}),
      );
      final writes = watch.writesTo(0x0E);
      expect(writes.length, 1);
      expect(writes[0].data, <int>[0x18, 0x01, 0x01, 0x05, 0x00, 0x00]);
    });

    test('SET_TIME writes the encoded time frame to 0x0E', () async {
      // SET_TIME JSON carries a fixed epoch; the write must equal the pure
      // encoder applied to that instant (local-timezone semantics are
      // identical on both sides of the comparison).
      const seconds = 1778000000;
      final message = TimeIOFunctional.generateRequestMessage(
        seconds.toDouble(),
        0,
      );
      TimeIO.connection = connection;
      await MessageDispatcher.sendToWatch(message);
      final writes = watch.writesTo(0x0E);
      expect(writes.length, 1);
      // prepareWatchCommands prepends the 0x09 current-time command byte.
      expect(writes[0].data, <int>[
        0x09,
        ...TimeEncoderPure.encodeCurrentTime(
          DateTime.fromMillisecondsSinceEpoch(seconds * 1000),
        ),
      ], reason: 'SET_TIME frame differs from the pure time encoder');
      expect(writes[0].data.first, 0x09);
    });

    test('invalid JSON is dropped without writes', () async {
      await MessageDispatcher.sendToWatch('not json');
      expect(watch.transport.writes, isEmpty);
    });

    test('missing action is dropped without writes', () async {
      await MessageDispatcher.sendToWatch('{"value": 1}');
      expect(watch.transport.writes, isEmpty);
    });

    test('unknown action is dropped without writes', () async {
      await MessageDispatcher.sendToWatch('{"action": "NO_SUCH_ACTION"}');
      expect(watch.transport.writes, isEmpty);
    });
  });

  group('onReceived routing', () {
    test('notifications with an unknown key are ignored without throwing', () {
      MessageDispatcher.onReceived(Uint8List.fromList(<int>[0x77, 0x01]));
    });

    test('empty notifications are ignored without throwing', () {
      MessageDispatcher.onReceived(Uint8List(0));
    });

    test('zero-key notifications are ignored (not routed to 0x00)', () {
      // Python extract_key drops leading zero bytes; 0x00 is not a key.
      MessageDispatcher.onReceived(Uint8List.fromList(<int>[0x00, 0x23]));
    });

    test('button notification routes to the pressed-button handler', () async {
      final fake = FakeWatch();
      final connection = await fake.connect();
      fake.respondButton(WatchButton.lowerLeft);
      final api = GshockApi(connection);
      final pending = api.getPressedButton();
      await Future<void>.delayed(Duration.zero);
      expect(await pending, WatchButton.lowerLeft);
    });
  });
}
