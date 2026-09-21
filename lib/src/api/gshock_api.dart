import 'dart:typed_data';

import '../constants/casio_constants.dart';
import '../io/app_notification_io.dart';
import '../io/button_pressed_io.dart';
import '../io/connection_protocol.dart';
import '../io/dst_watch_state_io.dart';
import '../model/app_notification.dart';
import '../model/step_counter_data.dart';
import '../model/watch_info.dart';
import '../timezone/casio_time_zone_helper.dart';

/// Main interface for interacting with Casio G-Shock watches.
class GshockApi {
  GshockApi(this.connection, {WatchInfo? watchInfo})
    : _watchInfo = watchInfo ?? watchInfoGlobal;

  static const int handleNotification = 0x0D;

  final ConnectionProtocol connection;
  final WatchInfo _watchInfo;

  Future<String> getWatchName() => _watchInfo.protocol.getWatchName(connection);

  Future<WatchButton> getPressedButton() =>
      _watchInfo.protocol.getPressedButton(connection);

  Future<Uint8List> getWorldCities(int cityNumber) =>
      _watchInfo.protocol.getWorldCities(connection, cityNumber);

  Future<Uint8List> getDstForWorldCities(int cityNumber) =>
      _watchInfo.protocol.getDstForWorldCities(connection, cityNumber);

  Future<Uint8List> getDstWatchState(DtsState state) =>
      _watchInfo.protocol.getDstWatchState(connection, state);

  /// Gets the home time. The [slot] parameter is ignored at the facade level
  /// (D11) to mirror Python; use the protocol/IO directly to honor it.
  Future<String> getHomeTime({int slot = 0}) =>
      _watchInfo.protocol.getHomeTime(connection);

  Future<void> setTime({
    double? currentTime,
    int offset = 0,
    String? timezone,
  }) async {
    CasioTimeZoneHelper.setTimezone(timezone);
    await _watchInfo.protocol.setTime(
      connection,
      currentTime: currentTime,
      offset: offset,
    );
  }

  Future<List<Map<String, Object?>>> getAlarms() =>
      _watchInfo.protocol.getAlarms(connection);

  Future<void> setAlarms(List<Map<String, Object?>> alarms) =>
      _watchInfo.protocol.setAlarms(connection, alarms);

  Future<int> getTimer() => _watchInfo.protocol.getTimer(connection);

  Future<void> setTimer(int timerValue) =>
      _watchInfo.protocol.setTimer(connection, timerValue);

  Future<Map<String, int>> getWatchCondition() =>
      _watchInfo.protocol.getWatchCondition(connection);

  Future<bool> getTimeAdjustment() =>
      _watchInfo.protocol.getTimeAdjustment(connection);

  Future<void> setTimeAdjustment(bool timeAdjustment, int minutesAfterHour) =>
      _watchInfo.protocol.setTimeAdjustment(
        connection,
        timeAdjustment,
        minutesAfterHour,
      );

  Future<Map<String, Object?>> getBasicSettings() =>
      _watchInfo.protocol.getBasicSettings(connection);

  Future<Map<String, Object?>> getSettings() =>
      _watchInfo.protocol.getSettings(connection);

  Future<void> setSettings(Map<String, Object?> settings) =>
      _watchInfo.protocol.setSettings(connection, settings);

  Future<StepCounterData> getStepCount({bool peek = false}) =>
      _watchInfo.protocol.getStepCount(connection, peek: peek);

  /// Superset addition (D1): the Python facade omits this although the
  /// protocol defines it.
  Future<int> getStepCountToday() =>
      _watchInfo.protocol.getStepCountToday(connection);

  Future<List<Map<String, Object?>>> getReminders() async {
    final reminders = <Map<String, Object?>>[];
    for (var i = 1; i <= 5; i++) {
      reminders.add(await getEventFromWatch(i));
    }
    return reminders;
  }

  Future<Map<String, Object?>> getEventFromWatch(int eventNumber) =>
      _watchInfo.protocol.getEventFromWatch(connection, eventNumber);

  Future<void> setReminders(List<Map<String, Object?>> events) =>
      _watchInfo.protocol.setReminders(connection, events);

  Future<String> getAppInfo() => _watchInfo.protocol.getAppInfo(connection);

  Future<void> sendAppNotification(AppNotification notification) async {
    final encodedBuffer = AppNotificationIO.encodeNotificationPacket(
      notification,
    );
    final encryptedBuffer = AppNotificationIO.xorEncodeBuffer(encodedBuffer);
    await connection.write(handleNotification, encryptedBuffer);
  }

  /// Resets per-connection capability state (`WatchInfo.reset`).
  void reset() => _watchInfo.reset();
}

/// Global watch info singleton used when no explicit instance is supplied.
final WatchInfo watchInfoGlobal = watchInfo;

/// Re-exported constant for adapters that need the notification handle.
const int casioNotificationHandle =
    CasioConstants.handleAllFeaturesNotification;
