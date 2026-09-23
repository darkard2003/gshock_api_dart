import 'dart:convert';
import 'dart:typed_data';

import '../dispatcher/message_dispatcher.dart';
import '../io/alarms_io.dart';
import '../io/app_info_io.dart';
import '../io/button_pressed_io.dart';
import '../io/connection_protocol.dart';
import '../io/dst_for_world_cities_io.dart';
import '../io/dst_watch_state_io.dart';
import '../io/events_io.dart';
import '../io/home_time_io.dart';
import '../io/second_dial_io.dart';
import '../io/settings_io.dart';
import '../io/step_counter_io.dart';
import '../io/time_adjustment_io.dart';
import '../io/time_io.dart';
import '../io/timer_io.dart';
import '../io/watch_condition_io.dart';
import '../io/watch_name_io.dart';
import '../io/world_cities_io.dart';
import '../model/alarms.dart';
import '../model/step_counter_data.dart';
import '../model/watch_info.dart';
import '../timezone/casio_time_zone_helper.dart';
import 'watch_protocol.dart';

const int handleAllFeatures = 0x0E;

/// {@category Protocols & Constants}
///
/// Standard protocol implementation for digital and hybrid G-Shock watches.
///
/// Used by watches such as the GW-B5600, DW-B5600, GMW-B5000, and GA-B2100.
/// Features a single-byte discriminator header and standard 10-byte time synchronizations.
class StandardProtocol extends WatchProtocol {
  @override
  Map<int, void Function(Uint8List data)> get dataReceivedHandlers =>
      MessageDispatcher.dataReceivedMessages;

  @override
  int? extractKey(Uint8List data) {
    if (data.isEmpty) return null;
    final key = data[0];
    if (key == 0) return null;
    return key;
  }

  @override
  Uint8List unwrapPayload(Uint8List data, int key) => data;

  @override
  String getWatchConditionRequest() => '28';

  @override
  Future<String> getWatchName(ConnectionProtocol connection) =>
      WatchNameIO.request(connection);

  @override
  Future<WatchButton> getPressedButton(ConnectionProtocol connection) =>
      ButtonPressedIO.request(connection);

  @override
  Future<Uint8List> getWorldCities(
    ConnectionProtocol connection,
    int cityNumber,
  ) => WorldCitiesIO.request(connection, cityNumber);

  @override
  Future<Uint8List> getDstForWorldCities(
    ConnectionProtocol connection,
    int cityNumber,
  ) => DstForWorldCitiesIO.request(connection, cityNumber);

  @override
  Future<Uint8List> getDstWatchState(
    ConnectionProtocol connection,
    DtsState state,
  ) => DstWatchStateIO.request(connection, state);

  @override
  Future<void> setTime(
    ConnectionProtocol connection, {
    double? currentTime,
    int offset = 0,
  }) async {
    await initializeForSettingTime(connection);
    await TimeIO.request(connection, currentTime, offset);

    if (watchInfo.hasSecondDial) {
      await SecondDialIO.setSecondDial(connection);
    }
  }

  Future<void> initializeForSettingTime(ConnectionProtocol connection) async {
    await readWriteDstWatchStates(connection);
    await readWriteDstForWorldCities(connection);

    if (watchInfo.hasWorldCities) {
      await readWriteWorldCities(connection);
    } else if (watchInfo.model == WatchModel.mtgB3000) {
      // Ported verbatim for structural parity (D7); reachable only in theory.
      await readWriteHomeTimes(connection);
    }
  }

  Future<Uint8List> _getDstWatchStateWithTz(
    ConnectionProtocol connection,
    DtsState state,
  ) async {
    final origDst = await getDstWatchState(connection, state);
    final casioTz = CasioTimeZoneHelper.getCasioTimeZone();
    final dstValue = (casioTz.isInDst() ? 1 : 0) | (casioTz.hasRules() ? 2 : 0);
    return DstWatchStateIO.setDst(origDst, dstValue);
  }

