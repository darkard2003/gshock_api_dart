import 'dart:typed_data';

import '../io/button_pressed_io.dart';
import '../io/connection_protocol.dart';
import '../io/dst_watch_state_io.dart';
import '../model/step_counter_data.dart';

/// Abstract protocol interface mirroring `WatchProtocol`.
abstract class WatchProtocol {
  Map<int, void Function(Uint8List data)> get dataReceivedHandlers;

  int? extractKey(Uint8List data);

  Uint8List unwrapPayload(Uint8List data, int key);

  String getWatchConditionRequest();

  Future<String> getWatchName(ConnectionProtocol connection);

  Future<WatchButton> getPressedButton(ConnectionProtocol connection);

  Future<Uint8List> getWorldCities(
    ConnectionProtocol connection,
    int cityNumber,
  );

  Future<Uint8List> getDstForWorldCities(
    ConnectionProtocol connection,
    int cityNumber,
  );

  Future<Uint8List> getDstWatchState(
    ConnectionProtocol connection,
    DtsState state,
  );

  Future<void> setTime(
    ConnectionProtocol connection, {
    double? currentTime,
    int offset,
  });

  Future<int> getTimer(ConnectionProtocol connection);

  Future<void> setTimer(ConnectionProtocol connection, int timerValue);

  String getTimerRequest();

  int getTimerSize();

  Future<String> getHomeTime(ConnectionProtocol connection);

  Future<int> getBatteryLevel(ConnectionProtocol connection);

  Future<int> getWatchTemperature(ConnectionProtocol connection);

  Future<List<Map<String, Object?>>> getAlarms(ConnectionProtocol connection);

  Future<void> setAlarms(
    ConnectionProtocol connection,
    List<Map<String, Object?>> alarms,
  );

  Future<Map<String, Object?>> getSettings(ConnectionProtocol connection);

  Future<void> setSettings(
    ConnectionProtocol connection,
    Map<String, Object?> settings,
  );

  Future<Map<String, Object?>> getBasicSettings(ConnectionProtocol connection);

  Future<bool> getTimeAdjustment(ConnectionProtocol connection);

  Future<void> setTimeAdjustment(
    ConnectionProtocol connection,
    bool timeAdjustment,
    int minutesAfterHour,
  );

  Future<Map<String, int>> getWatchCondition(ConnectionProtocol connection);

  Future<String> getAppInfo(ConnectionProtocol connection);

  Future<int> getStepCountToday(ConnectionProtocol connection);

  Future<StepCounterData> getStepCount(
    ConnectionProtocol connection, {
    bool peek,
  });

  Future<Map<String, Object?>> getEventFromWatch(
    ConnectionProtocol connection,
    int eventNumber,
  );

  Future<void> setReminders(
    ConnectionProtocol connection,
    List<Map<String, Object?>> events,
  );
}
