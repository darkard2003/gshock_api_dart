import 'dart:convert';
import 'dart:typed_data';

import '../constants/casio_constants.dart';
import '../io/alarms_io.dart';
import '../io/app_info_io.dart';
import '../io/button_pressed_io.dart';
import '../io/dst_for_world_cities_io.dart';
import '../io/dst_watch_state_io.dart';
import '../io/error_io.dart';
import '../io/events_io.dart';
import '../io/gw_bx5600_time_io.dart';
import '../io/home_time_io.dart';
import '../io/settings_io.dart';
import '../io/step_counter_io.dart';
import '../io/time_adjustment_io.dart';
import '../io/time_io.dart';
import '../io/timer_io.dart';
import '../io/unknown_io.dart';
import '../io/watch_condition_io.dart';
import '../io/watch_name_io.dart';
import '../io/world_cities_io.dart';
import '../model/watch_info.dart';
import '../protocols/watch_protocol.dart';
import '../util/logger.dart';

const Map<String, int> _characteristics = CasioConstants.characteristics;

typedef WatchSender = Future<void> Function(String message);
typedef OnReceivedFunction = void Function(Uint8List data);

/// Dispatches action messages to IO senders and routes received data to
/// handlers via the active [WatchProtocol].
class MessageDispatcher {
  MessageDispatcher._();

  static final Map<String, WatchSender> watchSenders = <String, WatchSender>{
    'GET_ALARMS': (m) => AlarmsIO.sendToWatch(m),
    'SET_ALARMS': (m) => AlarmsIO.sendToWatchSet(m),
    'SET_REMINDERS': (m) => EventsIO.sendToWatchSet(m),
    'GET_SETTINGS': (m) => SettingsIO.sendToWatch(m),
    'SET_SETTINGS': (m) => SettingsIO.sendToWatchSet(m),
    'GET_TIME_ADJUSTMENT': (m) => TimeAdjustmentIO.sendToWatch(m),
    'SET_TIME_ADJUSTMENT': (m) => TimeAdjustmentIO.sendToWatchSet(m),
    'GET_TIMER': (m) => TimerIO.sendToWatch(m),
    'SET_TIMER': (m) => TimerIO.sendToWatchSet(m),
    'SET_TIME': (m) => TimeIO.sendToWatchSet(m),
    'GET_HOME_TIME': (m) => HomeTimeIO.sendToWatch(m),
  };

  static final Map<int, OnReceivedFunction>
  dataReceivedMessages = <int, OnReceivedFunction>{
    _characteristics['CASIO_SETTING_FOR_ALM']!: AlarmsIO.onReceived,
    _characteristics['CASIO_SETTING_FOR_ALM2']!: AlarmsIO.onReceived,
    _characteristics['CASIO_TIMER']!: TimerIO.onReceived,
    _characteristics['CASIO_WATCH_NAME']!: WatchNameIO.onReceived,
    _characteristics['CASIO_DST_SETTING']!: DstForWorldCitiesIO.onReceived,
    _characteristics['CASIO_REMINDER_TIME']!: EventsIO.onReceived,
    _characteristics['CASIO_REMINDER_TITLE']!: EventsIO.onReceivedTitle,
    _characteristics['CASIO_WORLD_CITIES']!: WorldCitiesIO.onReceived,
    _characteristics['CASIO_DST_WATCH_STATE']!: DstWatchStateIO.onReceived,
    _characteristics['CASIO_WATCH_CONDITION']!: WatchConditionIO.onReceived,
    _characteristics['CASIO_APP_INFORMATION']!: AppInfoIO.onReceived,
    _characteristics['CASIO_BLE_FEATURES']!: ButtonPressedIO.onReceived,
    _characteristics['CASIO_SETTING_FOR_BASIC']!: SettingsIO.onReceived,
    _characteristics['CASIO_SETTING_FOR_BLE']!: TimeAdjustmentIO.onReceived,
    _characteristics['ERROR']!: ErrorIO.onReceived,
    _characteristics['UNKNOWN']!: UnknownIO.onReceived,
    _characteristics['CMD_SET_TIMEMODE']!: UnknownIO.onReceived,
    _characteristics['FIND_PHONE']!: UnknownIO.onReceived,
    _characteristics['CASIO_ACTIVITY_RECORD']!: StepCounterIO.onReceived,
    _characteristics['GW_BX5600_SP_DATA_HEADER_03']!: GwBx5600TimeIO.onReceived,
    _characteristics['GW_BX5600_SP_DATA_HEADER_05']!: GwBx5600TimeIO.onReceived,
    _characteristics['GW_BX5600_SP_DATA_HEADER_06']!: GwBx5600TimeIO.onReceived,
    _characteristics['CASIO_HOME_TIME']!: HomeTimeIO.onReceived,
  };

  static Future<void> sendToWatch(Object message) async {
    String? action;
    String rawJson;

    if (message is Map) {
      action = message['action'] as String?;
      rawJson = jsonEncode(message);
    } else {
      final str = '$message'.trim();
      if (str.startsWith('{')) {
        rawJson = str;
        try {
          final decoded = jsonDecode(str);
          if (decoded is Map) {
            action = decoded['action'] as String?;
          }
        } on FormatException {
          gshockLogger.error('Failed to decode JSON message: $message');
          return;
        }
      } else {
        action = str;
        rawJson = jsonEncode(<String, Object?>{'action': str});
      }
    }

    if (action == null || action.isEmpty) {
      gshockLogger.error("Message has no valid 'action' key: $message");
      return;
    }

    final sender = watchSenders[action];
    if (sender != null) {
      await sender(rawJson);
    } else {
      gshockLogger.error('Unknown action received: $action');
    }
  }

  static void onReceived(Uint8List data, [WatchProtocol? protocol]) {
    if (data.isEmpty) {
      gshockLogger.info(['Received empty data.']);
      return;
    }

    final prot = protocol ?? watchInfo.protocol;
    final key = prot.extractKey(data);
    if (key == null) {
      gshockLogger.info(['Could not extract key from data.']);
      return;
    }

    final handlers = prot.dataReceivedHandlers;
    final handler = handlers[key];
    if (handler == null) {
      gshockLogger.info(['Unknown characteristic key received: $key']);
    } else {
      final unwrappedData = prot.unwrapPayload(data, key);
      handler(unwrappedData);
    }
  }
}
