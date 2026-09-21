import 'dart:typed_data';

import '../io/ble_action.dart';
import '../io/connection_protocol.dart';
import '../io/packet.dart';
import '../util/cancelable_result.dart';
import '../util/logger.dart';

/// Buttons reported by the watch.
enum WatchButton {
  upperLeft(1),
  lowerLeft(2),
  upperRight(3),
  lowerRight(4),
  noButton(5),
  invalid(6),
  find(7);

  const WatchButton(this.value);

  final int value;
}

/// Button indicator codes from the BLE feature payload.
abstract final class _ButtonIndicatorCodes {
  static const int reset = 0;
  static const int leftPress = 1;
  static const int find = 2;
  static const int noButton = 3;
  static const int rightPress = 4;
}

/// Pure functional button-pressed decoder.
class ButtonPressedIOFunctional {
  ButtonPressedIOFunctional._();

  static WatchButton decode(Uint8List dataBytes) {
    const defaultButton = WatchButton.invalid;
    if (dataBytes.length < 19) return defaultButton;

    try {
      final protocol = Protocol.fromValue(dataBytes[0]);
      if (protocol != Protocol.bleFeatures) return defaultButton;

      final buttonIndicator = dataBytes[1 + 7];
      const buttonMap = <int, WatchButton>{
        _ButtonIndicatorCodes.reset: WatchButton.lowerLeft,
        _ButtonIndicatorCodes.leftPress: WatchButton.lowerLeft,
        _ButtonIndicatorCodes.find: WatchButton.find,
        _ButtonIndicatorCodes.noButton: WatchButton.noButton,
        _ButtonIndicatorCodes.rightPress: WatchButton.lowerRight,
      };
      return buttonMap[buttonIndicator] ?? WatchButton.lowerRight;
    } catch (_) {
      return defaultButton;
    }
  }

  static List<BleAction> prepareWatchCommands() => <BleAction>[
    WriteAction(
      handle: 0x000C,
      data: Uint8List.fromList(<int>[Protocol.bleFeatures.value]),
    ),
  ];

  static List<BleAction> prepareWatchCommandsSet(Object data) {
    final dataBytes = data is Uint8List
        ? data
        : Uint8List.fromList('$data'.codeUnits);
    return <BleAction>[WriteAction(handle: 0x000E, data: dataBytes)];
  }
}

/// Stateful wrapper around [ButtonPressedIOFunctional].
class ButtonPressedIO {
  ButtonPressedIO._();

  static CancelableResult<WatchButton>? result;
  static ConnectionProtocol? connection;

  static Future<WatchButton> request(ConnectionProtocol connection) async {
    ButtonPressedIO.connection = connection;
    final pending = CancelableResult<WatchButton>();
    ButtonPressedIO.result = pending;
    try {
      await connection.request(
        Protocol.bleFeatures.value
            .toRadixString(16)
            .padLeft(2, '0')
            .toUpperCase(),
      );
      return await pending.getResult();
    } finally {
      if (identical(ButtonPressedIO.result, pending)) {
        ButtonPressedIO.result = null;
      }
    }
  }

  static Future<void> sendToWatch(ConnectionProtocol connection) async {
    for (final command in ButtonPressedIOFunctional.prepareWatchCommands()) {
      if (command is WriteAction) {
        await connection.write(command.handle, command.data);
      }
    }
  }

  static Future<void> sendToWatchSet(Object data) async {
    final conn = ButtonPressedIO.connection;
    if (conn == null) {
      throw StateError('ButtonPressedIO.connection is not set');
    }
    for (final command in ButtonPressedIOFunctional.prepareWatchCommandsSet(
      data,
    )) {
      if (command is WriteAction) {
        await conn.write(command.handle, command.data);
      }
    }
  }

  static void onReceived(Uint8List data) {
    final button = ButtonPressedIOFunctional.decode(data);
    if (result == null) {
      gshockLogger.warning(['ButtonPressedIO.result is not set']);
      return;
    }
    result!.setResult(button);
  }
}
