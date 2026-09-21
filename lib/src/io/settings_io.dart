import 'dart:convert';
import 'dart:typed_data';

import '../io/ble_action.dart';
import '../io/connection_protocol.dart';
import '../io/packet.dart';
import '../model/settings.dart';
import '../model/watch_info.dart';
import '../util/bytes.dart';
import '../util/cancelable_result.dart';
import '../util/logger.dart';

/// Pure functional settings codec.
class SettingsIOFunctional {
  SettingsIOFunctional._();

  static const Map<String, int> _languageIndex = <String, int>{
    'English': 0,
    'Spanish': 1,
    'French': 2,
    'German': 3,
    'Italian': 4,
    'Russian': 5,
  };

  static const List<String> _languages = <String>[
    'English',
    'Spanish',
    'French',
    'German',
    'Italian',
    'Russian',
  ];

  static Uint8List encode(Map<String, Object?> settingsDict) {
    const mask24Hours = 0x01;
    const maskButtonToneOff = 0x02;
    const maskLightOff = 0x04;
    const powerSavingMode = 0x10;

    final arr = Uint8List(12);
    arr[0] = Protocol.settingForBasic.value;
    if (settingsDict['time_format'] == '24h') arr[1] |= mask24Hours;
    if (settingsDict['button_tone'] != true) arr[1] |= maskButtonToneOff;
    if (settingsDict['auto_light'] != true) arr[1] |= maskLightOff;
    if (settingsDict['power_saving_mode'] != true) arr[1] |= powerSavingMode;

    final longDuration = watchInfo.longLightDuration.isNotEmpty
        ? watchInfo.longLightDuration
        : '4s';
    if (settingsDict['light_duration'] == longDuration) arr[2] = 1;
    if (settingsDict['date_format'] == 'DD:MM') arr[4] = 1;
    arr[5] = _languageIndex[settingsDict['language']] ?? 0;

    return arr;
  }

  static Uint8List encodeMtgB3000(Map<String, Object?> settingsDict) {
    const mask24Hours = 0x01;
    const maskButtonToneOff = 0x02;
    const powerSavingModeOff = 0x10;

    final arr = Uint8List(12);
    arr[0] = Protocol.settingForBasic.value;
    arr[1] |= mask24Hours;
    if (settingsDict['button_tone'] != true) arr[1] |= maskButtonToneOff;
    if (settingsDict['power_saving_mode'] != true) {
      arr[1] |= powerSavingModeOff;
    }

    final longDuration = watchInfo.longLightDuration.isNotEmpty
        ? watchInfo.longLightDuration
        : '4s';
    if (settingsDict['light_duration'] == longDuration) arr[2] = 1;

    return arr;
  }

  static Map<String, Object?> decode(Uint8List settingBytes) {
    const mask24Hours = 0x01;
    const maskButtonToneOff = 0x02;
    const maskLightOff = 0x04;
    const powerSavingMode = 0x10;

    final settingArray = Bytes.toIntArray(Bytes.toHexString(settingBytes));
    final decoded = <String, Object?>{};

    decoded['time_format'] = (settingArray[1] & mask24Hours) != 0
        ? '24h'
        : '12h';
    decoded['button_tone'] = (settingArray[1] & maskButtonToneOff) == 0;
    decoded['auto_light'] = (settingArray[1] & maskLightOff) == 0;
    decoded['power_saving_mode'] = (settingArray[1] & powerSavingMode) == 0;
    decoded['date_format'] = settingArray[4] == 1 ? 'DD:MM' : 'MM:DD';

    if (settingArray[5] >= 0 && settingArray[5] < _languages.length) {
      decoded['language'] = _languages[settingArray[5]];
    } else {
      decoded['language'] = 'English';
    }

    final longDuration = watchInfo.longLightDuration.isNotEmpty
        ? watchInfo.longLightDuration
        : '4s';
    final shortDuration = watchInfo.shortLightDuration.isNotEmpty
        ? watchInfo.shortLightDuration
        : '2s';
    decoded['light_duration'] = settingArray[2] == 1
        ? longDuration
        : shortDuration;
    return decoded;
  }

