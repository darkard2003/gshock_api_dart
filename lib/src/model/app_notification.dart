import 'dart:convert';

/// {@category Data Models}
///
/// Notification categories recognized by G-Shock watches supporting notifications (e.g. DW-H5600, GBD-H2000).
enum NotificationType {
  /// General notification.
  generic(0),

  /// High-priority or emergency phone call.
  phoneCallUrgent(1),

  /// Incoming phone call.
  phoneCall(2),

  /// Email message alert.
  email(3),

  /// SMS or text chat message.
  message(4),

  /// Calendar event or reminder alert.
  calendar(5),

  /// Combined email and SMS alert.
  emailSms(6);

  const NotificationType(this.value);

  /// The raw Casio protocol integer code for this notification category.
  final int value;

  /// Resolves a [NotificationType] from its integer wire [value].
  static NotificationType? fromValue(int value) {
    for (final t in NotificationType.values) {
      if (t.value == value) return t;
    }
    return null;
  }
}

/// {@category Data Models}
///
/// Push notification model with UTF-8 length clamping for Casio display screens.
///
/// Casio watches have strict packet length constraints:
/// - Maximum text length: 193 UTF-8 bytes.
/// - Maximum short text length: 40 UTF-8 bytes.
/// - Maximum combined text length: 206 UTF-8 bytes.
/// Strings exceeding these bounds are automatically truncated cleanly without splitting UTF-8 runes.
class AppNotification {
  /// Creates an [AppNotification] with automatic UTF-8 byte truncation.
  AppNotification({
    required this.type,
    required this.timestamp,
    required this.app,
    required this.title,
    required this.text,
    this.shortText = '',
  }) {
    const maxLengthText = 193;
    const maxLengthShortText = 40;
    const maxCombined = 206;

    var textBytes = utf8.encode(text);
    if (textBytes.length > maxLengthText) {
      text = _safeDecode(textBytes.sublist(0, maxLengthText));
    }

    var shortTextBytes = utf8.encode(shortText);
    if (shortTextBytes.length > maxLengthShortText) {
      shortText = _safeDecode(shortTextBytes.sublist(0, maxLengthShortText));
    }

    textBytes = utf8.encode(text);
    shortTextBytes = utf8.encode(shortText);
    final totalLen = textBytes.length + shortTextBytes.length;
    if (totalLen > maxCombined) {
      final allowedTextBytes = maxCombined - shortTextBytes.length;
      final clamped = allowedTextBytes < 0 ? 0 : allowedTextBytes;
      text = _safeDecode(textBytes.sublist(0, clamped));
    }
  }

  /// The notification category.
  final NotificationType type;

  /// ISO 8601 or formatted timestamp of the notification.
  final String timestamp;

  /// Package name or identifier of the emitting application (e.g. `'com.whatsapp'`).
  final String app;

  /// Notification title or sender name displayed on the watch.
  final String title;

  /// Main notification message body (automatically truncated if exceeding 193 UTF-8 bytes).
  String text;

  /// Short preview text or subtitle (automatically truncated if exceeding 40 UTF-8 bytes).
  String shortText;

  static String _safeDecode(List<int> bytes) {
    // Mirrors Python `bytes.decode("utf-8", errors="ignore")`: drop trailing
    // incomplete multi-byte sequences produced by byte-length truncation.
    var candidate = bytes;
    while (candidate.isNotEmpty) {
      try {
        return utf8.decode(candidate);
      } on FormatException {
        candidate = candidate.sublist(0, candidate.length - 1);
      }
    }
    return '';
  }

  Map<String, Object?> toDict() => <String, Object?>{
    'type': type,
    'timestamp': timestamp,
    'app': app,
    'title': title,
    'text': text,
    'short_text': shortText,
  };

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type.value,
    'timestamp': timestamp,
    'app': app,
    'title': title,
    'text': text,
    'short_text': shortText,
  };

  factory AppNotification.fromJson(Map<String, Object?> json) {
    final typeVal = json['type'];
    NotificationType notifType;
    if (typeVal is NotificationType) {
      notifType = typeVal;
    } else if (typeVal is int) {
      notifType =
          NotificationType.fromValue(typeVal) ?? NotificationType.generic;
    } else {
      notifType = NotificationType.generic;
    }
    return AppNotification(
      type: notifType,
      timestamp: '${json['timestamp'] ?? ''}',
      app: '${json['app'] ?? ''}',
      title: '${json['title'] ?? ''}',
      text: '${json['text'] ?? ''}',
      shortText: '${json['short_text'] ?? json['shortText'] ?? ''}',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          timestamp == other.timestamp &&
          app == other.app &&
          title == other.title &&
          text == other.text &&
          shortText == other.shortText;

  @override
  int get hashCode => Object.hash(type, timestamp, app, title, text, shortText);

  @override
  String toString() =>
      'AppNotification(type: $type, app: $app, title: $title, timestamp: $timestamp)';
}
