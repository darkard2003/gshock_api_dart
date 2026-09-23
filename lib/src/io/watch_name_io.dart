import 'dart:typed_data';

import '../io/ble_action.dart';
import '../io/connection_protocol.dart';
import '../io/packet.dart';
import '../util/bytes.dart';
import '../util/cancelable_result.dart';
import '../util/logger.dart';

/// Pure functional watch-name codec.
/// @nodoc
class WatchNameIOFunctional {
  WatchNameIOFunctional._();

  static String decode(Uint8List dataBytes) {
    final hexStr = Bytes.toHexString(dataBytes);
    final asciiStr = Bytes.toAsciiString(hexStr, 1);
    return Bytes.cleanStr(asciiStr);
  }

  static List<BleAction> prepareWatchCommands() => <BleAction>[
    WriteAction(
      handle: 0x000C,
      data: Uint8List.fromList(<int>[Protocol.watchName.value]),
    ),
  ];
}

/// Stateful wrapper around [WatchNameIOFunctional].
/// @nodoc
class WatchNameIO {
  WatchNameIO._();

  static CancelableResult<String>? result;
  static ConnectionProtocol? connection;

  static Future<String> request(ConnectionProtocol connection) async {
    WatchNameIO.connection = connection;
    final pending = CancelableResult<String>();
    WatchNameIO.result = pending;
    try {
      await connection.request(
        Protocol.watchName.value
            .toRadixString(16)
            .padLeft(2, '0')
            .toUpperCase(),
      );
      return await pending.getResult();
    } finally {
      if (identical(WatchNameIO.result, pending)) {
        WatchNameIO.result = null;
      }
    }
  }

  static void onReceived(Uint8List data) {
    final cleanData = WatchNameIOFunctional.decode(data);
    if (result == null) {
      gshockLogger.warning(['WatchNameIO.result is not set']);
      return;
    }
    result!.setResult(cleanData);
  }

  static Future<void> sendToWatch() async {}
}
