import 'dart:convert';
import 'dart:typed_data';

import '../io/ble_action.dart';
import '../io/connection_protocol.dart';
import '../io/packet.dart';
import '../util/cancelable_result.dart';
import '../util/logger.dart';

/// Pure functional world-cities command generator.
class WorldCitiesIOFunctional {
  WorldCitiesIOFunctional._();

  static List<BleAction> prepareWatchCommands() => <BleAction>[
    WriteAction(
      handle: 0x000C,
      data: Uint8List.fromList(<int>[Protocol.worldCities.value]),
    ),
  ];
}

/// Stateful wrapper around [WorldCitiesIOFunctional].
class WorldCitiesIO {
  WorldCitiesIO._();

  static CancelableResult<Uint8List>? result;
  static ConnectionProtocol? connection;

  static Future<Uint8List> request(
    ConnectionProtocol connection,
    int cityNumber,
  ) async {
    WorldCitiesIO.connection = connection;
    final pending = CancelableResult<Uint8List>();
    WorldCitiesIO.result = pending;
    try {
      final key =
          '${Protocol.worldCities.value.toRadixString(16).padLeft(2, '0').toUpperCase()}0$cityNumber';
      await connection.request(key);
      return await pending.getResult();
    } finally {
      if (identical(WorldCitiesIO.result, pending)) {
        WorldCitiesIO.result = null;
      }
    }
  }

  static Future<void> sendToWatch(ConnectionProtocol connection) async {
    for (final command in WorldCitiesIOFunctional.prepareWatchCommands()) {
      if (command is WriteAction) {
        await connection.write(command.handle, command.data);
      }
    }
  }

  static String parseCity(String timeZoneName) {
    return timeZoneName.split('/').last.split(':').last.toUpperCase();
  }

  static Uint8List encodeAndPad(String cityName, int cityNumber) {
    final cityBytes = ascii.encode(cityName);
    final padded = Uint8List(19);
    padded[0] = Protocol.worldCities.value;
    padded[1] = cityNumber;

    for (var i = 0; i < cityBytes.length; i++) {
      if (i + 2 < 19) {
        padded[i + 2] = cityBytes[i];
      } else {
        break;
      }
    }
    return padded;
  }

  static void onReceived(Uint8List data) {
    if (result == null) {
      gshockLogger.warning(['WorldCitiesIO.result is not set']);
      return;
    }
    result!.setResult(data);
  }
}
