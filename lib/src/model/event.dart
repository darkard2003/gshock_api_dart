import 'package:timezone/timezone.dart' as tz;

/// Event date value object.
class EventDate {
  const EventDate({required this.year, required this.month, required this.day});

  final int year;
  final String month;
  final int day;

  factory EventDate.fromJson(Map<String, Object?> json) => EventDate(
    year: (json['year'] as num?)?.toInt() ?? 0,
    month: '${json['month'] ?? ''}',
    day: (json['day'] as num?)?.toInt() ?? 0,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'year': year,
    'month': month,
    'day': day,
  };

  bool equals(EventDate eventDate) =>
      eventDate.year == year &&
      eventDate.month == month &&
      eventDate.day == day;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventDate &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month &&
          day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => 'year: $year, month: $month, day: $day';
}

/// Repeat-period constants.
class RepeatPeriod {
  RepeatPeriod._();

  static const String never = 'NEVER';
  static const String daily = 'DAILY';
  static const String weekly = 'WEEKLY';
  static const String monthly = 'MONTHLY';
  static const String yearly = 'YEARLY';
}

const List<String> dayOfWeek = <String>[
  'MONDAY',
  'TUESDAY',
  'WEDNESDAY',
  'THURSDAY',
  'FRIDAY',
  'SATURDAY',
  'SUNDAY',
];

const List<String> monthNames = <String>[
  'JANUARY',
  'FEBRUARY',
  'MARCH',
  'APRIL',
  'MAY',
  'JUNE',
  'JULY',
  'AUGUST',
  'SEPTEMBER',
  'OCTOBER',
  'NOVEMBER',
  'DECEMBER',
];

/// Creates an [EventDate] from a Unix timestamp (ms) and IANA zone.
EventDate createEventDate(double timeMs, String zoneName) {
  final location = tz.getLocation(zoneName);
  final start = tz.TZDateTime.fromMillisecondsSinceEpoch(
    location,
    timeMs.round(),
  );
  return EventDate(year: start.year, month: '${start.month}', day: start.day);
}

/// Event/reminder model.
class Event {
  Event({
    this.title = '',
    this.startDate,
    this.endDate,
    this.repeatPeriod = RepeatPeriod.never,
    this.daysOfWeek,
    this.enabled = false,
    this.incompatible = false,
    this.selected = false,
  });

  String title;
  EventDate? startDate;
  EventDate? endDate;
  String repeatPeriod;
  List<String>? daysOfWeek;
  bool enabled;
  bool incompatible;
  bool selected;

  String _stringToRepeatPeriod(String? value) {
    switch (value?.toLowerCase()) {
      case 'daily':
        return RepeatPeriod.daily;
      case 'weekly':
        return RepeatPeriod.weekly;
      case 'monthly':
        return RepeatPeriod.monthly;
      case 'yearly':
        return RepeatPeriod.yearly;
      case 'never':
        return RepeatPeriod.never;
      default:
        return RepeatPeriod.never;
    }
  }

  EventDate? _toEventDate(Object? value) {
    if (value is EventDate) return value;
    if (value is Map) {
      return EventDate(
        year: (value['year'] as num?)?.toInt() ?? 0,
        month: '${value['month'] ?? ''}',
        day: (value['day'] as num?)?.toInt() ?? 0,
      );
    }
    return null;
  }

  /// Populates the event from a JSON-like map.
  Event createEvent(Map<String, Object?> eventJson) {
    final timeObj =
        (eventJson['time'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};

    title = (eventJson['title'] as String?) ?? title;
    startDate = _toEventDate(timeObj['start_date']) ?? startDate;
    endDate = _toEventDate(timeObj['end_date']) ?? endDate;
    daysOfWeek =
        (timeObj['days_of_week'] as List?)?.cast<String>() ?? daysOfWeek;

    enabled = timeObj['enabled'] == true;
    incompatible = timeObj['incompatible'] == true;
    selected = timeObj['selected'] == true;
    repeatPeriod = _stringToRepeatPeriod(timeObj['repeat_period'] as String?);

    return this;
  }

  Map<String, Object?> toJson({
    String? title,
    EventDate? startDate,
    EventDate? endDate,
    String? repeatPeriod,
    List<String>? daysOfWeek,
    bool? enabled,
    bool? incompatible,
    bool? selected,
  }) {
    final currentTitle = title ?? this.title;
    final currentStartDate = startDate ?? this.startDate;
    var currentEndDate = endDate ?? this.endDate;
    final currentRepeatPeriod = repeatPeriod ?? this.repeatPeriod;
    final currentDaysOfWeek = daysOfWeek ?? this.daysOfWeek;
    final currentEnabled = enabled ?? this.enabled;
    final currentIncompatible = incompatible ?? this.incompatible;
    final currentSelected = selected ?? this.selected;

    final timeJson = <String, Object?>{
      'repeatPeriod': currentRepeatPeriod,
      'daysOfWeek': currentDaysOfWeek,
      'enabled': currentEnabled,
      'incompatible': currentIncompatible,
      'selected': currentSelected,
    };

    if (currentStartDate == null) {
      throw ArgumentError(
        'Event must have a start date to be converted to JSON.',
      );
    }

    timeJson['start_date'] = currentStartDate.toJson();
    currentEndDate ??= currentStartDate;
    timeJson['end_date'] = currentEndDate.toJson();

    return <String, Object?>{'title': currentTitle, 'time': timeJson};
  }

  factory Event.fromJson(Map<String, Object?> json) {
    final event = Event();
    event.createEvent(json);
    return event;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Event &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          repeatPeriod == other.repeatPeriod &&
          _listEquals(daysOfWeek, other.daysOfWeek) &&
          enabled == other.enabled &&
          incompatible == other.incompatible &&
          selected == other.selected;

  @override
  int get hashCode => Object.hash(
    title,
    startDate,
    endDate,
    repeatPeriod,
    daysOfWeek == null ? null : Object.hashAll(daysOfWeek!),
    enabled,
    incompatible,
    selected,
  );

  @override
  String toString() =>
      'Event(title: $title, startDate: $startDate, endDate: $endDate, '
      'repeatPeriod: $repeatPeriod, enabled: $enabled)';
}

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