  Future<void> readWriteDstWatchStates(ConnectionProtocol connection) async {
    await readAndWrite(
      connection,
      (c, p) => _getDstWatchStateWithTz(c, p as DtsState),
      DtsState.zero,
    );

    final states = <DtsState>[DtsState.two, DtsState.four];
    final take = watchInfo.dstCount - 1;
    for (final state in states.take(take < 0 ? 0 : take)) {
      await readAndWrite(
        connection,
        (c, p) => getDstWatchState(c, p as DtsState),
        state,
      );
    }
  }

  Future<Uint8List> _getDstForWorldCitiesWithTz(
    ConnectionProtocol connection,
    int cityNum,
  ) async {
    final origDst = await getDstForWorldCities(connection, cityNum);
    final casioTz = CasioTimeZoneHelper.getCasioTimeZone();
    return DstForWorldCitiesIO.setDst(origDst, casioTz);
  }

  Future<void> readWriteDstForWorldCities(ConnectionProtocol connection) async {
    await readAndWrite(
      connection,
      (c, p) => _getDstForWorldCitiesWithTz(c, p as int),
      0,
    );

    for (
      var cityNumber = 1;
      cityNumber < watchInfo.worldCitiesCount;
      cityNumber++
    ) {
      await readAndWrite(
        connection,
        (c, p) => getDstForWorldCities(c, p as int),
        cityNumber,
      );
    }
  }

  Future<Uint8List> _getWorldCitiesWithTz(
    ConnectionProtocol connection,
    int cityNum,
  ) async {
    final casioTz = CasioTimeZoneHelper.getCasioTimeZone();
    final cityName = WorldCitiesIO.parseCity(casioTz.zoneName);
    return WorldCitiesIO.encodeAndPad(cityName, cityNum);
  }

  Future<void> readWriteWorldCities(ConnectionProtocol connection) async {
    await readAndWrite(
      connection,
      (c, p) => _getWorldCitiesWithTz(c, p as int),
      0,
    );

    for (
      var cityNumber = 1;
      cityNumber < watchInfo.worldCitiesCount;
      cityNumber++
    ) {
      await readAndWrite(
        connection,
        (c, p) => getWorldCities(c, p as int),
        cityNumber,
      );
    }
  }

  Future<void> readWriteHomeTimes(ConnectionProtocol connection) async {
    for (
      var cityNumber = 0;
      cityNumber < watchInfo.worldCitiesCount;
      cityNumber++
    ) {
      final rawBytes = await HomeTimeIO.requestRaw(
        connection,
        slot: cityNumber,
      );
      await connection.write(handleAllFeatures, rawBytes);
    }
  }

  Future<void> readAndWrite(
    ConnectionProtocol connection,
    Future<Uint8List> Function(ConnectionProtocol, Object) function,
    Object param,
  ) async {
    final ret = await function(connection, param);
    await connection.write(handleAllFeatures, ret);
  }

  @override
  Future<int> getTimer(ConnectionProtocol connection) =>
      TimerIO.request(connection);

  @override
  Future<void> setTimer(ConnectionProtocol connection, int timerValue) async {
    TimerIO.connection = connection;
    final message = '{"action": "SET_TIMER", "value": $timerValue }';
    await connection.sendMessage(message);
  }

  @override
  String getTimerRequest() => '18';

  @override
  int getTimerSize() => 7;

  @override
  Future<String> getHomeTime(ConnectionProtocol connection) =>
      HomeTimeIO.request(connection);

  @override
  Future<int> getBatteryLevel(ConnectionProtocol connection) async {
    final cond = await getWatchCondition(connection);
    return cond['batteryLevel'] ?? 0;
  }

  @override
  Future<int> getWatchTemperature(ConnectionProtocol connection) async {
    final cond = await getWatchCondition(connection);
    return cond['temperature'] ?? 0;
  }

