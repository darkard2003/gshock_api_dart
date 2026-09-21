import 'dart:typed_data';

import '../util/logger.dart';

/// Logs error characteristic payloads.
class ErrorIO {
  ErrorIO._();

  static Future<void> request(String message) async {
    gshockLogger.info([message]);
  }

  static void onReceived(Uint8List message) {
    gshockLogger.info(['ErrorIO onReceived: $message']);
  }
}
