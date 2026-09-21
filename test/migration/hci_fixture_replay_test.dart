import 'dart:io';
import 'dart:typed_data';

import 'package:gshock_api_dart/gshock_api_dart.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Direction of an HCI packet.
enum HciDirection { writeCmd, writeReq, notify }

/// Parsed record from a BTSnoop text log.
class HciRecord {
  const HciRecord({
    required this.direction,
    required this.handle,
    required this.data,
  });

  final HciDirection direction;
  final int handle;
  final Uint8List data;
}

/// Parses BTSnoop text dumps from `gshock_api/test_data/*.txt`.
class HciTextLogParser {
  static final RegExp _lineRegex = RegExp(
    r'(Write Cmd|Write Req|Notify) Handle:\s*0x([0-9A-Fa-f]+)\s+Value:\s*([0-9A-Fa-f]+)',
  );

  static List<HciRecord> parse(String content) {
    final records = <HciRecord>[];
    for (final line in content.split('\n')) {
      final match = _lineRegex.firstMatch(line);
      if (match == null) continue;

      final typeStr = match.group(1)!;
      final handle = int.parse(match.group(2)!, radix: 16);
      final hexData = match.group(3)!;
      final data = Bytes.fromCasioCmd(hexData);

      final HciDirection direction;
      if (typeStr == 'Notify') {
        direction = HciDirection.notify;
      } else if (typeStr == 'Write Cmd') {
        direction = HciDirection.writeCmd;
      } else {
        direction = HciDirection.writeReq;
      }

      records.add(HciRecord(direction: direction, handle: handle, data: data));
    }
    return records;
  }
}

