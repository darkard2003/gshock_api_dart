import 'dart:async';

import '../exceptions.dart';

/// {@category Utilities & Exceptions}
///
/// Async notification awaiting primitive with timeout and cancellation support.
///
/// Implements the register-before-write pattern to prevent race conditions where
/// fast watch notifications arrive before the listening future is registered.
class CancelableResult<T> {
  /// Creates a [CancelableResult] with the specified [timeout] (defaults to 10 seconds).
  CancelableResult({this.timeout = const Duration(seconds: 10)});

  /// Maximum duration to await notification completion before timing out.
  final Duration timeout;
  final Completer<T> _completer = Completer<T>();

  bool get isCompleted => _completer.isCompleted;

  Future<T> getResult() async {
    try {
      return await _completer.future.timeout(timeout);
    } on TimeoutException catch (e, st) {
      throw GShockConnectionException(
        'Timeout waiting for response from the watch: $e',
        e,
        st,
      );
    }
  }

  void setResult(T value) {
    if (!_completer.isCompleted) {
      _completer.complete(value);
    }
  }

  void setError(Object error, [StackTrace? stackTrace]) {
    if (!_completer.isCompleted) {
      _completer.completeError(error, stackTrace);
    }
  }
}
