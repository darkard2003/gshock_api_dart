import 'package:gshock_api_dart/gshock_api_dart.dart';
import 'package:test/test.dart';

void main() {
  group('Bytes.fromCasioCmd', () {
    test('converts a compact hex command to bytes', () {
      expect(Bytes.fromCasioCmd('A3010C'), equals(<int>[0xA3, 0x01, 0x0C]));
    });

    test('handles odd-length input like Python to_casio_cmd', () {
      expect(Bytes.fromCasioCmd('303'), equals(<int>[0x30, 0x03]));
      expect(Bytes.fromCasioCmd('A30'), equals(<int>[0xA3, 0x00]));
    });
  });

  group('Bytes.toIntArray', () {
    test('parses prefixed space-separated values', () {
      expect(
        Bytes.toIntArray('0xA3 0x01 0x0C'),
        equals(<int>[0xA3, 0x01, 0x0C]),
      );
    });

    test('ignores empty tokens', () {
      expect(Bytes.toIntArray('0xA3  0x01'), equals(<int>[0xA3, 0x01]));
    });
  });

  group('Bytes.toCompactString', () {
    test('strips spaces and prefixes', () {
      expect(Bytes.toCompactString('0x01 0x2A'), equals('012A'));
    });
  });

  group('Bytes.toHexString', () {
    test('formats bytes with 0x prefix', () {
      expect(Bytes.toHexString(<int>[0x01, 0x2A]), equals('0x01 2A'));
    });
  });

  group('Bytes.removePrefix', () {
    test('removes only when present', () {
      expect(Bytes.removePrefix('0xAB', '0x'), 'AB');
      expect(Bytes.removePrefix('AB', '0x'), 'AB');
    });
  });

  group('Bytes.toAsciiString', () {
    test('decodes compact hex skipping command bytes', () {
      expect(Bytes.toAsciiString('23472d53484f434b00', 1), 'G-SHOCK\u0000');
    });

    test('decodes spaced hex skipping command bytes', () {
      expect(Bytes.toAsciiString('0x23 47 2D', 1), 'G-');
    });
  });

  group('Bytes.trimNonAsciiCharacters', () {
    test('strips null characters', () {
      expect(Bytes.trimNonAsciiCharacters('G-SHOCK\u0000'), 'G-SHOCK');
    });
  });

  group('Bytes.cleanStr', () {
    test('keeps printable characters only', () {
      expect(Bytes.cleanStr('A\u0001B\u0000C'), 'ABC');
    });
  });

  group('Bytes.toByteArray', () {
    test('pads short input with nulls', () {
      expect(Bytes.toByteArray('AB', 5), <int>[0x41, 0x42, 0, 0, 0]);
    });

    test('truncates long input', () {
      expect(Bytes.toByteArray('ABCDE', 3), <int>[0x41, 0x42, 0x43]);
    });

    test('is UTF-8 aware', () {
      final bytes = Bytes.toByteArray('é', 3);
      expect(bytes, <int>[0xC3, 0xA9, 0]);
    });
  });

  group('Bytes.encodeString', () {
    test('pads to max length with uppercase hex', () {
      expect(Bytes.encodeString('AB', 3), '414200');
    });
  });

  group('Bytes.decToHex', () {
    test('round-trips BCD decimal digits', () {
      expect(Bytes.decToHex(0x25), 25);
    });
  });

  group('Bytes.toHexStringCompact', () {
    test('formats ASCII as lowercase hex', () {
      expect(Bytes.toHexStringCompact('TEST', 4), '54455354');
    });
  });
}