  static Map<String, Object?> decodeMtgB3000(Uint8List settingBytes) {
    const maskButtonToneOff = 0x02;
    const powerSavingMode = 0x10;

    final settingArray = Bytes.toIntArray(Bytes.toHexString(settingBytes));
    final decoded = <String, Object?>{};
    decoded['button_tone'] = (settingArray[1] & maskButtonToneOff) == 0;
    decoded['power_saving_mode'] = (settingArray[1] & powerSavingMode) == 0;

    final longDuration = watchInfo.longLightDuration.isNotEmpty
        ? watchInfo.longLightDuration
        : '4s';
    final shortDuration = watchInfo.shortLightDuration.isNotEmpty
        ? watchInfo.shortLightDuration
        : '2s';
    decoded['light_duration'] = settingArray[2] == 1
        ? longDuration
        : shortDuration;
    return decoded;
  }

  static List<BleAction> prepareWatchCommands() => <BleAction>[
    WriteAction(
      handle: 0x000C,
      data: Uint8List.fromList(<int>[Protocol.settingForBasic.value]),
    ),
  ];

  static List<BleAction> prepareWatchCommandsSet(String messageJson) {
    final jsonSetting = ((jsonDecode(messageJson) as Map)['value'] as Map)
        .cast<String, Object?>();
    final encodedSetting = encode(jsonSetting);
    return <BleAction>[WriteAction(handle: 0x000E, data: encodedSetting)];
  }

  static List<BleAction> prepareWatchCommandsSetMtgB3000(String messageJson) {
    final jsonSetting = ((jsonDecode(messageJson) as Map)['value'] as Map)
        .cast<String, Object?>();
    final encodedSetting = encodeMtgB3000(jsonSetting);
    return <BleAction>[WriteAction(handle: 0x000E, data: encodedSetting)];
  }
}

/// Stateful wrapper around [SettingsIOFunctional].
class SettingsIO {
  SettingsIO._();

  static CancelableResult<String>? result;
  static ConnectionProtocol? connection;

  static Future<String> request(ConnectionProtocol connection) async {
    SettingsIO.connection = connection;
    final pending = CancelableResult<String>();
    SettingsIO.result = pending;
    try {
      await connection.request(
        Protocol.settingForBasic.value
            .toRadixString(16)
            .padLeft(2, '0')
            .toUpperCase(),
      );
      return await pending.getResult();
    } finally {
      if (identical(SettingsIO.result, pending)) {
        SettingsIO.result = null;
      }
    }
  }

  static Future<void> sendToWatch(String message) async {
    final conn = SettingsIO.connection;
    if (conn == null) {
      throw StateError('SettingsIO.connection is not set');
    }
    for (final command in SettingsIOFunctional.prepareWatchCommands()) {
      if (command is WriteAction) {
        await conn.write(command.handle, command.data);
      }
    }
  }

  static Future<void> sendToWatchSet(String message) async {
    final conn = SettingsIO.connection;
    if (conn == null) {
      throw StateError('SettingsIO.connection is not set');
    }
    final commands = watchInfo.model == WatchModel.mtgB3000
        ? SettingsIOFunctional.prepareWatchCommandsSetMtgB3000(message)
        : SettingsIOFunctional.prepareWatchCommandsSet(message);

    for (final command in commands) {
      if (command is WriteAction) {
        final settingToSet = Bytes.toCompactString(
          Bytes.toHexString(command.data),
        );
        await conn.write(command.handle, settingToSet);
      }
    }
  }

  static void onReceived(Uint8List message) {
    gshockLogger.info(['SettingsIO onReceived: $message']);

    if (watchInfo.model == WatchModel.mtgB3000) {
      final decodedDict = SettingsIOFunctional.decodeMtgB3000(message);
      settings.buttonTone = decodedDict['button_tone'] as bool;
      settings.powerSavingMode = decodedDict['power_saving_mode'] as bool;
      settings.lightDuration = decodedDict['light_duration'] as String;
    } else {
      final decodedDict = SettingsIOFunctional.decode(message);
      settings.timeFormat = decodedDict['time_format'] as String;
      settings.buttonTone = decodedDict['button_tone'] as bool;
      settings.autoLight = decodedDict['auto_light'] as bool;
      settings.powerSavingMode = decodedDict['power_saving_mode'] as bool;
      settings.dateFormat = decodedDict['date_format'] as String;
      settings.language = decodedDict['language'] as String;
      settings.lightDuration = decodedDict['light_duration'] as String;
    }

    if (result == null) {
      gshockLogger.warning(['SettingsIO.result is not set']);
      return;
    }
    result!.setResult(jsonEncode(settings.toJson()));
  }
}
