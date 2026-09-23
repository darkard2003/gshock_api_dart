import 'dart:convert';
import 'dart:typed_data';

import '../io/ble_action.dart';
import '../io/connection_protocol.dart';
import '../io/packet.dart';
import '../util/bytes.dart';
import '../util/cancelable_result.dart';
import '../util/logger.dart';

/// Reminder bitmasks.
/// @nodoc
abstract final class ReminderMasks {
  static const int yearlyMask = 0x08;
  static const int monthlyMask = 0x10;
  static const int weeklyMask = 0x04;

  static const int sundayMask = 0x01;
  static const int mondayMask = 0x02;
  static const int tuesdayMask = 0x04;
  static const int wednesdayMask = 0x08;
  static const int thursdayMask = 0x10;
  static const int fridayMask = 0x20;
  static const int saturdayMask = 0x40;

  static const int enabledMask = 0x01;
}

/// Time period (enabled + repeat period).
/// @nodoc
class TimePeriod {
  TimePeriod(this.enabled, this.repeatPeriod);

  final bool enabled;
  final String repeatPeriod;
}

const Map<String, int> _monthNumbers = <String, int>{
  'january': 1,
  'february': 2,
  'march': 3,
  'april': 4,
  'may': 5,
  'june': 6,
  'july': 7,
  'august': 8,
  'september': 9,
  'october': 10,
  'november': 11,
  'december': 12,
};

