import 'dart:typed_data';

import 'package:gshock_api_dart/gshock_api_dart.dart';
import 'package:test/test.dart';

void main() {
  late AnalogueProtocol protocol;

  setUp(() {
    protocol = AnalogueProtocol();
  });

  group('AnalogueProtocol envelope handling', () {
    test('extractKey returns null for empty data', () {
      expect(protocol.extractKey(Uint8List(0)), isNull);
    });

    test('extractKey unwraps 0x28 packet with data[1] == 0x01 (offset 4)', () {
      // 0x28, 0x01, xx, xx, key (0x23 = CASIO_WATCH_NAME), payload...
      final data = Uint8List.fromList(<int>[
        0x28,
        0x01,
        0x00,
        0x00,
        0x23, // key
        0x47, // 'G'
        0x2D, // '-'
      ]);
      expect(protocol.extractKey(data), 0x23);
    });

    test('extractKey unwraps 0x28 packet with data[1] == 0x00 (offset 3)', () {
      // 0x28, 0x00, xx, key (0x15 = CASIO_SETTING_FOR_ALM), payload...
      final data = Uint8List.fromList(<int>[
        0x28,
        0x00,
        0x00,
        0x15, // key
        0x40,
        0x40,
      ]);
      expect(protocol.extractKey(data), 0x15);
    });

    test(
      'extractKey falls back to 0x28 when enveloped key is not registered',
      () {
        // 0x28, 0x01, xx, xx, unknown key 0x77
        final data = Uint8List.fromList(<int>[0x28, 0x01, 0x00, 0x00, 0x77]);
        expect(protocol.extractKey(data), 0x28);
      },
    );

    test('extractKey returns first byte for non-0x28 packets', () {
      final data = Uint8List.fromList(<int>[0x13, 0x01, 0x02]);
      expect(protocol.extractKey(data), 0x13);
    });

    test(
      'unwrapPayload strips 4 bytes when data[1] == 0x01 and key != 0x28',
      () {
        final data = Uint8List.fromList(<int>[
          0x28,
          0x01,
          0xAA,
          0xBB,
          0x23, // key at index 4
          0x47, // payload start
          0x2D,
        ]);
        final unwrapped = protocol.unwrapPayload(data, 0x23);
        expect(unwrapped, <int>[0x23, 0x47, 0x2D]);
      },
    );

    test(
      'unwrapPayload strips 3 bytes when data[1] == 0x00 and key != 0x28',
      () {
        final data = Uint8List.fromList(<int>[
          0x28,
          0x00,
          0xAA,
          0x15, // key at index 3
          0x40,
          0x40,
        ]);
        final unwrapped = protocol.unwrapPayload(data, 0x15);
        expect(unwrapped, <int>[0x15, 0x40, 0x40]);
      },
    );

    test('unwrapPayload leaves raw 0x28 packet intact when key == 0x28', () {
      final data = Uint8List.fromList(<int>[0x28, 0x09, 0x15]);
      expect(protocol.unwrapPayload(data, 0x28), data);
    });
  });

  group('AnalogueProtocol constants', () {
    test('getWatchConditionRequest is 280000', () {
      expect(protocol.getWatchConditionRequest(), '280000');
    });

    test('timer parameters match MTG analogue specs', () {
      expect(protocol.getTimerRequest(), '182000');
      expect(protocol.getTimerSize(), 15);
    });
  });
}
