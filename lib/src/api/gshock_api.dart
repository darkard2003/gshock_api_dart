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

/// {@category Core API}
///
/// High-level API facade for interacting with Casio G-Shock Bluetooth watches.
///
/// [GshockApi] wraps the active [ConnectionProtocol] and [WatchInfo] model to provide
/// a clean, asynchronous interface for all watch features without exposing raw BLE packet
/// details or model dialect differences.
///
/// ### Example
/// ```dart
/// final connection = GshockConnection(transport: transport);
/// final api = GshockApi(connection);
///
/// await connection.connect();
/// final name = await api.getWatchName();
/// await api.setTime(timezone: 'America/New_York');
/// ```
class GshockApi {
  /// Creates a [GshockApi] instance using the provided [connection].
  ///
  /// If [watchInfo] is omitted, defaults to the global [watchInfoGlobal] singleton.
  GshockApi(this.connection, {WatchInfo? watchInfo})
    : _watchInfo = watchInfo ?? watchInfoGlobal;

  /// Characteristic handle for feature notifications (`0x0D`).
  static const int handleNotification = 0x0D;

  /// The active connection protocol used for BLE communication.
  final ConnectionProtocol connection;
  final WatchInfo _watchInfo;

  /// Reads the full watch model name string from the device (e.g. `'CASIO GW-B5600'`).
  ///
  /// Queries BLE characteristic handle `0x04` or `0x07` depending on watch generation.
  Future<String> getWatchName() => _watchInfo.protocol.getWatchName(connection);

  /// Awaits the next button press event sent by the watch.
  ///
  /// When a user holds a watch button (e.g. lower-right for phone finder or lower-left
  /// for time sync), the watch transmits a button code on handle `0x0D` (`CASIO_BLE_FEATURES`).
  ///
  /// Returns a [WatchButton] representing the reported button press:
  /// - [WatchButton.find]: Phone finder trigger (typically lower-right button long press).
  /// - [WatchButton.lowerLeft]: Time sync / mode trigger.
  /// - [WatchButton.lowerRight]: Action trigger.
  /// - [WatchButton.noButton]: Connection handshake without button press.
  Future<WatchButton> getPressedButton() =>
      _watchInfo.protocol.getPressedButton(connection);

  /// Reads the world city code stored in the specified [cityNumber] slot (0 to 5).
  Future<Uint8List> getWorldCities(int cityNumber) =>
      _watchInfo.protocol.getWorldCities(connection, cityNumber);

  /// Reads Daylight Saving Time (DST) configuration for the specified [cityNumber] slot (0 to 5).
  Future<Uint8List> getDstForWorldCities(int cityNumber) =>
      _watchInfo.protocol.getDstForWorldCities(connection, cityNumber);

  /// Reads the current DST state of the watch.
  Future<Uint8List> getDstWatchState(DtsState state) =>
      _watchInfo.protocol.getDstWatchState(connection, state);

  /// Reads the home time city configuration from the watch.
  ///
  /// The [slot] parameter is ignored at the facade level to preserve Python compatibility;
  /// use the protocol or IO class directly if slot selection is needed.
  Future<String> getHomeTime({int slot = 0}) =>
      _watchInfo.protocol.getHomeTime(connection);

  /// Synchronizes the watch's internal clock and timezone with the specified parameters.
  ///
  /// - [currentTime]: Unix epoch timestamp in seconds (defaults to `DateTime.now()`).
  /// - [offset]: Timezone offset in seconds (defaults to 0).
  /// - [timezone]: Optional IANA timezone identifier (e.g. `'America/New_York'`, `'Asia/Tokyo'`).
  ///
  /// This method automatically executes the required wire sequence for your watch model:
  /// - **Standard watches** (GW-B5600, GA-B2100): Writes a standard 10-byte time packet to handle `0x0E`.
  /// - **MIP watches** (GW-BX5600, GMW-BZ5000): Drives the 4-step SP configuration handshake over handles `0x17` and `0x19`.
  /// - **Analogue watches** (MTG-B1000, MTG-B3000): Handles second-dial reset sequences and motor calibrations.
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

  /// Fetches all configured alarms from the watch.
  ///
  /// Returns a list of alarm maps, where each map contains:
  /// - `'hour'`: [int] (0-23)
  /// - `'minute'`: [int] (0-59)
  /// - `'enabled'`: [bool] (whether the alarm is toggled ON)
  /// - `'hasHourlyChime'`: [bool] (whether the hourly signal beep is active; on slot 0)
  Future<List<Map<String, Object?>>> getAlarms() =>
      _watchInfo.protocol.getAlarms(connection);

  /// Writes alarm configurations to the watch.
  ///
  /// [alarms] must be a list of alarm maps matching the schema documented in [getAlarms].
  Future<void> setAlarms(List<Map<String, Object?>> alarms) =>
      _watchInfo.protocol.setAlarms(connection, alarms);

  /// Reads the countdown timer value from the watch, in seconds.
  Future<int> getTimer() => _watchInfo.protocol.getTimer(connection);

  /// Sets the countdown timer on the watch.
  ///
  /// [timerValue] is specified in seconds (e.g. `600` for a 10-minute timer).
  Future<void> setTimer(int timerValue) =>
      _watchInfo.protocol.setTimer(connection, timerValue);

  /// Reads the battery level and charging condition of the watch.
  ///
  /// Returns a map containing:
  /// - `'battery'`: [int] battery percentage (0 to 100).
  /// - `'batteryLevel'`: [int] raw hardware ADC reading.
  Future<Map<String, int>> getWatchCondition() =>
      _watchInfo.protocol.getWatchCondition(connection);

