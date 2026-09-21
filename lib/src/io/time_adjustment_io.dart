import 'dart:convert';
import 'dart:typed_data';

import '../io/ble_action.dart';
import '../io/connection_protocol.dart';
import '../io/packet.dart';
import '../util/bytes.dart';
import '../util/cancelable_result.dart';
import '../util/logger.dart';
import 'error_io.dart';

/// Pure functional time-adjustment codec.
class TimeAdjustmentIOFunctional {
  TimeAdjustmentIOFunctional._();

  static Uint8List encode(
    String originalHex,
    bool timeAdjustment,
    int minutesAfterHour,
  ) {
    final intArray = Bytes.toIntArray(originalHex);
    intArray[12] = timeAdjustment ? 0x00 : 0x80;
    intArray[13] = minutesAfterHour;
    return Uint8List.fromList(intArray);
  }

  static Map<String, String> decode(Uint8List dataBytes) {
    final timeAdjusted = dataBytes[12] == 0x00;
    final minutesAfterHour = dataBytes[13];
    return <String, String>{
      'timeAdjustment': timeAdjusted ? 'True' : 'False',
      'minutesAfterHour': '$minutesAfterHour',
    };
  }

  static List<BleAction> prepareWatchCommands() => <BleAction>[
    WriteAction(
      handle: 0x000C,
      data: Uint8List.fromList(<int>[Protocol.settingForBle.value]),
    ),
  ];

  static List<BleAction> prepareWatchCommandsSet(
    String messageJson,
    String originalHex,
  ) {
    final parsed = (jsonDecode(messageJson) as Map).cast<String, Object?>();
    final timeAdjustment =
        parsed['timeAdjustment']?.toString().toLowerCase() == 'true';
    final minutesAfterHour =
        int.tryParse('${parsed['minutesAfterHour'] ?? '0'}') ?? 0;

    final encoded = encode(originalHex, timeAdjustment, minutesAfterHour);
    return <BleAction>[WriteAction(handle: 0x000E, data: encoded)];
  }
}

/// Stateful wrapper around [TimeAdjustmentIOFunctional].
class TimeAdjustmentIO {
  TimeAdjustmentIO._();

  static CancelableResult<Map<String, String>>? result;
  static ConnectionProtocol? connection;
  static String? originalValue;

  static Future<Map<String, String>> request(
    ConnectionProtocol connection,
  ) async {
    TimeAdjustmentIO.connection = connection;
    final pending = CancelableResult<Map<String, String>>();
    TimeAdjustmentIO.result = pending;
    try {
      await connection.request(
        Protocol.settingForBle.value
            .toRadixString(16)
            .padLeft(2, '0')
            .toUpperCase(),
      );
      return await pending.getResult();
    } finally {
      if (identical(TimeAdjustmentIO.result, pending)) {
        TimeAdjustmentIO.result = null;
      }
    }
  }

  static Future<void> sendToWatch(String message) async {
    final conn = TimeAdjustmentIO.connection;
    if (conn == null) {
      throw StateError('TimeAdjustmentIO.connection is not set');
    }
    for (final command in TimeAdjustmentIOFunctional.prepareWatchCommands()) {
      if (command is WriteAction) {
        await conn.write(command.handle, command.data);
      }
    }
  }

  static Future<void> sendToWatchSet(String message) async {
    if (originalValue == null) {
      await ErrorIO.request('Error: Must call get before set');
      return;
    }
    final conn = TimeAdjustmentIO.connection;
    if (conn == null) {
      throw StateError('TimeAdjustmentIO.connection is not set');
    }
    final commands = TimeAdjustmentIOFunctional.prepareWatchCommandsSet(
      message,
      originalValue!,
    );
    for (final command in commands) {
      if (command is WriteAction) {
        final writeCmd = Bytes.toCompactString(Bytes.toHexString(command.data));
        await conn.write(0x000E, writeCmd);
      }
    }
  }

  static void onReceived(Uint8List message) {
    originalValue = Bytes.toHexString(message);
    final decoded = TimeAdjustmentIOFunctional.decode(message);
    if (result == null) {
      gshockLogger.warning(['TimeAdjustmentIO.result is not set']);
      return;
    }
    result!.setResult(decoded);
  }

  static Future<void> onReceivedSet(Uint8List message) async {
    gshockLogger.info(['TimeAdjustmentIO onReceivedSet: $message']);
  }
}
