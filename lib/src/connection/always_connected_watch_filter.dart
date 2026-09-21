import '../model/watch_info.dart';

/// For always-connected watches, limit the connection frequency to once every
/// 6 hours. Otherwise they may block other watches from connecting.
class AlwaysConnectedWatchFilter {
  final Map<String, int> lastConnectedTimes = <String, int>{};

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
