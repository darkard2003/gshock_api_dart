import 'dart:convert';
import 'dart:typed_data';

import '../io/ble_action.dart';
import '../io/connection_protocol.dart';
import '../io/packet.dart';
import '../model/watch_info.dart';
import '../util/bytes.dart';
import '../util/cancelable_result.dart';
import '../util/logger.dart';

/// Pure functional timer codec.
/// @nodoc
class TimerIOFunctional {
  TimerIOFunctional._();

  static Uint8List encode(int seconds) {
    final hours = seconds ~/ 3600;
    final minutesAndSeconds = seconds % 3600;
    final minutes = minutesAndSeconds ~/ 60;
    final secs = minutesAndSeconds % 60;
    return Uint8List.fromList(<int>[
      Protocol.timer.value,
      hours,
      minutes,
      secs,
      0,
      0,
    ]);
  }

  static int decode(Uint8List dataBytes) {
    const headerOffset = 1;
    if (dataBytes.length < 4) return 0;
    final hours = dataBytes[headerOffset];
    final minutes = dataBytes[1 + headerOffset];
    final seconds = dataBytes[2 + headerOffset];
    return hours * 3600 + minutes * 60 + seconds;
  }

  static Uint8List encodeMtgB3000(int seconds) {
    final hours = seconds ~/ 3600;
    final minutesAndSeconds = seconds % 3600;
    final minutes = minutesAndSeconds ~/ 60;
    final secs = minutesAndSeconds % 60;
    return Uint8List.fromList(<int>[
      Protocol.timer.value,
      hours,
      minutes,
      secs,
      ...List<int>.filled(11, 0),
    ]);
  }

  static List<BleAction> prepareWatchCommands() => <BleAction>[
    WriteAction(
      handle: 0x000C,
      data: Uint8List.fromList(<int>[Protocol.timer.value]),
    ),
  ];

  static List<BleAction> prepareWatchCommandsSet(String messageJson) {
    final dataObj = (jsonDecode(messageJson) as Map).cast<String, Object?>();
    final seconds = (dataObj['value'] as num?)?.toInt() ?? 0;
    return <BleAction>[WriteAction(handle: 0x000E, data: encode(seconds))];
  }

  static List<BleAction> prepareWatchCommandsSetMtgB3000(String messageJson) {
    final dataObj = (jsonDecode(messageJson) as Map).cast<String, Object?>();
    final seconds = (dataObj['value'] as num?)?.toInt() ?? 0;
    return <BleAction>[
      WriteAction(handle: 0x000E, data: encodeMtgB3000(seconds)),
    ];
  }
}

/// Stateful wrapper around [TimerIOFunctional].
/// @nodoc
class TimerIO {
  TimerIO._();

  static CancelableResult<int>? result;
  static ConnectionProtocol? connection;

  static Future<int> request(ConnectionProtocol connection) async {
    TimerIO.connection = connection;
    final pending = CancelableResult<int>();
    TimerIO.result = pending;
    try {
      await connection.request(
        Protocol.timer.value.toRadixString(16).padLeft(2, '0').toUpperCase(),
      );
      return await pending.getResult();
    } finally {
      if (identical(TimerIO.result, pending)) {
        TimerIO.result = null;
      }
    }
  }

  static Future<void> sendToWatch([String message = '']) async {
    final conn = TimerIO.connection;
    if (conn == null) {
      throw StateError('TimerIO.connection is not set');
    }
    for (final command in TimerIOFunctional.prepareWatchCommands()) {
      if (command is WriteAction) {
        await conn.write(command.handle, command.data);
      }
    }
  }

  static Future<void> sendToWatchSet(String data) async {
    final conn = TimerIO.connection;
    if (conn == null) {
      throw StateError('TimerIO.connection is not set');
    }
    final commands = watchInfo.model == WatchModel.mtgB3000
        ? TimerIOFunctional.prepareWatchCommandsSetMtgB3000(data)
        : TimerIOFunctional.prepareWatchCommandsSet(data);

    for (final command in commands) {
      if (command is WriteAction) {
        final secondsAsCompactStr = Bytes.toCompactString(
          Bytes.toHexString(command.data),
        );
        await conn.write(0x000E, secondsAsCompactStr);
      }
    }
  }

  static void onReceived(Uint8List data) {
    final decoded = TimerIOFunctional.decode(data);
    if (result == null) {
      gshockLogger.warning(['TimerIO.result is not set']);
      return;
    }
    result!.setResult(decoded);
  }
}
