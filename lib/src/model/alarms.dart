import '../constants/casio_constants.dart';
import '../util/bytes.dart';
import '../util/logger.dart';

const int hourlyChimeMask = 0x80;
const int enabledMask = 0x40;
const int alarmConstantValue = 0x40;

const Map<String, int> _characteristics = CasioConstants.characteristics;

/// Immutable alarm value object.
class Alarm {
  const Alarm({
    required this.hour,
    required this.minute,
    required this.enabled,
    this.hasHourlyChime = false,
  });

  factory Alarm.fromJson(Map<String, Object?> json) {
    return Alarm(
      hour: (json['hour'] as int?) ?? 0,
      minute: (json['minute'] as int?) ?? 0,
      enabled: json['enabled'] == true,
      hasHourlyChime: json['hasHourlyChime'] == true,
    );
  }

  final int hour;
  final int minute;
  final bool enabled;
  final bool hasHourlyChime;

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

/// Mutable alarm collection mirroring `Alarms` in Python.
class Alarms {
  final List<Map<String, Object?>> alarms = <Map<String, Object?>>[];

  void clear() => alarms.clear();

  void addAlarms(List<Map<String, Object?>> alarmJsonArr) {
    alarms.addAll(alarmJsonArr);
  }

  List<int> fromJsonAlarmFirstAlarm(Map<String, Object?> alarm) {
    return createFirstAlarm(alarm);
  }

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

  /// NOTE: preserves the Python quirk (D6) that this slices the accumulated
  /// state (`self.alarms[1:]`) and ignores the argument.
  List<int> fromJsonAlarmSecondaryAlarms(
    List<Map<String, Object?>> alarmsJson,
  ) {
    if (alarmsJson.length < 2) return <int>[];
    final secondary = alarms.length > 1
        ? alarms.sublist(1)
        : <Map<String, Object?>>[];
    return createSecondaryAlarm(secondary);
  }

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

/// Global alarm instance (mirrors Python's module global `alarms_inst`).
final Alarms alarmsInst = Alarms();

/// Decodes alarm byte payloads into JSON-like maps.
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
