import 'dart:typed_data';

import '../io/button_pressed_io.dart';
import '../io/connection_protocol.dart';
import '../io/dst_watch_state_io.dart';
import '../model/step_counter_data.dart';

/// {@category Protocols & Constants}
///
/// Abstract strategy contract defining Casio watch communication protocols.
///
/// Concrete implementations:
/// - `StandardProtocol`: Standard digital and hybrid G-Shock watches.
/// - `MipProtocol`: Memory-in-Pixel display watches (GW-BX5600, GMW-BZ5000) using 4-step SP configuration handshake.
/// - `AnalogueProtocol`: Full analogue watches (MTG-B1000, MTG-B3000) managing motor alignment and second-dial calibration.
abstract class WatchProtocol {
  /// Notification dispatch map associating characteristic codes with packet consumer handlers.
  Map<int, void Function(Uint8List data)> get dataReceivedHandlers;

  /// Extracts the notification feature discriminator key from raw packet [data].
  int? extractKey(Uint8List data);

  /// Unwraps the inner payload bytes for [key] from the raw packet [data].
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
