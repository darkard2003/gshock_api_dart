/// {@category Data Models}
///
/// Lifelog and pedometer step data container.
///
/// Models such as the ABL-100WE, F-B100W, and GBD-200 record daily step totals
/// and 24 hourly step accumulation buckets. Unrecorded or future hourly buckets
/// are marked with the sentinel value `0xFFFE`.
class StepCounterData {
  /// Sentinel value indicating an unrecorded or future hourly step bucket (`0xFFFE`).
  static const int unrecordedHour = 0xFFFE;

  /// Sentinel value indicating an unrecorded daily total (`0xFFFFFFFE`).
  static const int unrecordedDay = 0xFFFFFFFE;

  /// Creates a [StepCounterData] container.
  StepCounterData({
    this.timestamp,
    this.dayOfWeek,
    this.month,
    this.dayOfMonth,
    List<int?>? hourlySteps,
    List<int?>? dailyHistory,
    List<int?>? dailyDistances,
    List<Map<String, Object?>>? hourlyIntervals,
    List<int?>? hourlyByHour,
    List<Map<String, Object?>>? dailyHistoryList,
    this.currentDaySteps,
    this.raw,
    List<String>? warnings,
    this.distanceMeters,
    this.pendingDistanceMeters,
    this.totalDistanceMeters,
    this.bcdTotalSteps,
    List<List<int>>? hourlyIntensities,
    List<int>? pendingIntensity,
    List<int>? committedDistances,
  }) : hourlySteps = hourlySteps ?? <int?>[],
       dailyHistory = dailyHistory ?? <int?>[],
       dailyDistances = dailyDistances ?? <int?>[],
       hourlyIntervals = hourlyIntervals ?? <Map<String, Object?>>[],
       hourlyByHour = hourlyByHour ?? <int?>[],
       dailyHistoryList = dailyHistoryList ?? <Map<String, Object?>>[],
       warnings = warnings ?? <String>[],
       hourlyIntensities = hourlyIntensities ?? <List<int>>[],
       pendingIntensity = pendingIntensity ?? <int>[],
       committedDistances = committedDistances ?? <int>[];

  DateTime? timestamp;
  int? dayOfWeek;
  int? month;
  int? dayOfMonth;
  List<int?> hourlySteps;
  List<int?> dailyHistory;
  List<int?> dailyDistances;

  List<Map<String, Object?>> hourlyIntervals;
  List<int?> hourlyByHour;
  List<Map<String, Object?>> dailyHistoryList;
  int? currentDaySteps;
  List<int>? raw;
  List<String> warnings;
  int? distanceMeters;
  int? pendingDistanceMeters;
  int? totalDistanceMeters;
  int? bcdTotalSteps;
  List<List<int>> hourlyIntensities;
  List<int> pendingIntensity;
  List<int> committedDistances;

  /// Returns an "unavailable" record.
  static StepCounterData unavailable() => StepCounterData(
    timestamp: null,
    hourlySteps: <int?>[],
    dailyHistory: <int?>[],
    currentDaySteps: null,
    raw: <int>[],
    warnings: <String>['step counter unavailable'],
    distanceMeters: null,
    pendingDistanceMeters: null,
    totalDistanceMeters: null,
    bcdTotalSteps: null,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'timestamp': timestamp?.toIso8601String(),
    'dayOfWeek': dayOfWeek,
    'month': month,
    'dayOfMonth': dayOfMonth,
    'hourlySteps': hourlySteps,
    'dailyHistory': dailyHistory,
    'dailyDistances': dailyDistances,
    'hourlyIntervals': hourlyIntervals,
    'hourlyByHour': hourlyByHour,
    'dailyHistoryList': dailyHistoryList,
    'currentDaySteps': currentDaySteps,
    'raw': raw,
    'warnings': warnings,
    'distanceMeters': distanceMeters,
    'pendingDistanceMeters': pendingDistanceMeters,
    'totalDistanceMeters': totalDistanceMeters,
    'bcdTotalSteps': bcdTotalSteps,
    'hourlyIntensities': hourlyIntensities,
    'pendingIntensity': pendingIntensity,
    'committedDistances': committedDistances,
  };

  @override
  String toString() =>
      'StepCounterData(timestamp: $timestamp, currentDaySteps: $currentDaySteps, '
      'totalDistanceMeters: $totalDistanceMeters, warnings: $warnings)';
}
