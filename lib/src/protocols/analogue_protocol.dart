import 'dart:typed_data';

import '../io/connection_protocol.dart';
import '../io/home_time_io.dart';
import '../io/second_dial_io.dart';
import '../io/time_io.dart';
import '../model/watch_info.dart';
import 'standard_protocol.dart';

/// {@category Protocols & Constants}
///
/// Protocol implementation for premium analogue G-Shock watches (MTG-B1000, MTG-B3000, GST-B100).
///
/// Handles analogue dial motor calibrations, wrapped envelope unpacking,
/// second-dial reset sequences, and 12-byte settings formats.
class AnalogueProtocol extends StandardProtocol {
  @override
  int? extractKey(Uint8List data) {
    if (data.isEmpty) return null;

    final firstByte = data[0];
    if (firstByte == 0x28 && data.length > 4) {
      final handlers = dataReceivedHandlers;
      if (data[1] == 0x01 && handlers.containsKey(data[4])) {
        return data[4];
      } else if (data[1] == 0x00 && handlers.containsKey(data[3])) {
        return data[3];
      } else {
        return 0x28;
      }
    }
    return firstByte;
  }

  @override
  Uint8List unwrapPayload(Uint8List data, int key) {
    if (data.isEmpty) return data;

    if (data[0] == 0x28 && key != 0x28) {
      final skip = (data.length > 1 && data[1] == 0x01) ? 4 : 3;
      return data.length > skip ? data.sublist(skip) : Uint8List(0);
    }
    return data;
  }

  @override
  String getWatchConditionRequest() => '280000';

  @override
  Future<void> setTime(
    ConnectionProtocol connection, {
    double? currentTime,
    int offset = 0,
  }) async {
    await readWriteDstWatchStates(connection);
    await readWriteDstForWorldCities(connection);
    await readWriteHomeTimes(connection);
    await TimeIO.request(connection, currentTime, offset);

    if (watchInfo.hasSecondDial) {
      await SecondDialIO.setSecondDial(connection);
    }
  }

  @override
  String getTimerRequest() => '182000';

  @override
  int getTimerSize() => 15;

  @override
  Future<String> getHomeTime(ConnectionProtocol connection) async {
    final rawBytes = await HomeTimeIO.requestRaw(connection, slot: 0);
    return _hex(rawBytes);
  }

  static String _hex(Uint8List bytes) {
    final buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write((b & 0xFF).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
