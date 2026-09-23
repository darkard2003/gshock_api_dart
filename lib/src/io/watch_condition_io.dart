import 'dart:typed_data';

import '../io/ble_action.dart';
import '../io/connection_protocol.dart';
import '../io/packet.dart';
import '../model/watch_info.dart';
import '../util/cancelable_result.dart';
import '../util/logger.dart';

/// Pure functional watch-condition decoder.
/// @nodoc
class WatchConditionIOFunctional {
  WatchConditionIOFunctional._();

  static Map<String, int> decode(Uint8List dataBytes) {
    const zero = <String, int>{'battery_level_percent': 0, 'temperature': 0};
    if (dataBytes.length < 3) return zero;

    late final Uint8List bytesData;
    try {
      final protocol = Protocol.fromValue(dataBytes[0]);
      if (protocol != Protocol.watchCondition) return zero;
      bytesData = Uint8List.sublistView(dataBytes, 1);
    } catch (_) {
      return zero;
    }

    if (bytesData.length >= 2) {
      final lower = watchInfo.batteryLevelLowerLimit;
      final upper = watchInfo.batteryLevelUpperLimit;
      final multiplier = (100.0 / (upper - lower)).round();
      final batteryLevel = bytesData[0] - lower;
      final batteryLevelPercent = (batteryLevel * multiplier).clamp(0, 100);
      final temperature = bytesData[1];
      return <String, int>{
        'battery_level_percent': batteryLevelPercent,
        'temperature': temperature,
      };
    }
    return zero;
  }

  static List<BleAction> prepareWatchCommands() => <BleAction>[
    WriteAction(
      handle: 0x000C,
      data: Uint8List.fromList(<int>[Protocol.watchCondition.value]),
    ),
  ];
}

/// Stateful wrapper around [WatchConditionIOFunctional].
/// @nodoc
class WatchConditionIO {
  WatchConditionIO._();

  static CancelableResult<Map<String, int>>? result;
  static ConnectionProtocol? connection;

  static Future<Map<String, int>> request(
    ConnectionProtocol connection, {
    String requestCmd = '28',
  }) async {
    WatchConditionIO.connection = connection;
    final pending = CancelableResult<Map<String, int>>();
    WatchConditionIO.result = pending;
    try {
      await connection.request(requestCmd);
      return await pending.getResult();
    } finally {
      if (identical(WatchConditionIO.result, pending)) {
        WatchConditionIO.result = null;
      }
    }
  }

  static Future<void> sendToWatch(ConnectionProtocol connection) async {
    for (final command in WatchConditionIOFunctional.prepareWatchCommands()) {
      if (command is WriteAction) {
        await connection.write(command.handle, command.data);
      }
    }
  }

  static void onReceived(Uint8List data) {
    final decoded = WatchConditionIOFunctional.decode(data);
    if (result == null) {
      gshockLogger.warning(['WatchConditionIO.result is not set']);
      return;
    }
    result!.setResult(decoded);
  }
}
