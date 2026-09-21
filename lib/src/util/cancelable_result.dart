import 'dart:async';

import '../exceptions.dart';

/// Await-a-notification primitive mirroring
/// `gshock_api/src/gshock_api/cancelable_result.py`.
///
/// Unlike Python, callers should create the result *before* issuing the
/// triggering write (register-before-write) to avoid losing fast
/// notifications.
class CancelableResult<T> {
  CancelableResult({this.timeout = const Duration(seconds: 10)});

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
