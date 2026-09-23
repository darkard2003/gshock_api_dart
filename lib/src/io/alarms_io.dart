import 'dart:convert';
import 'dart:typed_data';

import '../constants/casio_constants.dart';
import '../io/ble_action.dart';
import '../io/connection_protocol.dart';
import '../model/alarms.dart';
import '../model/watch_info.dart';
import '../util/bytes.dart';
import '../util/cancelable_result.dart';

const Map<String, int> _characteristics = CasioConstants.characteristics;

/// Pure functional core for the alarm protocol.
/// @nodoc
class AlarmsIOFunctional {
  AlarmsIOFunctional._();

  static List<BleAction> prepareWatchCommands() => <BleAction>[
    WriteAction(
      handle: 0x000C,
      data: Uint8List.fromList(<int>[
        _characteristics['CASIO_SETTING_FOR_ALM']!,
      ]),
    ),
    WriteAction(
      handle: 0x000C,
      data: Uint8List.fromList(<int>[
        _characteristics['CASIO_SETTING_FOR_ALM2']!,
      ]),
    ),
  ];

  static List<BleAction> prepareWatchCommandsMtgB3000() => <BleAction>[
    WriteAction(
      handle: 0x000C,
      data: Uint8List.fromList(<int>[
        _characteristics['CASIO_SETTING_FOR_ALM']!,
      ]),
    ),
  ];

  static List<BleAction> prepareWatchCommandsSet(String messageJson) {
    final parsed = (jsonDecode(messageJson) as Map).cast<String, Object?>();
    final alarms =
        (parsed['value'] as List?)?.cast<Map<String, Object?>>() ??
        <Map<String, Object?>>[];

    final alarmCasio0 = alarmsInst.fromJsonAlarmFirstAlarm(alarms[0]);
    final alarmCasio = alarmsInst.fromJsonAlarmSecondaryAlarms(alarms);

    return <BleAction>[
      WriteAction(handle: 0x000E, data: Uint8List.fromList(alarmCasio0)),
      WriteAction(handle: 0x000E, data: Uint8List.fromList(alarmCasio)),
    ];
  }

  static List<BleAction> prepareWatchCommandsSetMtgB3000(String messageJson) {
    final parsed = (jsonDecode(messageJson) as Map).cast<String, Object?>();
    final alarms =
        (parsed['value'] as List?)?.cast<Map<String, Object?>>() ??
        <Map<String, Object?>>[];

    final alarmCasio0 = alarmsInst.fromJsonAlarmFirstAlarm(alarms[0]);
    return <BleAction>[
      WriteAction(handle: 0x000E, data: Uint8List.fromList(alarmCasio0)),
    ];
  }

  static List<Map<String, Object?>> parsePacket(Uint8List data) {
    final decodedFull = alarmDecoder.toJson(Bytes.toHexString(data));
    return decodedFull['ALARMS'] ?? <Map<String, Object?>>[];
  }
}

/// Imperative shell managing alarm IO and shared state.
/// @nodoc
class AlarmsIO {
  AlarmsIO._();

  static CancelableResult<List<Map<String, Object?>>>? result;
  static ConnectionProtocol? connection;

  static Future<List<Map<String, Object?>>> request(
    ConnectionProtocol connection,
  ) async {
    AlarmsIO.connection = connection;
    alarmsInst.clear();
    final pending = CancelableResult<List<Map<String, Object?>>>();
    AlarmsIO.result = pending;
    try {
      await connection.sendMessage('{ "action": "GET_ALARMS"}');
      return await pending.getResult();
    } finally {
      if (identical(AlarmsIO.result, pending)) {
        AlarmsIO.result = null;
      }
    }
  }

  static Future<void> sendToWatch([String message = '']) async {
    final conn = AlarmsIO.connection;
    if (conn == null) {
      throw StateError('AlarmsIO.connection is not set');
    }
    final commands = watchInfo.model == WatchModel.mtgB3000
        ? AlarmsIOFunctional.prepareWatchCommandsMtgB3000()
        : AlarmsIOFunctional.prepareWatchCommands();

    for (final command in commands) {
      if (command is WriteAction) {
        final alarmCommand = Bytes.toCompactString(
          Bytes.toHexString(command.data),
        );
        await conn.write(command.handle, alarmCommand);
      }
    }
  }

  static Future<void> sendToWatchSet(String message) async {
    final conn = AlarmsIO.connection;
    if (conn == null) {
      throw StateError('AlarmsIO.connection is not set');
    }
    final commands = watchInfo.model == WatchModel.mtgB3000
        ? AlarmsIOFunctional.prepareWatchCommandsSetMtgB3000(message)
        : AlarmsIOFunctional.prepareWatchCommandsSet(message);

    for (final command in commands) {
      if (command is WriteAction) {
        final alarmCommand = Bytes.toCompactString(
          Bytes.toHexString(command.data),
        );
        await conn.write(command.handle, alarmCommand);
      }
    }
  }

  static void onReceived(Uint8List data) {
    final decodedAlarms = AlarmsIOFunctional.parsePacket(data);
    alarmsInst.addAlarms(decodedAlarms);

    final alarmCountThreshold = watchInfo.alarmCount;
    if (alarmsInst.alarms.length == alarmCountThreshold && result != null) {
      result!.setResult(alarmsInst.alarms);
    }
  }
}
