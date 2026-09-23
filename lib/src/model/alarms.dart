import '../constants/casio_constants.dart';
import '../util/bytes.dart';
import '../util/logger.dart';

/// Wire bitmask flag indicating the hourly chime is enabled (`0x80`).
const int hourlyChimeMask = 0x80;

/// Wire bitmask flag indicating an alarm slot is active (`0x40`).
const int enabledMask = 0x40;

/// Constant discriminator byte in Casio alarm wire packets (`0x40`).
const int alarmConstantValue = 0x40;

const Map<String, int> _characteristics = CasioConstants.characteristics;

/// {@category Data Models}
///
/// Immutable representation of a single watch alarm slot.
///
/// Holds the scheduled time ([hour], [minute]), active toggle ([enabled]),
/// and whether the hourly time signal beep ([hasHourlyChime]) is enabled.
class Alarm {
  /// Creates an immutable [Alarm].
  const Alarm({
    required this.hour,
    required this.minute,
    required this.enabled,
    this.hasHourlyChime = false,
  });

  /// Deserializes an [Alarm] from a JSON-compatible map.
  factory Alarm.fromJson(Map<String, Object?> json) {
    return Alarm(
      hour: (json['hour'] as int?) ?? 0,
      minute: (json['minute'] as int?) ?? 0,
      enabled: json['enabled'] == true,
      hasHourlyChime: json['hasHourlyChime'] == true,
    );
  }

  /// Alarm hour in 24-hour format (0 to 23).
  final int hour;

  /// Alarm minute (0 to 59).
  final int minute;

  /// Whether this alarm is turned on.
  final bool enabled;

  /// Whether the watch's hourly signal chime is enabled. Only valid on the primary alarm (slot 0).
  final bool hasHourlyChime;

  /// Serializes this alarm to a map.
  Map<String, Object?> toJson() => <String, Object?>{
    'enabled': enabled,
    'hasHourlyChime': hasHourlyChime,
    'hour': hour,
    'minute': minute,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Alarm &&
          runtimeType == other.runtimeType &&
          hour == other.hour &&
          minute == other.minute &&
          enabled == other.enabled &&
          hasHourlyChime == other.hasHourlyChime;

  @override
  int get hashCode => Object.hash(hour, minute, enabled, hasHourlyChime);

  @override
  String toString() =>
      'Alarm(hour: $hour, minute: $minute, enabled: $enabled, hasHourlyChime: $hasHourlyChime)';
}

/// {@category Data Models}
///
/// Mutable alarm collection and Casio BLE wire packet encoder.
class Alarms {
  /// The list of alarm configuration maps managed by this collection.
  final List<Map<String, Object?>> alarms = <Map<String, Object?>>[];

  /// Clears all stored alarms.
  void clear() => alarms.clear();

  /// Appends [alarmJsonArr] to the alarm collection.
  void addAlarms(List<Map<String, Object?>> alarmJsonArr) {
    alarms.addAll(alarmJsonArr);
  }

  /// Encodes the first alarm map into wire bytes for characteristic `CASIO_SETTING_FOR_ALM`.
  List<int> fromJsonAlarmFirstAlarm(Map<String, Object?> alarm) {
    return createFirstAlarm(alarm);
  }

  /// Encodes the primary alarm into Casio wire bytes (`0x15`).
  List<int> createFirstAlarm(Map<String, Object?> alarm) {
    var flag = 0;
    if (alarm['enabled'] == true) flag |= enabledMask;
    if (alarm['hasHourlyChime'] == true) flag |= hourlyChimeMask;

    return <int>[
      _characteristics['CASIO_SETTING_FOR_ALM']!,
      flag,
      alarmConstantValue,
      (alarm['hour'] as int?) ?? 0,
      (alarm['minute'] as int?) ?? 0,
    ];
  }

  /// Encodes secondary alarms (slots 1..4) into wire bytes for characteristic `CASIO_SETTING_FOR_ALM2`.
  List<int> fromJsonAlarmSecondaryAlarms(
    List<Map<String, Object?>> alarmsJson,
  ) {
    if (alarmsJson.length < 2) return <int>[];
    final secondary = alarms.length > 1
        ? alarms.sublist(1)
        : <Map<String, Object?>>[];
    return createSecondaryAlarm(secondary);
  }

  /// Encodes a list of secondary alarms into Casio wire bytes (`0x16`).
  List<int> createSecondaryAlarm(List<Map<String, Object?>> alarms) {
    final allAlarms = <int>[_characteristics['CASIO_SETTING_FOR_ALM2']!];
    for (final alarm in alarms) {
      var flag = 0;
      if (alarm['enabled'] == true) flag |= enabledMask;
      if (alarm['hasHourlyChime'] == true) flag |= hourlyChimeMask;
      allAlarms.addAll(<int>[
        flag,
        alarmConstantValue,
        (alarm['hour'] as int?) ?? 0,
        (alarm['minute'] as int?) ?? 0,
      ]);
    }
    return allAlarms;
  }
}

/// Global alarm instance.
final Alarms alarmsInst = Alarms();

/// @nodoc
class AlarmDecoder {
  Map<String, List<Map<String, Object?>>> toJson(String command) {
    final jsonResponse = <String, List<Map<String, Object?>>>{};
    final intArray = Bytes.toIntArray(command);
    final alarms = <Map<String, Object?>>[];

    if (intArray.isNotEmpty &&
        intArray[0] == _characteristics['CASIO_SETTING_FOR_ALM']) {
      intArray.removeAt(0);
      alarms.add(createJsonAlarm(intArray));
      jsonResponse['ALARMS'] = alarms;
    } else if (intArray.isNotEmpty &&
        intArray[0] == _characteristics['CASIO_SETTING_FOR_ALM2']) {
      intArray.removeAt(0);

      final quarterLen = intArray.length ~/ 4;
      final subarr1 = intArray.sublist(0, quarterLen);
      final subarr2 = intArray.sublist(quarterLen, 2 * quarterLen);
      final subarr3 = intArray.sublist(2 * quarterLen, 3 * quarterLen);
      final subarr4 = intArray.sublist(3 * quarterLen);

      alarms.add(createJsonAlarm(subarr1));
      alarms.add(createJsonAlarm(subarr2));
      alarms.add(createJsonAlarm(subarr3));
      alarms.add(createJsonAlarm(subarr4));

      jsonResponse['ALARMS'] = alarms;
    } else {
      gshockLogger.warning(['Unhandled Command', command]);
    }

    return jsonResponse;
  }

  Map<String, Object?> createJsonAlarm(List<int> intArray) {
    final alarm = Alarm(
      hour: intArray[2],
      minute: intArray[3],
      enabled: (intArray[0] & enabledMask) != 0,
      hasHourlyChime: (intArray[0] & hourlyChimeMask) != 0,
    );
    return toJsonNewAlarm(alarm);
  }

  Map<String, Object?> toJsonNewAlarm(Alarm alarm) => alarm.toJson();
}

/// Global alarm decoder (mirrors Python's module global `alarm_decoder`).
final AlarmDecoder alarmDecoder = AlarmDecoder();
