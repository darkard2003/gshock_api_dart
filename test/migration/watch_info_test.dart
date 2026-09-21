import 'package:gshock_api_dart/gshock_api_dart.dart';
import 'package:test/test.dart';

import 'golden/python_reference.dart';
import 'helpers.dart';

/// Verifies the complete watch-model registry against the Python
/// `watch_info.py`: all 140 exact model names, and the full capability /
/// protocol matrix for every [WatchModel].
///
/// `pythonModelCapabilities` lists Python's [WatchModel] members in
/// declaration order; the Dart port declares the same 24 members in the
/// same order, so models are compared by position (verified by the
/// `model enums align by declaration order` test).
void main() {
  setUp(resetMigrationState);
  tearDown(resetMigrationState);

  group('model enum alignment', () {
    test('Dart WatchModel has one member per Python WatchModel, in order', () {
      // ga, gw, dw_b5600, dw, gmw, gpr, gst, msg, gb001, gbd, gbd_800,
      // mrg_b5000, gcw_b5000, eqb, ecb, abl_100, f_b100, dw_h5600,
      // gmw_bz5000, gw_bx5600, mtg_b1000, mtg_b3000, generic, unknown.
      expect(pythonModelCapabilities.length, 24);
      expect(WatchModel.values.length, 24);
      // Spot-check positional alignment at both ends of the enum.
      expect(_pythonNameOf(WatchModel.values.first), 'GA');
      expect(_pythonNameOf(WatchModel.values[2]), 'DW_B5600');
      expect(_pythonNameOf(WatchModel.values[19]), 'GW_BX5600');
      expect(_pythonNameOf(WatchModel.values[20]), 'MTG_B1000');
      expect(_pythonNameOf(WatchModel.values[21]), 'MTG_B3000');
      expect(_pythonNameOf(WatchModel.values[23]), 'UNKNOWN');
    });
  });

  group('EXACT_MODEL_MAP', () {
    test('all 140 exact entries match Python (name -> model)', () {
      expect(exactModelMap.length, pythonExactModelMap.length);
      for (final entry in pythonExactModelMap.entries) {
        final dartModel = exactModelMap[entry.key];
        expect(
          dartModel,
          isNotNull,
          reason: 'watch name ${entry.key} missing from Dart EXACT_MODEL_MAP',
        );
        expect(
          _pythonNameOf(dartModel!),
          entry.value,
          reason:
              '${entry.key}: Dart resolves to ${_pythonNameOf(dartModel)}, '
              'Python resolves to ${entry.value}',
        );
      }
    });

    test('specific prefixes before generic (guardrail ordering)', () {
      // Exact-map hits must never fall through to the generic GW/MTG prefix
      // fallbacks (the model-prefix-ordering guardrail).
      expect(exactModelMap['GW-BX5600'], WatchModel.gwBx5600);
      expect(exactModelMap['MTG-B1000'], WatchModel.mtgB1000);
      expect(exactModelMap['MTG-B3000'], WatchModel.mtgB3000);
      expect(exactModelMap['GMW-BZ5000'], WatchModel.gmwBz5000);
      expect(exactModelMap['DW-H5600'], WatchModel.dwH5600);
      expect(exactModelMap['ABL-100WE'], WatchModel.abl100);
      expect(exactModelMap['F-B100W'], WatchModel.fB100);
      expect(exactModelMap['GPR-B1000'], WatchModel.gpr);
      // Same-model entries alias to a shared model (module number families).
      expect(exactModelMap['GMW-B5000'], WatchModel.gmw);
      expect(exactModelMap['GBD-800'], WatchModel.gbd800);
      expect(exactModelMap['GMD-B800'], WatchModel.gbd800);
    });

    test('unmapped names resolve to generic (exact-map lookup only)', () {
      // Python `resolve_model` is a pure exact-map lookup; anything not in
      // EXACT_MODEL_MAP falls back to GENERIC (no prefix matching).
      watchInfo.setNameAndModel('CASIO GW-S5600');
      expect(watchInfo.model, WatchModel.generic);
      watchInfo.setNameAndModel('CASIO DW-B5600');
      expect(
        watchInfo.model,
        WatchModel.dwB5600,
      ); // DW-B5600 is in the exact map
      watchInfo.setNameAndModel('CASIO UNKNOWN-XYZ');
      expect(watchInfo.model, WatchModel.generic);
    });
  });

  group('capability matrix', () {
    test('every WatchModel matches Python capabilities', () {
      for (final modelEntry in pythonModelCapabilities.entries) {
        final model = _modelByPythonName(modelEntry.key);
        final expected = modelEntry.value;

        _setModel(model);

        // Protocol selection.
        final protocolName = watchInfo.protocol.runtimeType.toString();
        expect(
          protocolName,
          expected['protocol'] as String,
          reason:
              '${modelEntry.key}: protocol $protocolName != '
              '${expected['protocol']}',
        );

        // Every capability field ('model' is the enum identity itself and
        // 'protocol' is checked above).
        for (final field in expected.keys) {
          if (field == 'protocol' || field == 'model') continue;
          final dartValue = _capability(field);
          final pyValue = expected[field];
          expect(
            dartValue,
            pyValue,
            reason: '${modelEntry.key}.$field: Dart=$dartValue Python=$pyValue',
          );
        }
      }
    });

    test('capability gates on representative models', () {
      // GW-BX5600: MIP protocol with the new SP time format.
      _setModel(WatchModel.gwBx5600);
      expect(watchInfo.hasNewTimeFormat, isTrue);
      expect(watchInfo.protocol, isA<MipProtocol>());

      // MTG-B1000: analogue with second dial.
      _setModel(WatchModel.mtgB1000);
      expect(watchInfo.hasSecondDial, isTrue);
      expect(watchInfo.protocol, isA<AnalogueProtocol>());

      // MTG-B3000: analogue with 12-byte settings and a second dial too
      // (Python ModelInfo: hasSecondDial=True for MTG-B3000).
      _setModel(WatchModel.mtgB3000);
      expect(watchInfo.settingsSize, 12);
      expect(watchInfo.hasSecondDial, isTrue);
      expect(watchInfo.protocol, isA<AnalogueProtocol>());

      // DW-H5600: always connected / health functions (hasStepCounter=false in Python).
      _setModel(WatchModel.dwH5600);
      expect(watchInfo.alwaysConnected, isTrue);
      expect(watchInfo.hasStepCounter, isFalse);

      // ABL-100WE: step counter.
      _setModel(WatchModel.abl100);
      expect(watchInfo.hasStepCounter, isTrue);

      // Generic GW: standard protocol, 6 world cities.
      _setModel(WatchModel.gw);
      expect(watchInfo.worldCitiesCount, 6);
      expect(watchInfo.protocol, isA<StandardProtocol>());
    });

    test('reset clears all capability state (no leaks across watches)', () {
      _setModel(WatchModel.mtgB1000);
      expect(watchInfo.hasSecondDial, isTrue);

      watchInfo.reset();
      expect(watchInfo.model, WatchModel.generic);
      expect(watchInfo.name, isEmpty);
      expect(watchInfo.address, isEmpty);
      expect(watchInfo.protocol, isA<StandardProtocol>());
      expect(watchInfo.hasSecondDial, isFalse);
      expect(watchInfo.hasStepCounter, isFalse);
      expect(watchInfo.hasNewTimeFormat, isFalse);
    });

    test('setNameAndModel also derives name and short name', () {
      watchInfo.setNameAndModel('CASIO MTG-B3000');
      expect(watchInfo.name, 'CASIO MTG-B3000');
      expect(watchInfo.shortName, isNotEmpty);
      expect(watchInfo.model, WatchModel.mtgB3000);
    });
  });

  group('lookupWatchInfo', () {
    test('returns the same capability dict Python produces', () {
      watchInfo.setNameAndModel('CASIO GW-BX5600');
      final lookup = watchInfo.lookupWatchInfo('CASIO GW-BX5600');
      expect(lookup['model'], WatchModel.gwBx5600);
      expect(lookup['alwaysConnected'], isFalse);
      expect(lookup['hasNewTimeFormat'], isTrue);
      expect(lookup['hasSecondDial'], isFalse);
      expect(lookup['hasStepCounter'], isFalse);

      final dwLookup = watchInfo.lookupWatchInfo('CASIO DW-H5600');
      expect(dwLookup['model'], WatchModel.dwH5600);
      expect(dwLookup['alwaysConnected'], isTrue);
      expect(dwLookup['hasStepCounter'], isFalse);
    });
  });
}

