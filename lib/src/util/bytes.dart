import 'dart:convert';
import 'dart:typed_data';

/// Pure byte/hex helpers mirroring `gshock_api/src/gshock_api/utils.py`.
///
/// Kept platform- and BLE-free so they can be unit-tested without a device.
class Bytes {
  const Bytes._();

  static const String hexPrefix = '0x';
  static const String nullChar = '\u0000';

  static final List<String> _byteToHex = List.generate(
    256,
    (i) => i.toRadixString(16).padLeft(2, '0').toUpperCase(),
    growable: false,
  );

  static final Int8List _hexNibbles = () {
    final table = Int8List(256)..fillRange(0, 256, -1);
    for (var i = 0; i <= 9; i++) {
      table[0x30 + i] = i;
    }
    for (var i = 0; i < 6; i++) {
      table[0x61 + i] = 10 + i;
      table[0x41 + i] = 10 + i;
    }
    return table;
  }();

  /// Converts a compact hexadecimal string (e.g. `'A3010C'`) into bytes.
  ///
  /// Mirrors Python `utils.to_casio_cmd`. Slices into 2-character parts
  /// (with a single-character tail if odd-length) and parses base 16.
  static Uint8List fromCasioCmd(String bytesStr) {
    final trimmed = bytesStr.trim();
    if (trimmed.isEmpty) return Uint8List(0);
    final len = trimmed.length;
    final count = (len + 1) ~/ 2;
    final result = Uint8List(count);
    var byteIdx = 0;

    for (var i = 0; i < len; i += 2) {
      final c1 = trimmed.codeUnitAt(i);
      final n1 = c1 < 256 ? _hexNibbles[c1] : -1;
      if (i + 1 < len) {
        final c2 = trimmed.codeUnitAt(i + 1);
        final n2 = c2 < 256 ? _hexNibbles[c2] : -1;
        if (n1 >= 0 && n2 >= 0) {
          result[byteIdx++] = (n1 << 4) | n2;
          continue;
        }
      } else if (n1 >= 0) {
        result[byteIdx++] = n1;
        continue;
      }
      final end = (i + 2 <= len) ? i + 2 : len;
      result[byteIdx++] = int.parse(
        trimmed.substring(i, end).trim(),
        radix: 16,
      );
    }
    return result;
  }

  /// Converts a space-separated hex string (e.g. `'0xA3 0x01 0x0C'`) into ints.
  ///
  /// Mirrors Python `utils.to_int_array`.
  static List<int> toIntArray(String hexStr) {
    final ints = <int>[];
    for (var part in hexStr.split(' ')) {
      if (part.startsWith(hexPrefix)) {
        part = removePrefix(part, hexPrefix);
      }
      if (part.isNotEmpty) {
        ints.add(int.parse(part, radix: 16));
      }
    }
    return ints;
  }

  /// Removes spaces and optional `0x` prefixes (`'0x01 0x2A'` -> `'012A'`).
  ///
  /// Mirrors Python `utils.to_compact_string`.
  static String toCompactString(String hexStr) {
    final buffer = StringBuffer();
    for (var part in hexStr.split(' ')) {
      if (part.startsWith(hexPrefix)) {
        part = removePrefix(part, hexPrefix);
      }
      buffer.write(part);
    }
    return buffer.toString();
  }

  /// Formats bytes as a space-separated, `0x`-prefixed hex string.
  ///
  /// Mirrors Python `utils.to_hex_string` (e.g. `01 2A` -> `0x01 2A`).
  static String toHexString(List<int> byteArr) {
    if (byteArr.isEmpty) return hexPrefix;
    final buffer = StringBuffer(hexPrefix);
    for (var i = 0; i < byteArr.length; i++) {
      if (i > 0) buffer.write(' ');
      buffer.write(_byteToHex[byteArr[i] & 0xFF]);
    }
    return buffer.toString();
  }

