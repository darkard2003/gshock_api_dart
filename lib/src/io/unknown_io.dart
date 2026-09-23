import 'dart:typed_data';

import '../util/logger.dart';

/// Logs unknown characteristic payloads.
/// @nodoc
class UnknownIO {
  UnknownIO._();

  static void onReceived(Uint8List message) {
    gshockLogger.info(['UnknownIO onReceived: $message']);
  }
}