const List<String> _monthNames = <String>[
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

/// Pure functional reminders/events codec.
/// @nodoc
class EventsIOFunctional {
  EventsIOFunctional._();

  static Uint8List reminderTitleFromJson(Map<String, Object?> reminderJson) {
    final titleStr = (reminderJson['title'] as String?) ?? '';
    return Bytes.toByteArray(titleStr, 18);
  }

  static Uint8List reminderTimeFromJson(Map<String, Object?>? reminderJson) {
    reminderJson ??= <String, Object?>{};

    List<int> createTimeDetail(
      String repeatPeriod,
      Map<String, Object?> startDate,
      Map<String, Object?> endDate,
      List<String>? daysOfWeek,
    ) {
      final timeDetail = List<int>.filled(8, 0);

      int hexToDec(int value) => int.parse('$value', radix: 16);

      int stringToMonth(String? monthStr) =>
          _monthNumbers[(monthStr ?? '').toLowerCase()] ?? 1;

      void encodeDate(
        List<int> timeDetail,
        Map<String, Object?> startDate,
        Map<String, Object?> endDate,
      ) {
        timeDetail[0] = hexToDec(
          ((startDate['year'] as num?)?.toInt() ?? 0) % 2000,
        );
        timeDetail[1] = hexToDec(stringToMonth(startDate['month'] as String?));
        timeDetail[2] = hexToDec((startDate['day'] as num?)?.toInt() ?? 0);
        timeDetail[3] = hexToDec(
          ((endDate['year'] as num?)?.toInt() ?? 0) % 2000,
        );
        timeDetail[4] = hexToDec(stringToMonth(endDate['month'] as String?));
        timeDetail[5] = hexToDec((endDate['day'] as num?)?.toInt() ?? 0);
        timeDetail[6] = 0;
        timeDetail[7] = 0;
      }

      if (repeatPeriod == 'NEVER') {
        encodeDate(timeDetail, startDate, endDate);
      } else if (repeatPeriod == 'WEEKLY') {
        encodeDate(timeDetail, startDate, endDate);

        var dayOfWeek = 0;
        if (daysOfWeek != null) {
          for (final day in daysOfWeek) {
            if (day == 'SUNDAY') {
              dayOfWeek |= ReminderMasks.sundayMask;
            } else if (day == 'MONDAY') {
              dayOfWeek |= ReminderMasks.mondayMask;
            } else if (day == 'TUESDAY') {
              dayOfWeek |= ReminderMasks.tuesdayMask;
            } else if (day == 'WEDNESDAY') {
              dayOfWeek |= ReminderMasks.wednesdayMask;
            } else if (day == 'THURSDAY') {
              dayOfWeek |= ReminderMasks.thursdayMask;
            } else if (day == 'FRIDAY') {
              dayOfWeek |= ReminderMasks.fridayMask;
            } else if (day == 'SATURDAY') {
              dayOfWeek |= ReminderMasks.saturdayMask;
            }
          }
        }
        timeDetail[6] = dayOfWeek;
        timeDetail[7] = 0;
      } else if (repeatPeriod == 'MONTHLY' || repeatPeriod == 'YEARLY') {
        encodeDate(timeDetail, startDate, endDate);
      } else {
        gshockLogger.debug(['Cannot handle Repeat Period: $repeatPeriod']);
      }

      return timeDetail;
    }

    int createTimePeriod(bool enabled, String repeatPeriod) {
      var timePeriod = 0;
      if (enabled) timePeriod |= ReminderMasks.enabledMask;
      if (repeatPeriod == 'WEEKLY') {
        timePeriod |= ReminderMasks.weeklyMask;
      } else if (repeatPeriod == 'MONTHLY') {
        timePeriod |= ReminderMasks.monthlyMask;
      } else if (repeatPeriod == 'YEARLY') {
        timePeriod |= ReminderMasks.yearlyMask;
      }
      return timePeriod;
    }

    final enabled = reminderJson['enabled'] == true;
    final repeatPeriod = (reminderJson['repeat_period'] as String?) ?? '';
    final startDate =
        (reminderJson['start_date'] as Map?)?.cast<String, Object?>() ??
        <String, Object?>{'year': 0, 'month': '', 'day': 0};
    final endDate =
        (reminderJson['end_date'] as Map?)?.cast<String, Object?>() ??
        <String, Object?>{'year': 0, 'month': '', 'day': 0};
    final daysOfWeek = (reminderJson['days_of_week'] as List?)?.cast<String>();

    final reminderCmd = <int>[createTimePeriod(enabled, repeatPeriod)];
    reminderCmd.addAll(
      createTimeDetail(repeatPeriod, startDate, endDate, daysOfWeek),
    );
    return Uint8List.fromList(reminderCmd);
  }

  static List<BleAction> prepareWatchCommandsSet(String messageJson) {
    final decoded = (jsonDecode(messageJson) as Map).cast<String, Object?>();
    final remindersJsonArr =
        (decoded['value'] as List?)?.cast<Map<String, Object?>>() ??
        <Map<String, Object?>>[];

    final actions = <BleAction>[];
    for (var index = 0; index < remindersJsonArr.length; index++) {
      final reminderJson = remindersJsonArr[index];
      final title = reminderTitleFromJson(reminderJson);

      final packetBytesTitle = <int>[
        Protocol.reminderTitle.value,
        index + 1,
        ...title,
      ];
      actions.add(
        WriteAction(handle: 0x000E, data: Uint8List.fromList(packetBytesTitle)),
      );

      final timeData = reminderTimeFromJson(
        (reminderJson['time'] as Map?)?.cast<String, Object?>(),
      );
      final packetBytesTime = <int>[
        Protocol.reminderTime.value,
        index + 1,
        ...timeData,
      ];
      actions.add(
        WriteAction(handle: 0x000E, data: Uint8List.fromList(packetBytesTime)),
      );
    }

    return actions;
  }

  static Map<String, Object?> decodeTime(String reminderStr) {
    TimePeriod decodeTimePeriod(int timePeriod) {
      final enabled =
          (timePeriod & ReminderMasks.enabledMask) == ReminderMasks.enabledMask;
      String repeatPeriod;
      if ((timePeriod & ReminderMasks.weeklyMask) == ReminderMasks.weeklyMask) {
        repeatPeriod = 'WEEKLY';
      } else if ((timePeriod & ReminderMasks.monthlyMask) ==
          ReminderMasks.monthlyMask) {
        repeatPeriod = 'MONTHLY';
      } else if ((timePeriod & ReminderMasks.yearlyMask) ==
          ReminderMasks.yearlyMask) {
        repeatPeriod = 'YEARLY';
      } else {
        repeatPeriod = 'NEVER';
      }
      return TimePeriod(enabled, repeatPeriod);
    }

    String intToMonthStr(int monthInt) {
      if (monthInt < 1 || monthInt > 12) return '';
      return _monthNames[monthInt - 1];
    }

    Map<String, Object?> decodeDate(List<int> timeDetail) {
      return <String, Object?>{
        'year': Bytes.decToHex(timeDetail[0]) + 2000,
        'month': intToMonthStr(Bytes.decToHex(timeDetail[1])),
        'day': Bytes.decToHex(timeDetail[2]),
      };
    }

    Map<String, Object?> decodeTimeDetail(List<int> timeDetail) {
      final result = <String, Object?>{};
      result['start_date'] = decodeDate(timeDetail.sublist(1));
      result['end_date'] = decodeDate(timeDetail.sublist(4));

      final dayOfWeek = timeDetail[7];
      final daysOfWeek = <String>[];
      if ((dayOfWeek & ReminderMasks.sundayMask) == ReminderMasks.sundayMask) {
        daysOfWeek.add('SUNDAY');
      }
      if ((dayOfWeek & ReminderMasks.mondayMask) == ReminderMasks.mondayMask) {
        daysOfWeek.add('MONDAY');
      }
      if ((dayOfWeek & ReminderMasks.tuesdayMask) ==
          ReminderMasks.tuesdayMask) {
        daysOfWeek.add('TUESDAY');
      }
      if ((dayOfWeek & ReminderMasks.wednesdayMask) ==
          ReminderMasks.wednesdayMask) {
        daysOfWeek.add('WEDNESDAY');
      }
      if ((dayOfWeek & ReminderMasks.thursdayMask) ==
          ReminderMasks.thursdayMask) {
        daysOfWeek.add('THURSDAY');
      }
      if ((dayOfWeek & ReminderMasks.fridayMask) == ReminderMasks.fridayMask) {
        daysOfWeek.add('FRIDAY');
      }
      if ((dayOfWeek & ReminderMasks.saturdayMask) ==
          ReminderMasks.saturdayMask) {
        daysOfWeek.add('SATURDAY');
      }
      result['days_of_week'] = daysOfWeek;
      return result;
    }

    final intArr = Bytes.toIntArray(reminderStr);
    if (intArr.length > 3 && intArr[3] == 0xFF) {
      return <String, Object?>{'end': ''};
    }

    final reminder = intArr.sublist(2);
    final reminderJson = <String, Object?>{};
    final timePeriod = decodeTimePeriod(reminder[0]);
    reminderJson['enabled'] = timePeriod.enabled;
    reminderJson['repeat_period'] = timePeriod.repeatPeriod;

    final timeDetailMap = decodeTimeDetail(reminder);
    reminderJson['start_date'] = timeDetailMap['start_date'];
    reminderJson['end_date'] = timeDetailMap['end_date'];
    reminderJson['days_of_week'] = timeDetailMap['days_of_week'];

    return <String, Object?>{'time': reminderJson};
  }
}

/// Decodes reminder titles.
/// @nodoc
class ReminderDecoder {
  ReminderDecoder._();

  static Map<String, String> reminderTitleToJson(Uint8List message) {
    if (message.length > 2 && message[2] == 0xFF) {
      return <String, String>{'end': ''};
    }
    final titleBytes = message.length > 2 ? message.sublist(2) : Uint8List(0);
    return <String, String>{'title': Bytes.cleanStr(latin1.decode(titleBytes))};
  }
}

/// Stateful wrapper around [EventsIOFunctional].
/// @nodoc
class EventsIO {
  EventsIO._();

  static CancelableResult<Map<String, Object?>>? result;
  static ConnectionProtocol? connection;
  static Map<String, Object?>? title;

  static Future<Map<String, Object?>> request(
    ConnectionProtocol connection,
    int eventNumber,
  ) async {
    EventsIO.connection = connection;
    final pending = CancelableResult<Map<String, Object?>>();
    EventsIO.result = pending;
    try {
      await connection.request(
        '${Protocol.reminderTitle.value.toRadixString(16).padLeft(2, '0').toUpperCase()}$eventNumber',
      );
      await connection.request(
        '${Protocol.reminderTime.value.toRadixString(16).padLeft(2, '0').toUpperCase()}$eventNumber',
      );
      return await pending.getResult();
    } finally {
      if (identical(EventsIO.result, pending)) {
        EventsIO.result = null;
      }
    }
  }

  static Future<void> sendToWatchSet(String message) async {
    final conn = EventsIO.connection;
    if (conn == null) {
      throw StateError('EventsIO.connection not set');
    }
    for (final command in EventsIOFunctional.prepareWatchCommandsSet(message)) {
      if (command is WriteAction) {
        final cmdHex = Bytes.toCompactString(Bytes.toHexString(command.data));
        await conn.write(0x000E, cmdHex);
      }
    }
  }

  static void onReceived(Uint8List message) {
    final data = Bytes.toHexString(message);
    final reminderJson = EventsIOFunctional.decodeTime(data.substring(2));
    if (title != null) {
      reminderJson.addAll(title!);
    }
    if (result == null) {
      gshockLogger.warning(['EventsIO.result is not set']);
      return;
    }
    result!.setResult(reminderJson);
  }

  static void onReceivedTitle(Uint8List message) {
    title = ReminderDecoder.reminderTitleToJson(message)
        .cast<String, Object?>();
  }
}
