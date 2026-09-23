import 'dart:typed_data';

import '../io/ble_action.dart';
import '../io/connection_protocol.dart';
import '../io/packet.dart';
import '../timezone/casio_time_zone_helper.dart';
import '../util/cancelable_result.dart';
import '../util/logger.dart';

/// Pure functional DST-for-world-cities command generator.
/// @nodoc
class DstForWorldCitiesIOFunctional {
  DstForWorldCitiesIOFunctional._();

  static List<BleAction> prepareWatchCommands() => <BleAction>[
    WriteAction(
      handle: 0x000C,
      data: Uint8List.fromList(<int>[Protocol.dstSetting.value]),
    ),
  ];
}

/// Stateful wrapper around [DstForWorldCitiesIOFunctional].
/// @nodoc
class DstForWorldCitiesIO {
  DstForWorldCitiesIO._();

  static CancelableResult<Uint8List>? result;
  static ConnectionProtocol? connection;

  static Future<Uint8List> request(
    ConnectionProtocol connection,
    int cityNumber,
  ) async {
    DstForWorldCitiesIO.connection = connection;
    final pending = CancelableResult<Uint8List>();
    DstForWorldCitiesIO.result = pending;
    try {
      final key =
          '${Protocol.dstSetting.value.toRadixString(16).padLeft(2, '0')}0$cityNumber';
      await connection.request(key);
      return await pending.getResult();
    } finally {
      if (identical(DstForWorldCitiesIO.result, pending)) {
        DstForWorldCitiesIO.result = null;
      }
    }
  }

  static Future<void> sendToWatch(ConnectionProtocol connection) async {
    for (final command
        in DstForWorldCitiesIOFunctional.prepareWatchCommands()) {
      if (command is WriteAction) {
        await connection.write(command.handle, command.data);
      }
    }
  }

  static Uint8List setDst(Uint8List originalData, CasioTimeZone casioTz) {
    final dataList = originalData.toList();
    if (dataList.length > 6) {
      dataList[4] = casioTz.offset & 0xFF;
      dataList[5] = casioTz.dstOffset & 0xFF;
      dataList[6] = casioTz.dstRules & 0xFF;
    }
    return Uint8List.fromList(dataList);
  }

  static void onReceived(Uint8List data) {
    if (result == null) {
      gshockLogger.warning(['DstForWorldCitiesIO.result is not set']);
      return;
    }
    result!.setResult(data);
  }
}
