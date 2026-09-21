/// Exceptions mirroring `gshock_api/src/gshock_api/exceptions.py`.
library;

/// Base exception for all G-Shock errors.
class GShockException implements Exception {
  GShockException([this.message = '', this.cause, this.stackTrace]);

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() {
    if (message.isEmpty) return runtimeType.toString();
    if (cause != null) return '$message (cause: $cause)';
    return message;
  }
}

/// Raised when the BLE connection to a G-Shock device fails.
class GShockConnectionException extends GShockException {
  GShockConnectionException([super.message, super.cause, super.stackTrace]);
}

/// Raised when a connection error can be safely ignored.
class GShockIgnorableException extends GShockConnectionException {
  GShockIgnorableException([super.message, super.cause, super.stackTrace]);
}
