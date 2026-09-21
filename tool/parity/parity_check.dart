import 'dart:io';
import 'dart:typed_data';

import 'package:gshock_api_dart/gshock_api_dart.dart';

void main() {
  stdout.writeln('====================================================');
  stdout.writeln('G-Shock API Python <-> Dart Parity Validation Check');
  stdout.writeln('====================================================\n');

  var passed = 0;
  var total = 0;

  void check(String name, bool Function() fn) {
    total++;
    try {
      if (fn()) {
        stdout.writeln('  [PASS] $name');
        passed++;
      } else {
        stderr.writeln('  [FAIL] $name');
      }
    } catch (e) {
      stderr.writeln('  [ERROR] $name: $e');
    }
  }

  // 1. Time encoding
  check('TimeEncoderPure byte-for-byte deterministic encoding', () {
    final dt = DateTime(2026, 5, 30, 8, 45, 30, 123, 456);
    final encoded = TimeEncoderPure.encodeCurrentTime(dt);
    return encoded.length == 10 &&
        encoded[0] == 0xEA &&
        encoded[1] == 0x07 &&
        encoded[2] == 5 &&
        encoded[3] == 30 &&
        encoded[4] == 8 &&
        encoded[5] == 45 &&
        encoded[6] == 30 &&
        encoded[7] == 5 &&
        encoded[9] == 1;
  });

  // 2. Settings encoding
  check('SettingsIOFunctional 12-byte payload with 0x13 header', () {
    watchInfo.setNameAndModel('CASIO GW-B5600');
    final settings = <String, Object?>{
      'time_format': '24h',
      'button_tone': true,
      'auto_light': false,
      'power_saving_mode': true,
      'light_duration': '4s',
      'date_format': 'DD:MM',
      'language': 'French',
    };
    final encoded = SettingsIOFunctional.encode(settings);
    final decoded = SettingsIOFunctional.decode(encoded);
    watchInfo.reset();
    return encoded.length == 12 &&
        encoded[0] == 0x13 &&
        decoded['time_format'] == '24h' &&
        decoded['language'] == 'French';
  });

  // 3. Timer encoding
  check('TimerIOFunctional 3665s encode / decode', () {
    const seconds = 3665;
    final encoded = TimerIOFunctional.encode(seconds);
    final decoded = TimerIOFunctional.decode(encoded);
    return encoded[0] == 0x18 &&
        encoded[1] == 1 &&
        encoded[2] == 1 &&
        encoded[3] == 5 &&
        decoded == seconds;
  });

  // 4. MTG-B3000 Timer encoding
  check('TimerIOFunctional MTG-B3000 15-byte frame', () {
    final encoded = TimerIOFunctional.encodeMtgB3000(600);
    return encoded.length == 15 && encoded[0] == 0x18 && encoded[2] == 10;
  });

  // 5. WatchModel resolution
  check('WatchInfo EXACT_MODEL_MAP protocol & capability resolution', () {
    watchInfo.setNameAndModel('CASIO GW-BX5600');
    final m1 =
        watchInfo.model == WatchModel.gwBx5600 &&
        watchInfo.hasNewTimeFormat &&
        watchInfo.protocol is MipProtocol;

    watchInfo.setNameAndModel('CASIO MTG-B1000');
    final m2 =
        watchInfo.model == WatchModel.mtgB1000 &&
        watchInfo.hasSecondDial &&
        watchInfo.protocol is AnalogueProtocol;

    watchInfo.setNameAndModel('CASIO ABL-100WE');
    final m3 = watchInfo.model == WatchModel.abl100 && watchInfo.hasStepCounter;

    watchInfo.setNameAndModel('CASIO DW-H5600');
    final m4 =
        watchInfo.model == WatchModel.dwH5600 && !watchInfo.hasStepCounter;

    watchInfo.reset();
    return m1 && m2 && m3 && m4;
  });

  // 6. Timezone coordinates
  check('CasioTimeZoneHelper coordinate accuracy', () {
    final coords = CasioTimeZoneHelper.getWorldCityCoordinates('Europe/Madrid');
    return coords.exact &&
        (coords.lat - 41.4548).abs() < 0.001 &&
        (coords.lon - 2.2502).abs() < 0.001;
  });

  // 7. Step counter lifelog parsing
  check('StepCounterIOFunctional 400-byte fixture parsing', () {
    final payload = Uint8List(400);
    payload[0] = 0x26;
    payload[1] = 1;
    payload[2] = 8;
    payload[3] = 17;
    payload[374] = 0x39;
    payload[375] = 0x30; // 12345

    final parsed = StepCounterIOFunctional.parse(payload);
    return parsed != null &&
        parsed.currentDaySteps == 12345 &&
        parsed.month == 1 &&
        parsed.dayOfMonth == 8 &&
        parsed.dayOfWeek == 3;
  });

  // 8. App notification XOR cipher
  check('AppNotificationIO XOR-255 encryption self-inverse', () {
    final original = Uint8List.fromList([0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC]);
    final encryptedHex = AppNotificationIO.xorEncodeBuffer(original);
    final decrypted = AppNotificationIO.xorDecodeBuffer(encryptedHex);
    return decrypted.length == original.length &&
        decrypted[0] == original[0] &&
        decrypted[5] == original[5];
  });

  stdout.writeln('\nParity Validation Result: $passed / $total checks passed.');
  if (passed != total) {
    exitCode = 1;
  }
}
