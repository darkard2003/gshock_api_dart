import 'dart:typed_data';

import '../io/ble_action.dart';
import '../io/connection_protocol.dart';
import '../io/packet.dart';
import '../util/cancelable_result.dart';
import '../util/logger.dart';

/// DST watch states.
enum DtsState {
  zero(0),
  two(2),
  four(4);

  const DtsState(this.value);

  final int value;
}

/// Pure functional DST watch-state command generator.
class DstWatchStateIOFunctional {
  DstWatchStateIOFunctional._();

  static List<BleAction> prepareWatchCommands() => <BleAction>[
    WriteAction(
      handle: 0x000C,
      data: Uint8List.fromList(<int>[Protocol.dstWatchState.value]),
    ),
  ];
}

/// Stateful wrapper around [DstWatchStateIOFunctional].
class DstWatchStateIO {
  DstWatchStateIO._();

  static CancelableResult<Uint8List>? result;
  static ConnectionProtocol? connection;

  static Future<Uint8List> request(
    ConnectionProtocol connection,
    DtsState state,
  ) async {
    DstWatchStateIO.connection = connection;
    final pending = CancelableResult<Uint8List>();
    DstWatchStateIO.result = pending;
    try {
      final key =
          '${Protocol.dstWatchState.value.toRadixString(16).padLeft(2, '0')}0${state.value}';
      await connection.request(key);
      return await pending.getResult();
    } finally {
      if (identical(DstWatchStateIO.result, pending)) {
        DstWatchStateIO.result = null;
      }
    }
  }

  static Future<void> sendToWatch(ConnectionProtocol connection) async {
    for (final command in DstWatchStateIOFunctional.prepareWatchCommands()) {
      if (command is WriteAction) {
        await connection.write(command.handle, command.data);
      }
    }
  }

  static Uint8List setDst(Uint8List originalData, int dstValue) {
    final dataList = originalData.toList();
    if (dataList.length > 3) {
      dataList[3] = dstValue;
    }
    return Uint8List.fromList(dataList);
  }

  static void onReceived(Uint8List data) {
    if (result == null) {
      gshockLogger.warning(['DstWatchStateIO.result is not set']);
      return;
    }
    result!.setResult(data);
  }
}
