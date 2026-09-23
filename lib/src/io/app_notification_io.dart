import 'dart:convert';
import 'dart:typed_data';

import '../model/app_notification.dart';

/// Result of reading a length-prefixed string.
/// @nodoc
class StringResult {
  const StringResult(this.string, this.offset);

  final String string;
  final int offset;
}

/// App-notification codec mirroring `iolib/app_notification_io.py`.
///
/// Quirk D4: Python declares `xor_encode_buffer` without `self`; we implement
/// it as a normal static helper.
/// @nodoc
class AppNotificationIO {
  AppNotificationIO._();

  /// Decodes a hex-encoded buffer using XOR with [key].
  static Uint8List xorDecodeBuffer(String buffer, {int key = 255}) {
    final clean = buffer.replaceAll(' ', '');
    final len = clean.length ~/ 2;
    final out = Uint8List(len);
    for (var i = 0; i < len; i++) {
      final byte = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
      out[i] = (byte ^ key) & 0xFF;
    }
    return out;
  }

  /// Encodes bytes using XOR with [key], returning lowercase hex.
  static String xorEncodeBuffer(Uint8List decodedBytes, {int key = 255}) {
    final buffer = StringBuffer();
    for (final b in decodedBytes) {
      buffer.write(((b ^ key) & 0xFF).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static StringResult readLengthPrefixedString(Uint8List buf, int offset) {
    if (offset + 2 > buf.length) {
      throw ArgumentError('Not enough data to read length prefix');
    }

    final length = buf[offset];
    if (buf[offset + 1] != 0x00) {
      throw ArgumentError('Expected null second byte in length prefix');
    }

    final start = offset + 2;
    final end = start + length;
    if (end > buf.length) {
      throw ArgumentError('String length exceeds buffer');
    }

    final string = utf8.decode(buf.sublist(start, end), allowMalformed: true);
    return StringResult(string, end);
  }

  /// Decodes a G-Shock calendar notification buffer.
  static AppNotification decodeNotificationPacket(Uint8List buf) {
    if (buf.length < 6) {
      throw ArgumentError('Buffer too short');
    }

    var offset = 6;

    final notifType = buf[offset];
    final notifTypeEnum = NotificationType.fromValue(notifType);
    offset += 1;

    final timestampRaw = ascii.decode(buf.sublist(offset, offset + 15));
    offset += 15;

    final appRes = readLengthPrefixedString(buf, offset);
    final app = appRes.string;
    offset = appRes.offset;

    final titleRes = readLengthPrefixedString(buf, offset);
    final title = titleRes.string;
    offset = titleRes.offset;

    final emptyRes = readLengthPrefixedString(buf, offset);
    offset = emptyRes.offset;

    final textRes = readLengthPrefixedString(buf, offset);
    final text = textRes.string;
    offset = textRes.offset;

    return AppNotification(
      type: notifTypeEnum ?? NotificationType.generic,
      timestamp: timestampRaw,
      app: app,
      title: title,
      text: text,
    );
  }

  static final Uint8List _notificationHeader = Uint8List.fromList(<int>[
    0,
    0,
    0,
    0,
    0,
    1,
  ]);

  /// Encodes a string as `[length][0x00][UTF-8 bytes]`.
  static Uint8List writeLengthPrefixedString(String text) {
    final encoded = utf8.encode(text);
    if (encoded.length > 255) {
      throw ArgumentError('Encoded string too long');
    }
    final buffer = Uint8List(encoded.length + 2);
    buffer[0] = encoded.length;
    buffer[1] = 0x00;
    buffer.setRange(2, buffer.length, encoded);
    return buffer;
  }

  /// Encodes an [AppNotification] into the G-Shock BLE buffer.
  static Uint8List encodeNotificationPacket(AppNotification data) {
    final result = <int>[];
    result.addAll(_notificationHeader);
    result.add(data.type.value);
    result.addAll(ascii.encode(data.timestamp));
    result.addAll(writeLengthPrefixedString(data.app));
    result.addAll(writeLengthPrefixedString(data.title));
    result.addAll(writeLengthPrefixedString(data.shortText));
    result.addAll(writeLengthPrefixedString(data.text));
    return Uint8List.fromList(result);
  }
}
