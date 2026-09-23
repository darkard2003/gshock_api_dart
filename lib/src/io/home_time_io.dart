import 'dart:typed_data';

import '../constants/casio_constants.dart';
import '../io/connection_protocol.dart';
import '../model/watch_info.dart';
import '../util/cancelable_result.dart';
import 'world_cities_io.dart';

/// Pure functional HomeTime processing.
/// @nodoc
class HomeTimeIOFunctional {
  HomeTimeIOFunctional._();

  /// Skips the first 2 header bytes, decodes the remainder as ASCII and strips
  /// the first null terminator.
  static String parseHomeCity(Uint8List data) {
    final rest = data.length > 2 ? data.sublist(2) : Uint8List(0);
    final end = rest.indexOf(0);
    final bytes = end >= 0 ? rest.sublist(0, end) : rest;
    return String.fromCharCodes(bytes);
  }
}

/// Stateful HomeTime wrapper delegating the read to [WorldCitiesIO] or the
/// dedicated `0x24` home-time characteristic (MTG-B3000).
/// @nodoc
class HomeTimeIO {
  HomeTimeIO._();

  static CancelableResult<Uint8List>? result;
  static ConnectionProtocol? connection;

  static Future<Uint8List> requestRaw(
    ConnectionProtocol connection, {
    int slot = 0,
  }) async {
    if (watchInfo.model == WatchModel.mtgB3000) {
      HomeTimeIO.connection = connection;
      final pending = CancelableResult<Uint8List>();
      HomeTimeIO.result = pending;
      try {
        final key =
            '${CasioConstants.characteristics['CASIO_HOME_TIME']!.toRadixString(16).padLeft(2, '0').toUpperCase()}0$slot';
        await connection.request(key);
        return await pending.getResult();
      } finally {
        if (identical(HomeTimeIO.result, pending)) {
          HomeTimeIO.result = null;
        }
      }
    } else {
      return WorldCitiesIO.request(connection, slot);
    }
  }

  static Future<void> sendToWatch([String message = '']) async {
    await WorldCitiesIO.sendToWatch(WorldCitiesIO.connection!);
  }

  static void onReceived(Uint8List data) {
    if (result != null) {
      result!.setResult(data);
    } else {
      WorldCitiesIO.onReceived(data);
    }
  }

  /// Reads the city name for [slot] from the watch.
  static Future<String> request(
    ConnectionProtocol connection, {
    int slot = 0,
  }) async {
    final raw = await requestRaw(connection, slot: slot);
    return HomeTimeIOFunctional.parseHomeCity(raw);
  }
}
