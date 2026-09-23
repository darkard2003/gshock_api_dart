/// Exceptions mirroring `gshock_api/src/gshock_api/exceptions.py`.
library;

/// {@category Utilities & Exceptions}
///
/// Base exception class for errors originating from G-Shock watch communications.
class GShockException implements Exception {
  /// Creates a [GShockException] with optional [message], underlying [cause], and [stackTrace].
  GShockException([this.message = '', this.cause, this.stackTrace]);

  /// Informative error message.
  final String message;

  /// Optional underlying cause object.
  final Object? cause;

  /// Optional captured stack trace.
  final StackTrace? stackTrace;

  @override
  String toString() {
    if (message.isEmpty) return runtimeType.toString();
    if (cause != null) return '$message (cause: $cause)';
    return message;
  }
}

/// {@category Utilities & Exceptions}
///
/// Raised when BLE connection, GATT characteristic discovery, or data transmission fails.
class GShockConnectionException extends GShockException {
  /// Creates a [GShockConnectionException].
  GShockConnectionException([super.message, super.cause, super.stackTrace]);
}

/// {@category Utilities & Exceptions}
///
/// Raised when a connection error can be safely ignored without disrupting watch operations.
class GShockIgnorableException extends GShockConnectionException {
  /// Creates a [GShockIgnorableException].
  GShockIgnorableException([super.message, super.cause, super.stackTrace]);
}
