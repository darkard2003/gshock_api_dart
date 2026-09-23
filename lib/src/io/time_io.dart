import 'dart:convert';
import 'dart:typed_data';

import '../exceptions.dart';
import '../io/ble_action.dart';
import '../io/connection_protocol.dart';
import '../io/packet.dart';
import '../util/bytes.dart';
import '../util/logger.dart';

/// Pure functional current-time encoder.
/// @nodoc
class TimeEncoderPure {
  TimeEncoderPure._();

  /// Encodes [dt] into the 10-byte watch payload.
  static Uint8List encodeCurrentTime(DateTime dt) {
    final nanos = (dt.millisecond * 1000 + dt.microsecond) * 1000;
    final nanoByte = (nanos * 256 ~/ 1000000000) & 0xFF;
    final bytes = Uint8List(10);
    bytes[0] = dt.year & 0xFF;
    bytes[1] = (dt.year >> 8) & 0xFF;
    bytes[2] = dt.month;
    bytes[3] = dt.day;
    bytes[4] = dt.hour;
    bytes[5] = dt.minute;
    bytes[6] = dt.second;
    bytes[7] = dt.weekday - 1;
    bytes[8] = nanoByte;
    bytes[9] = 0x01;
    return bytes;
  }
}

/// Pure functional command generator.
/// @nodoc
class TimeIOFunctional {
  TimeIOFunctional._();

  static String generateRequestMessage(double? currentTime, int offset) {
    return jsonEncode(<String, Object?>{
      'action': 'SET_TIME',
      'value': <String, Object?>{
        'time': currentTime?.round(),
        'offset': offset,
      },
    });
  }

  static List<BleAction> prepareWatchCommands(
    String messageJson,
    double systemTime,
  ) {
    final data = (jsonDecode(messageJson) as Map).cast<String, Object?>();
    final value = ((data['value'] as Map?) ?? const <String, Object?>{})
        .cast<String, Object?>();
    final rawTimestamp = value['time'];
    final double? timestamp = (rawTimestamp as num?)?.toDouble();
    final offset = (value['offset'] as num?)?.toInt() ?? 0;

    final effective = timestamp ?? systemTime;
    final dateTime = DateTime.fromMillisecondsSinceEpoch(
      ((effective + offset) * 1000).round(),
    );
    final timePayload = TimeEncoderPure.encodeCurrentTime(dateTime);

    final packetBytes = Uint8List.fromList(<int>[
      Protocol.currentTime.value,
      ...timePayload,
    ]);
    return <BleAction>[WriteAction(handle: 0x000E, data: packetBytes)];
  }
}

/// Stateful adapter wrapper.
/// @nodoc
class TimeIO {
  TimeIO._();

  static ConnectionProtocol? connection;

  static Future<void> request(
    ConnectionProtocol connection,
    double? currentTime,
    int offset,
  ) async {
    TimeIO.connection = connection;
    final messageStr = TimeIOFunctional.generateRequestMessage(
      currentTime,
      offset,
    );
    await connection.sendMessage(messageStr);
  }

  static Future<void> sendToWatchSet(String message) async {
    final systemTime = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final commands = TimeIOFunctional.prepareWatchCommands(message, systemTime);
    final conn = TimeIO.connection;
    if (conn == null) {
      throw StateError('TimeIO.connection is not set');
    }
    for (final command in commands) {
      if (command is WriteAction) {
        final timeCommand = Bytes.toHexString(command.data);
        try {
          await conn.write(command.handle, Bytes.toCompactString(timeCommand));
        } on GShockIgnorableException catch (e) {
          gshockLogger.info(['Ignoring $e']);
        }
      }
    }
  }
}

/// Legacy encoder class delegating to [TimeEncoderPure].
/// @nodoc
class TimeEncoder {
  TimeEncoder._();

  static Uint8List prepareCurrentTime(DateTime dt) =>
      TimeEncoderPure.encodeCurrentTime(dt);
}
