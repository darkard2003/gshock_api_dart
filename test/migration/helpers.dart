import 'dart:typed_data';

import 'package:gshock_api_dart/gshock_api_dart.dart';

/// Resets all global/static library state between tests.
///
/// The Python implementation keeps its IO state on module-level globals; the
/// Dart port mirrors that with static fields. Tests must clear them so
/// state never leaks between watches, exactly like the Python
/// `watch_info.reset()` guardrail requires.
void resetMigrationState() {
  watchInfo.reset();
  alarmsInst.clear();
  AlarmsIO.result = null;
  AlarmsIO.connection = null;
  AppInfoIO.result = null;
  AppInfoIO.connection = null;
  ButtonPressedIO.result = null;
  DstForWorldCitiesIO.result = null;
  DstForWorldCitiesIO.connection = null;
  DstWatchStateIO.result = null;
  DstWatchStateIO.connection = null;
  EventsIO.result = null;
  EventsIO.connection = null;
  EventsIO.title = null;
  GwBx5600TimeIO.result = null;
  GwBx5600TimeIO.step = 0;
  GwBx5600TimeIO.accumulator = Uint8List(0);
  HomeTimeIO.result = null;
  HomeTimeIO.connection = null;
  SettingsIO.result = null;
  SettingsIO.connection = null;
  StepCounterIO.result = null;
  StepCounterIO.connection = null;
  StepCounterIO.accumulator = Uint8List(0);
  StepCounterIO.expectedLength = fallbackExpectedLength;
  StepCounterIO.lastData = null;
  TimeAdjustmentIO.result = null;
  TimeAdjustmentIO.connection = null;
  TimeAdjustmentIO.originalValue = null;
  TimerIO.result = null;
  TimerIO.connection = null;
  WatchNameIO.result = null;
  WatchNameIO.connection = null;
  WorldCitiesIO.result = null;
  WorldCitiesIO.connection = null;
}
