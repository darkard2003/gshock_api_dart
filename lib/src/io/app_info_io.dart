import 'dart:async';
import 'dart:typed_data';

import '../io/ble_action.dart';
import '../io/connection_protocol.dart';
import '../io/packet.dart';
import '../util/bytes.dart';
import '../util/cancelable_result.dart';
import '../util/logger.dart';

/// Pure functional app-info handshake.
/// @nodoc
class AppInfoIOFunctional {
  AppInfoIOFunctional._();

  static List<BleAction> prepareWatchCommands() => <BleAction>[
    WriteAction(
      handle: 0x000C,
      data: Uint8List.fromList(<int>[Protocol.appInfo.value]),
    ),
  ];

  static List<BleAction> prepareWatchResponse(Uint8List data) {
    if (data.length >= 12) {
      try {
        final protocol = Protocol.fromValue(data[0]);
        final header = Header(
          protocol: protocol ?? Protocol.error,
          size: data.length,
        );
        final payload = Uint8List.sublistView(data, 1, 11);
        final trailer = Uint8List.sublistView(data, 11);
        final checksum = data[data.length - 1];

        final payloadAllFf = payload.every((b) => b == 0xFF);
        if (header.protocol == Protocol.appInfo &&
            payloadAllFf &&
            trailer[0] == 0x00) {
          final resHeader = Header(protocol: Protocol.appInfo, size: 12);
          final resPayload = Bytes.fromCasioCmd('3488F4E5D5AFC829E06D');
          final resTrailer = Uint8List.fromList(<int>[0x02]);
          final packetBytes = Uint8List.fromList(<int>[
            resHeader.protocol.value,
            ...resPayload,
            ...resTrailer,
          ]);
          return <BleAction>[WriteAction(handle: 0xE, data: packetBytes)];
        }
        // Keep checksum referenced for parity with the Python trailer.
        assert(checksum >= 0);
      } catch (_) {
        // ignore malformed packets
      }
    }
    return <BleAction>[];
  }
}

/// Stateful wrapper around [AppInfoIOFunctional].
/// @nodoc
class AppInfoIO {
  AppInfoIO._();

  static CancelableResult<String>? result;
  static ConnectionProtocol? connection;

  static Future<String> request(ConnectionProtocol connection) async {
    AppInfoIO.connection = connection;
    final pending = CancelableResult<String>();
    AppInfoIO.result = pending;
    try {
      await connection.request(
        Protocol.appInfo.value.toRadixString(16).padLeft(2, '0').toUpperCase(),
      );
      return await pending.getResult();
    } finally {
      if (identical(AppInfoIO.result, pending)) {
        AppInfoIO.result = null;
      }
    }
  }

  static Future<void> sendToWatch(ConnectionProtocol connection) async {
    for (final command in AppInfoIOFunctional.prepareWatchCommands()) {
      if (command is WriteAction) {
        await connection.write(command.handle, command.data);
      }
    }
  }

  static void onReceived(Uint8List data) {
    gshockLogger.info(['AppInfoIO.on_received: ${Bytes.toHexString(data)}']);
    unawaited(
      Future(() async {
        final commands = AppInfoIOFunctional.prepareWatchResponse(data);
        if (commands.isNotEmpty) {
          final conn = AppInfoIO.connection;
          if (conn == null) {
            throw StateError('AppInfoIO.connection is not set');
          }
          for (final command in commands) {
            if (command is WriteAction) {
              await conn.write(command.handle, command.data);
            }
          }
        }

        if (result == null) {
          throw StateError('AppInfoIO.result is not set');
        }
        result!.setResult('OK');
      }),
    );
  }
}