void main() {
  setUp(resetMigrationState);
  tearDown(resetMigrationState);

  group('HCI Fixture Replay - btsnoop_hci-DW-H5600-1.txt', () {
    late List<HciRecord> records;

    setUpAll(() {
      final file = File('../gshock_api/test_data/btsnoop_hci-DW-H5600-1.txt');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'BTSnoop fixture text file must exist',
      );
      records = HciTextLogParser.parse(file.readAsStringSync());
      expect(records, isNotEmpty);
    });

    test('replays watch name from capture', () {
      final nameRecord = records.firstWhere(
        (r) =>
            r.direction == HciDirection.notify &&
            r.data.isNotEmpty &&
            r.data[0] == 0x23,
      );
      final decodedName = WatchNameIOFunctional.decode(nameRecord.data);
      expect(decodedName, equals('CASIO GW-B5600'));

      watchInfo.setNameAndModel(decodedName);
      expect(watchInfo.model, equals(WatchModel.gw));
      expect(watchInfo.worldCitiesCount, equals(6));
    });

    test('replays button pressed from capture', () {
      final buttonRecord = records.firstWhere(
        (r) =>
            r.direction == HciDirection.notify &&
            r.data.isNotEmpty &&
            r.data[0] == 0x10,
      );
      final button = ButtonPressedIOFunctional.decode(buttonRecord.data);
      expect(button, isA<WatchButton>());
    });

    test('replays timer value from capture', () {
      final timerRecord = records.firstWhere(
        (r) =>
            r.direction == HciDirection.notify &&
            r.data.isNotEmpty &&
            r.data[0] == 0x18,
      );
      // Value: 18 00 04 0F 00 00 00 00 -> 0h, 4m, 15s = 255 seconds
      final seconds = TimerIOFunctional.decode(timerRecord.data);
      expect(seconds, equals(255));
    });

    test('replays reminder title frame from capture', () {
      final reminderTitleRecord = records.firstWhere(
        (r) =>
            r.direction == HciDirection.writeReq &&
            r.data.isNotEmpty &&
            r.data[0] == 0x30,
      );
      // Value: 30 01 486170707920626972746864617921... -> "Happy birthday!"
      final decoded = ReminderDecoder.reminderTitleToJson(
        reminderTitleRecord.data,
      );
      expect(decoded['title'], equals('Happy birthday!'));
    });

    test('replays world city Toronto from capture', () {
      final cityRecord = records.firstWhere(
        (r) =>
            r.direction == HciDirection.notify &&
            r.data.isNotEmpty &&
            r.data[0] == 0x1F,
      );
      // Value: 1F 00 54 4F 52 4F 4E 54 4F...
      final city = String.fromCharCodes(
        cityRecord.data.sublist(2).takeWhile((b) => b != 0),
      );
      expect(city, equals('TORONTO'));
    });

    test('replays watch condition from capture', () {
      final condRecord = records.firstWhere(
        (r) =>
            r.direction == HciDirection.notify &&
            r.data.isNotEmpty &&
            r.data[0] == 0x28,
      );
      // Value: 28 13 1E 00
      final condition = WatchConditionIOFunctional.decode(condRecord.data);
      expect(condition['battery_level_percent'], isNotNull);
      expect(condition['temperature'], isNotNull);
    });
  });

  group('HCI Fixture Replay - btsnoop_hci-bx2.txt (GW-BX5600 MIP)', () {
    late List<HciRecord> records;

    setUpAll(() {
      final file = File('../gshock_api/test_data/btsnoop_hci-bx2.txt');
      expect(file.existsSync(), isTrue);
      records = HciTextLogParser.parse(file.readAsStringSync());
      expect(records, isNotEmpty);
    });

    test('resolves GW-BX5600 model and MIP protocol from capture', () {
      final nameRecord = records.firstWhere(
        (r) =>
            r.direction == HciDirection.notify &&
            r.data.isNotEmpty &&
            r.data[0] == 0x23,
      );
      final decodedName = WatchNameIOFunctional.decode(nameRecord.data);
      expect(decodedName, equals('CASIO GW-BX5600'));

      watchInfo.setNameAndModel(decodedName);
      expect(watchInfo.model, equals(WatchModel.gwBx5600));
      expect(watchInfo.hasNewTimeFormat, isTrue);
      expect(watchInfo.protocol, isA<MipProtocol>());
    });

    test('replays SP configuration sequence and captures time frame 0x09', () {
      // Find the time frame written to handle 0x0E (0x09 EA 07 ...)
      final timeWrite = records.firstWhere(
        (r) => r.handle == 0x000E && r.data.isNotEmpty && r.data[0] == 0x09,
      );

      // Data: 09 EA 07 01 15 16 1A 21 03 EA 01
      // Year: 0x07EA = 2026, Month: 1, Day: 21, Hour: 22 (0x16), Minute: 26 (0x1A), Sec: 33 (0x21)
      final payload = timeWrite.data.sublist(1);
      final year = payload[0] | (payload[1] << 8);
      final month = payload[2];
      final day = payload[3];
      final hour = payload[4];
      final minute = payload[5];
      final second = payload[6];

      expect(year, equals(2026));
      expect(month, equals(1));
      expect(day, equals(21));
      expect(hour, equals(22));
      expect(minute, equals(26));
      expect(second, equals(33));
    });
  });

  group('HCI Fixture Replay - btsnoop_hci_ABL.txt (ABL-100WE Lifelog)', () {
    late List<HciRecord> records;

    setUpAll(() {
      final file = File('../gshock_api/test_data/btsnoop_hci_ABL.txt');
      expect(file.existsSync(), isTrue);
      records = HciTextLogParser.parse(file.readAsStringSync());
      expect(records, isNotEmpty);
    });

    test('resolves ABL-100WE and step counter capability from capture', () {
      final nameRecord = records.firstWhere(
        (r) =>
            r.direction == HciDirection.notify &&
            r.data.isNotEmpty &&
            r.data[0] == 0x23,
      );
      final decodedName = WatchNameIOFunctional.decode(nameRecord.data);
      expect(decodedName, equals('CASIO ABL-100WE'));

      watchInfo.setNameAndModel(decodedName);
      expect(watchInfo.model, equals(WatchModel.abl100));
      expect(watchInfo.hasStepCounter, isTrue);
    });

    test(
      'dispatches real DRSP and Convoy packets through connection routing',
      () {
        final transport = MockTransport();
        final connection = GshockConnection(transport: transport);

        // Verify routing of Convoy notifications (Handle 0x14)
        final convoyNotifs = records.where(
          (r) => r.direction == HciDirection.notify && r.handle == 0x0014,
        );
        expect(convoyNotifs, isNotEmpty);

        // Routing to StepCounterIO does not throw
        for (final notif in convoyNotifs) {
          expect(
            () => connection.handleNotification(
              CasioConstants.casioConvoyCharacteristicUuid,
              notif.data,
            ),
            returnsNormally,
          );
        }
      },
    );
  });
}