/// Sets the active model the same way Python's WatchInfo does: assigning
/// `.model` alone does NOT re-resolve `info`; `set_name_and_model` does.
/// Tests use this helper to mirror a full model switch.
void _setModel(WatchModel model) {
  watchInfo.model = model;
  watchInfo.info = resolveModelInfo(model);
}

/// Maps a Dart [WatchModel] to the Python enum name using declaration order.
String _pythonNameOf(WatchModel model) =>
    pythonModelCapabilities.keys.elementAt(model.index);

WatchModel _modelByPythonName(String pythonName) {
  final index = pythonModelCapabilities.keys.toList().indexOf(pythonName);
  if (index < 0) {
    throw ArgumentError('no Python WatchModel named $pythonName');
  }
  return WatchModel.values[index];
}

Object? _capability(String pythonFieldName) {
  switch (pythonFieldName) {
    case 'worldCitiesCount':
      return watchInfo.worldCitiesCount;
    case 'dstCount':
      return watchInfo.dstCount;
    case 'alarmCount':
      return watchInfo.alarmCount;
    case 'hasAutoLight':
      return watchInfo.hasAutoLight;
    case 'hasReminders':
      return watchInfo.hasReminders;
    case 'shortLightDuration':
      return watchInfo.shortLightDuration;
    case 'longLightDuration':
      return watchInfo.longLightDuration;
    case 'weekLanguageSupported':
      return watchInfo.weekLanguageSupported;
    case 'hasBatteryLevel':
      return watchInfo.hasBatteryLevel;
    case 'hasTemperature':
      return watchInfo.hasTemperature;
    case 'batteryLevelLowerLimit':
      return watchInfo.batteryLevelLowerLimit;
    case 'batteryLevelUpperLimit':
      return watchInfo.batteryLevelUpperLimit;
    case 'alwaysConnected':
      return watchInfo.alwaysConnected;
    case 'findButtonUserDefined':
      return watchInfo.findButtonUserDefined;
    case 'hasPowerSavingMode':
      return watchInfo.hasPowerSavingMode;
    case 'chimeInSettings':
      return watchInfo.chimeInSettings;
    case 'vibrate':
      return watchInfo.vibrate;
    case 'hasHealthFunctions':
      return watchInfo.hasHealthFunctions;
    case 'hasMessages':
      return watchInfo.hasMessages;
    case 'hasDateFormat':
      return watchInfo.hasDateFormat;
    case 'hasWorldCities':
      return watchInfo.hasWorldCities;
    case 'hasHomeTime':
      return watchInfo.hasHomeTime;
    case 'hasMultipleFonts':
      return watchInfo.hasMultipleFonts;
    case 'hasStepCounter':
      return watchInfo.hasStepCounter;
    case 'hasStepCounterMock':
      return watchInfo.hasStepCounterMock;
    case 'hasNewTimeFormat':
      return watchInfo.hasNewTimeFormat;
    case 'hasTimeAdjustment':
      return watchInfo.hasTimeAdjustment;
    case 'hasSecondDial':
      return watchInfo.hasSecondDial;
    case 'hasFineWatchCondition':
      return watchInfo.hasFineWatchCondition;
    case 'hasTimeFormat':
      return watchInfo.hasTimeFormat;
    case 'hasHourlyChime':
      return watchInfo.hasHourlyChime;
    case 'hasLongTimerKey':
      return watchInfo.hasLongTimerKey;
    case 'settingsSize':
      return watchInfo.settingsSize;
    case 'hasAppInfo':
      return watchInfo.hasAppInfo;
  }
  throw ArgumentError('unmapped capability field: $pythonFieldName');
}
