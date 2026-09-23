import '../model/watch_info.dart';

/// {@category Connection & Transport}
///
/// Connection frequency filter for always-connected watch models.
///
/// Certain Casio models (e.g. ECB-30, ECB-10, EQB-1000) maintain prolonged or background
/// BLE links. To conserve watch battery and prevent them from monopolizing the Bluetooth
/// adapter, this filter throttles connections to at most once every 6 hours per watch.
class AlwaysConnectedWatchFilter {
  /// Map of trimmed watch name -> last connection timestamp in epoch milliseconds.
  final Map<String, int> lastConnectedTimes = <String, int>{};

  /// Returns `true` if the watch is permitted to connect right now.
  ///
  /// For watches with `alwaysConnected == false`, this always returns `true`.
  /// For always-connected models, returns `true` only if at least 6 hours have elapsed
  /// since the last connection (or if connecting for the first time).
  bool connectionFilter(String watchName) {
    final cleanName = watchName.trim();
    final watch = watchInfo.lookupWatchInfo(cleanName);

    if (watch['alwaysConnected'] != true) {
      return true;
    }

    final lastTime = lastConnectedTimes[cleanName];
    final now = DateTime.now().millisecondsSinceEpoch;

    if (lastTime == null) {
      updateConnectionTime(cleanName);
      return true;
    }

    final elapsed = now - lastTime;
    const sixHoursInSeconds = 6 * 3600;

    if (elapsed > sixHoursInSeconds * 1000) {
      updateConnectionTime(cleanName);
      return true;
    }

    return false;
  }

  void updateConnectionTime(String watchName) {
    lastConnectedTimes[watchName.trim()] =
        DateTime.now().millisecondsSinceEpoch;
  }
}

/// Global always-connected filter (mirrors Python's module global).
final AlwaysConnectedWatchFilter alwaysConnectedWatchFilter =
    AlwaysConnectedWatchFilter();
