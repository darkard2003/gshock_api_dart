import 'dart:convert';

/// Notification types mirroring `NotificationType` in `app_notification.py`.
enum NotificationType {
  generic(0),
  phoneCallUrgent(1),
  phoneCall(2),
  email(3),
  message(4),
  calendar(5),
  emailSms(6);

  const NotificationType(this.value);

  final int value;

  static NotificationType? fromValue(int value) {
    for (final t in NotificationType.values) {
      if (t.value == value) return t;
    }
    return null;
  }
}

/// App notification model with UTF-8-aware truncation.
class AppNotification {
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

  final NotificationType type;
  final String timestamp;
  final String app;
  final String title;
  String text;
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