  /// Removes [prefix] from the start of [inputString] if present.
  ///
  /// Mirrors Python `utils.remove_prefix`.
  static String removePrefix(String inputString, String prefix) {
    return inputString.startsWith(prefix)
        ? inputString.substring(prefix.length)
        : inputString;
  }

  /// Converts a hex string containing ASCII into a string, skipping the first
  /// [commandLengthToSkip] bytes.
  ///
  /// Mirrors Python `utils.to_ascii_string`.
  static String toAsciiString(String hexStr, int commandLengthToSkip) {
    List<String> partsWithCommand;
    if (!hexStr.contains(' ') && hexStr.length.isEven) {
      partsWithCommand = [
        for (var i = 0; i < hexStr.length; i += 2) hexStr.substring(i, i + 2),
      ];
    } else {
      partsWithCommand = hexStr.split(' ');
    }

    final parts = partsWithCommand.sublist(commandLengthToSkip);
    final asciiHex = parts.join();
    return latin1.decode(fromCasioCmd(asciiHex));
  }

  /// Removes the null character used for padding.
  ///
  /// Mirrors Python `utils.trim_non_ascii_characters`.
  static String trimNonAsciiCharacters(String inputString) {
    return inputString.replaceAll(nullChar, '');
  }

  /// Returns the current time in milliseconds since the epoch.
  ///
  /// Mirrors Python `utils.current_milli_time`.
  static int currentMilliTime() => DateTime.now().millisecondsSinceEpoch;

  static final Set<int> _printable = () {
    final set = <int>{};
    for (final code
        in '0123456789'
                'abcdefghijklmnopqrstuvwxyz'
                'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
                '!"#\$%&\'()*+,-./:;<=>?@[\\]^_`{|}~ \t\n\r\u000B\u000C'
            .codeUnits) {
      set.add(code);
    }
    return set;
  }();

  /// Removes non-printable ASCII characters from a string.
  ///
  /// Mirrors Python `utils.clean_str` (Python's `string.printable` set).
  static String cleanStr(String dirtyStr) {
    final buffer = StringBuffer();
    for (final unit in dirtyStr.codeUnits) {
      if (_printable.contains(unit)) buffer.writeCharCode(unit);
    }
    return buffer.toString();
  }

  /// Encodes [inputString] as UTF-8, padding with nulls or truncating to
  /// exactly [maxLen] bytes.
  ///
  /// Mirrors Python `utils.to_byte_array`.
  static Uint8List toByteArray(String inputString, int maxLen) {
    final encoded = utf8.encode(inputString);
    if (encoded.length > maxLen) {
      return Uint8List.fromList(encoded.sublist(0, maxLen));
    }
    if (encoded.length < maxLen) {
      final out = Uint8List(maxLen);
      out.setRange(0, encoded.length, encoded);
      return out;
    }
    return Uint8List.fromList(encoded);
  }

  /// Converts a string to a compact lowercase hex string.
  ///
  /// Mirrors Python `utils.to_hex_string_compact` (unused, kept for parity).
  static String toHexStringCompact(String asciiStr, int _) {
    final buffer = StringBuffer();
    for (final byte in ascii.encode(asciiStr)) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// Converts a decimal integer to its "hexadecimal integer value".
  ///
  /// Mirrors Python `utils.dec_to_hex`. Throws when the hexadecimal
  /// representation contains non-decimal digits, exactly like Python.
  static int decToHex(int dec) {
    return int.parse(dec.toRadixString(16));
  }

  /// Encodes an ASCII string into a padded, compact, uppercase hex string.
  ///
  /// Mirrors Python `utils.encode_string`.
  static String encodeString(String asciiString, int maxLen) {
    final intArr = asciiString.codeUnits.toList();
    while (intArr.length < maxLen) {
      intArr.add(0);
    }
    return intArr
        .map((i) => i.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join();
  }

  /// Alias kept for the previously scaffolded API.
  static String hexStringCompact(String asciiStr, int maxLen) =>
      toHexStringCompact(asciiStr, maxLen);
}