  @override
  Future<List<Map<String, Object?>>> getAlarms(
    ConnectionProtocol connection,
  ) async {
    alarmsInst.clear();
    await AlarmsIO.request(connection);
    return alarmsInst.alarms;
  }

  @override
  Future<void> setAlarms(
    ConnectionProtocol connection,
    List<Map<String, Object?>> alarms,
  ) async {
    if (alarms.isEmpty) return;
    AlarmsIO.connection = connection;
    final alarmsStr = jsonEncode(alarms);
    final setActionCmd = '{"action":"SET_ALARMS", "value":$alarmsStr }';
    await connection.sendMessage(setActionCmd);
  }

  @override
  Future<Map<String, Object?>> getSettings(
    ConnectionProtocol connection,
  ) async {
    final result = await getBasicSettings(connection);
    try {
      final timeAdjRes = await TimeAdjustmentIO.request(connection);
      final val = timeAdjRes['timeAdjustment'];
      result['time_adjustment'] =
          val.toString().toLowerCase() == 'true' ||
          val.toString().toLowerCase() == '1';
      result['time_adjustment_minutes_after_hour'] =
          timeAdjRes['minutesAfterHour'];
    } catch (_) {
      // ignore, matching Python's broad except
    }
    return result;
  }

  @override
  Future<void> setSettings(
    ConnectionProtocol connection,
    Map<String, Object?> settings,
  ) async {
    SettingsIO.connection = connection;
    final settingJson = jsonEncode(settings);
    final message = '{"action": "SET_SETTINGS", "value": $settingJson }';
    await connection.sendMessage(message);
  }

  @override
  Future<Map<String, Object?>> getBasicSettings(
    ConnectionProtocol connection,
  ) async {
    final resultStr = await SettingsIO.request(connection);
    return (jsonDecode(resultStr) as Map).cast<String, Object?>();
  }

  @override
  Future<bool> getTimeAdjustment(ConnectionProtocol connection) async {
    final result = await TimeAdjustmentIO.request(connection);
    final val = result['timeAdjustment'];
    return val.toString().toLowerCase() == 'true' ||
        val.toString().toLowerCase() == '1';
  }

  @override
  Future<void> setTimeAdjustment(
    ConnectionProtocol connection,
    bool timeAdjustment,
    int minutesAfterHour,
  ) async {
    TimeAdjustmentIO.connection = connection;
    final message =
        '{"action": "SET_TIME_ADJUSTMENT", "timeAdjustment": "$timeAdjustment", "minutesAfterHour": "$minutesAfterHour" }';
    await connection.sendMessage(message);
  }

  @override
  Future<Map<String, int>> getWatchCondition(ConnectionProtocol connection) {
    final reqCmd = getWatchConditionRequest();
    return WatchConditionIO.request(connection, requestCmd: reqCmd);
  }

  @override
  Future<String> getAppInfo(ConnectionProtocol connection) =>
      AppInfoIO.request(connection);

  @override
  Future<int> getStepCountToday(ConnectionProtocol connection) async {
    final data = await StepCounterIO.request(connection);
    return data.currentDaySteps ?? 0;
  }

  @override
  Future<StepCounterData> getStepCount(
    ConnectionProtocol connection, {
    bool peek = false,
  }) => StepCounterIO.request(connection, peek: peek);

  @override
  Future<Map<String, Object?>> getEventFromWatch(
    ConnectionProtocol connection,
    int eventNumber,
  ) => EventsIO.request(connection, eventNumber);

  @override
  Future<void> setReminders(
    ConnectionProtocol connection,
    List<Map<String, Object?>> events,
  ) async {
    if (events.isEmpty) return;
    EventsIO.connection = connection;

    final enabled = events.where((event) {
      final time = (event['time'] as Map?)?.cast<String, Object?>();
      return time?['enabled'] == true;
    }).toList();

    await connection.sendMessage(
      '{"action": "SET_REMINDERS", "value": ${jsonEncode(enabled)}}',
    );
  }
}
