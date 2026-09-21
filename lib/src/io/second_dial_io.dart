import 'dart:typed_data';

import 'connection_protocol.dart';
import 'dst_for_world_cities_io.dart';
import 'dst_watch_state_io.dart';
import 'world_cities_io.dart';
import '../model/watch_info.dart';
import '../util/logger.dart';

const int handleWrite = 0x000E;

final Uint8List resetSequenceStart = Uint8List.fromList(<int>[
  0x21,
  0x00,
  0x01,
]);
final Uint8List resetSequenceEnd = Uint8List.fromList(<int>[0x21, 0x01, 0x01]);

/// Implements the MTG-B1000 second-dial sequence.
class SecondDialIO {
  SecondDialIO._();

  static ConnectionProtocol? connection;

  static Future<void> setSecondDial(ConnectionProtocol connection) async {
    SecondDialIO.connection = connection;
    gshockLogger.info(['SecondDialIO: starting second dial sequence']);

    await connection.write(handleWrite, resetSequenceStart);
    gshockLogger.info(['ResetSequence start (210001)']);

    final dstData = await DstWatchStateIO.request(connection, DtsState.zero);
    await connection.write(handleWrite, dstData);

    final dstCity0 = await DstForWorldCitiesIO.request(connection, 0);
    final dstCity1 = await DstForWorldCitiesIO.request(connection, 1);
    await connection.write(handleWrite, dstCity0);
    await connection.write(handleWrite, dstCity1);

    if (watchInfo.hasWorldCities) {
      final wc0 = await WorldCitiesIO.request(connection, 0);
      final wc1 = await WorldCitiesIO.request(connection, 1);
      await connection.write(handleWrite, wc0);
      await connection.write(handleWrite, wc1);
    }

    await connection.write(handleWrite, resetSequenceEnd);
    gshockLogger.info(['ResetSequence end (210101)']);
    gshockLogger.info(['SecondDialIO: second dial sequence complete']);
  }
}