  /// Reads whether automatic time adjustment (4x daily sync) is enabled on the watch.
  Future<bool> getTimeAdjustment() =>
      _watchInfo.protocol.getTimeAdjustment(connection);

  /// Configures automatic time adjustment.
  ///
  /// - [timeAdjustment]: Whether auto time sync is enabled.
  /// - [minutesAfterHour]: Minute offset within the scheduled sync hours.
  Future<void> setTimeAdjustment(bool timeAdjustment, int minutesAfterHour) =>
      _watchInfo.protocol.setTimeAdjustment(
        connection,
        timeAdjustment,
        minutesAfterHour,
      );

  /// Reads basic watch settings.
  ///
  /// Returns a map containing:
  /// - `'timeFormat'`: [String] (`'12h'` or `'24h'`).
  /// - `'keyTone'`: [bool] (button beep sound enabled/disabled).
  /// - `'powerSavingMode'`: [bool] (display sleep mode in dark).
  Future<Map<String, Object?>> getBasicSettings() =>
      _watchInfo.protocol.getBasicSettings(connection);

  /// Reads full watch preferences and display settings.
  ///
  /// Returns a map containing:
  /// - `'timeFormat'`: [String] (`'12h'` or `'24h'`).
  /// - `'keyTone'`: [bool] (button beep).
  /// - `'autoLight'`: [bool] (auto wrist tilt illumination).
  /// - `'lightDuration'`: [String] (`'1.5s'` or `'3s'`).
  /// - `'powerSavingMode'`: [bool] (power saving sleep mode).
  /// - `'dateFormat'`: [String] (`'DD.MM'` or `'MM.DD'`).
  /// - `'language'`: [String] (`'English'`, `'Spanish'`, `'French'`, `'German'`, `'Italian'`, `'Russian'`).
  Future<Map<String, Object?>> getSettings() =>
      _watchInfo.protocol.getSettings(connection);

  /// Writes watch settings to the device.
  ///
  /// [settings] must be a map matching the keys documented in [getSettings].
  Future<void> setSettings(Map<String, Object?> settings) =>
      _watchInfo.protocol.setSettings(connection, settings);

  /// Retrieves step counter and lifelog records from the watch.
  ///
  /// Supported on models with built-in accelerometers (ABL-100WE, F-B100W, GBD-200).
  /// If [peek] is `true`, data is read without clearing or altering watch-side buffers.
  ///
  /// Returns a [StepCounterData] instance containing the daily step total and 24 hourly buckets.
  Future<StepCounterData> getStepCount({bool peek = false}) =>
      _watchInfo.protocol.getStepCount(connection, peek: peek);

  /// Reads today's total step count directly as an integer.
  Future<int> getStepCountToday() =>
      _watchInfo.protocol.getStepCountToday(connection);

  /// Reads all 5 reminder slots configured on the watch.
  ///
  /// Returns a list of reminder maps, each containing:
  /// - `'title'`: [String] reminder text displayed on LCD.
  /// - `'start'`: [Map] with `'year'`, `'month'`, `'day'`.
  /// - `'end'`: [Map] with `'year'`, `'month'`, `'day'`.
  /// - `'period'`: [String] repeat period (`'NEVER'`, `'DAILY'`, `'WEEKLY'`, `'MONTHLY'`, `'YEARLY'`).
  /// - `'enabled'`: [bool].
  Future<List<Map<String, Object?>>> getReminders() async {
    final reminders = <Map<String, Object?>>[];
    for (var i = 1; i <= 5; i++) {
      reminders.add(await getEventFromWatch(i));
    }
    return reminders;
  }

  /// Reads a single reminder slot from the watch ([eventNumber] between 1 and 5).
  Future<Map<String, Object?>> getEventFromWatch(int eventNumber) =>
      _watchInfo.protocol.getEventFromWatch(connection, eventNumber);

  /// Writes all 5 reminder slots to the watch.
  ///
  /// [events] must be a list of 5 reminder maps matching the schema documented in [getReminders].
  Future<void> setReminders(List<Map<String, Object?>> events) =>
      _watchInfo.protocol.setReminders(connection, events);

  /// Reads the watch application information string from characteristic `0x22`.
  Future<String> getAppInfo() => _watchInfo.protocol.getAppInfo(connection);

  /// Transmits an encrypted push app notification to the watch.
  ///
  /// Supported on watches with notification display screens (e.g. DW-H5600, GBD-H2000).
  /// The [notification] payload is encoded into length-prefixed UTF-8 strings,
  /// encrypted using Casio's XOR-255 cipher, and written to characteristic handle `0x0D`.
  Future<void> sendAppNotification(AppNotification notification) async {
    final encodedBuffer = AppNotificationIO.encodeNotificationPacket(
      notification,
    );
    final encryptedBuffer = AppNotificationIO.xorEncodeBuffer(encodedBuffer);
    await connection.write(handleNotification, encryptedBuffer);
  }

  /// Resets per-connection cached capability state in [WatchInfo].
  ///
  /// Must be invoked when disconnecting or before connecting to a different watch model
  /// to ensure model capabilities do not leak across sessions.
  void reset() => _watchInfo.reset();
}

/// Global [WatchInfo] singleton used when no explicit instance is supplied.
final WatchInfo watchInfoGlobal = watchInfo;

/// Re-exported constant for adapters that need the notification handle (`0x0D`).
const int casioNotificationHandle =
    CasioConstants.handleAllFeaturesNotification;
