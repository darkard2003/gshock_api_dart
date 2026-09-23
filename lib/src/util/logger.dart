/// Minimal logging wrapper mirroring `gshock_api/src/gshock_api/logger.py`.
///
/// The Python library configures the stdlib `logging` module. For a portable
/// Dart core we keep a tiny sink-based logger so consumers can route logs to
/// their own framework (and so tests stay quiet by default).
library;

/// {@category Utilities & Exceptions}
///
/// Log severity levels for G-Shock Bluetooth operations.
enum GshockLogLevel {
  /// Verbose protocol and packet dumps.
  debug,

  /// General operational status messages.
  info,

  /// Recoverable issues or unrecognized packets.
  warning,

  /// Connection failures and protocol errors.
  error,
}

typedef GshockLogSink = void Function(GshockLogLevel level, String message);

/// Joins arguments the way `print()` does.
String _join(List<Object?> args) => args.map((a) => '$a').join(' ');

/// {@category Utilities & Exceptions}
///
/// Configurable zero-allocation logger for the G-Shock library.
///
/// Supports custom sink redirection to Flutter's `debugPrint`, standard logging frameworks,
/// or file outputs.
class GshockLogger {
  /// Creates a logger configured with [level] and optional output [sink].
  GshockLogger({this.level = GshockLogLevel.info, this.sink});

  /// Minimum severity level required for messages to be logged.
  final GshockLogLevel level;

  /// Optional sink receiving formatted log messages.
  final GshockLogSink? sink;

  void _log(
    GshockLogLevel messageLevel,
    Object? message, [
    List<Object?>? extraArgs,
  ]) {
    if (messageLevel.index < level.index || sink == null) return;
    if (message is List) {
      sink?.call(messageLevel, _join(message));
    } else if (extraArgs != null && extraArgs.isNotEmpty) {
      sink?.call(messageLevel, '$message ${_join(extraArgs)}');
    } else {
      sink?.call(messageLevel, '$message');
    }
  }

  void error(Object? message, [List<Object?>? extraArgs]) =>
      _log(GshockLogLevel.error, message, extraArgs);
  void info(Object? message, [List<Object?>? extraArgs]) =>
      _log(GshockLogLevel.info, message, extraArgs);
  void debug(Object? message, [List<Object?>? extraArgs]) =>
      _log(GshockLogLevel.debug, message, extraArgs);
  void warn(Object? message, [List<Object?>? extraArgs]) =>
      _log(GshockLogLevel.warning, message, extraArgs);
  void warning(Object? message, [List<Object?>? extraArgs]) =>
      _log(GshockLogLevel.warning, message, extraArgs);
}

/// Global logger instance. Silent by default; supply a [GshockLogSink] to
/// observe output.
GshockLogger gshockLogger = GshockLogger();
