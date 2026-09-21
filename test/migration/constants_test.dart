import 'package:gshock_api_dart/gshock_api_dart.dart';
import 'package:test/test.dart';

import 'golden/python_reference.dart';

/// Verifies every BLE constant against the Python `casio_constants.py`.
///
/// These constants define the wire protocol; any divergence here means the
/// Dart port cannot talk to (or be tested against) real watches.
void main() {
  group('UUIDs', () {
    test('every Python characteristic UUID matches', () {
      for (final entry in pythonUuids.entries) {
        final dartValue = _dartUuid(entry.key);
        expect(
          dartValue,
          entry.value,
          reason:
              'UUID constant for ${entry.key} diverges from Python: '
              '$dartValue != ${entry.value}',
        );
      }
      expect(pythonUuids.length, 11);
    });

    test('service UUID prefix is 26eb00', () {
      for (final uuid in const [
        CasioConstants.casioReadRequestForAllFeaturesCharacteristicUuid,
        CasioConstants.casioNotificationCharacteristicUuid,
        CasioConstants.casioAllFeaturesCharacteristicUuid,
        CasioConstants.casioDataRequestSpCharacteristicUuid,
        CasioConstants.casioConvoyCharacteristicUuid,
        CasioConstants.casioSetConfigurationCharacteristicUuid,
        CasioConstants.casioGetConfigurationCharacteristicUuid,
      ]) {
        expect(uuid.startsWith('26eb00'), isTrue, reason: uuid);
      }
    });
  });

  group('handles', () {
    test('every Python static handle matches', () {
      final dartHandles = <String, int>{
        'HANDLE_DEVICE_NAME_LEGACY': 0x04,
        'HANDLE_APPEARANCE': 0x06,
        'HANDLE_DEVICE_NAME_GW': 0x07,
        'HANDLE_TX_POWER': 0x09,
        'HANDLE_READ_ALL_FEATURES': 0x0C,
        'HANDLE_ALL_FEATURES_NOTIFICATION': 0x0D,
        'HANDLE_ALL_FEATURES_WRITE': 0x0E,
        'HANDLE_DATA_REQUEST_SP': 0x11,
        'HANDLE_CONVOY_NOTIFICATION': 0x14,
        'HANDLE_SP_NOTIFY': 0x15,
        'HANDLE_SP_REQUEST': 0x17,
        'HANDLE_SP_DATA': 0x19,
      };
      for (final entry in pythonHandles.entries) {
        expect(
          dartHandles[entry.key],
          entry.value,
          reason: 'handle ${entry.key} diverges from Python',
        );
      }
      expect(pythonHandles.length, 12);
    });

    test('handle -> UUID map covers all mapped pairs exactly', () {
      final map = GshockConnection.initHandlesMap();
      // Python's init_handles_map maps exactly these 11 handles.
      expect(map.length, 11);
      expect(
        map[0x0C],
        CasioConstants.casioReadRequestForAllFeaturesCharacteristicUuid,
      );
      expect(map[0x0D], CasioConstants.casioNotificationCharacteristicUuid);
      expect(map[0x0E], CasioConstants.casioAllFeaturesCharacteristicUuid);
      expect(map[0x11], CasioConstants.casioDataRequestSpCharacteristicUuid);
      expect(map[0x14], CasioConstants.casioConvoyCharacteristicUuid);
      expect(map[0x17], CasioConstants.casioSetConfigurationCharacteristicUuid);
      expect(map[0x19], CasioConstants.casioGetConfigurationCharacteristicUuid);
      expect(map[0x04], CasioConstants.casioGetDeviceName);
      expect(map[0x06], CasioConstants.casioAppearance);
      expect(map[0x09], CasioConstants.txPowerLevelCharacteristicUuid);
      expect(map[0xFF], CasioConstants.serialNumberString);
    });

    test('write-without-response handles are {0x0C, 0x0D, 0x14, 0x17}', () {
      expect(GshockConnection.noResponseHandles, <int>{0x0C, 0x0D, 0x14, 0x17});
    });
  });

  group('characteristic codes', () {
    test('every Python CHARACTERISTICS entry matches', () {
      for (final entry in pythonCharacteristics.entries) {
        expect(
          CasioConstants.characteristics[entry.key],
          entry.value,
          reason:
              'characteristic code for ${entry.key} diverges from Python: '
              'got ${CasioConstants.characteristics[entry.key]}, '
              'want ${entry.value}',
        );
      }
      expect(pythonCharacteristics.length, greaterThanOrEqualTo(32));
    });

    test('key characteristic codes from the wire protocol', () {
      final c = CasioConstants.characteristics;
      expect(c['CASIO_WATCH_NAME'], 0x23);
      expect(c['CASIO_APP_INFORMATION'], 0x22);
      expect(c['CASIO_ACTIVITY_RECORD'], 0x26);
      expect(c['CASIO_WATCH_CONDITION'], 0x28);
      expect(c['CASIO_CURRENT_TIME'], 0x09);
      expect(c['CASIO_SETTING_FOR_ALM'], 0x15);
      expect(c['CASIO_SETTING_FOR_ALM2'], 0x16);
      expect(c['CASIO_SETTING_FOR_BASIC'], 0x13);
      expect(c['CASIO_SETTING_FOR_BLE'], 0x11);
      expect(c['CASIO_WORLD_CITIES'], 0x1F);
      expect(c['CASIO_DST_SETTING'], 0x1E);
      expect(c['CASIO_DST_WATCH_STATE'], 0x1D);
      expect(c['CASIO_REMINDER_TITLE'], 0x30);
      expect(c['CASIO_REMINDER_TIME'], 0x31);
      expect(c['CASIO_TIMER'], 0x18);
      expect(c['CASIO_HOME_TIME'], 0x24);
      expect(c['ERROR'], 0xFF);
    });

    test('GW-BX5600 SP headers route to the time IO', () {
      final c = CasioConstants.characteristics;
      expect(c['GW_BX5600_SP_DATA_HEADER_03'], isNotNull);
      expect(c['GW_BX5600_SP_DATA_HEADER_05'], isNotNull);
      expect(c['GW_BX5600_SP_DATA_HEADER_06'], isNotNull);
    });
  });
}

String _dartUuid(String pythonName) {
  switch (pythonName) {
    case 'CASIO_GET_DEVICE_NAME':
      return CasioConstants.casioGetDeviceName;
    case 'CASIO_APPEARANCE':
      return CasioConstants.casioAppearance;
    case 'TX_POWER_LEVEL_CHARACTERISTIC_UUID':
      return CasioConstants.txPowerLevelCharacteristicUuid;
    case 'CASIO_READ_REQUEST_FOR_ALL_FEATURES_CHARACTERISTIC_UUID':
      return CasioConstants.casioReadRequestForAllFeaturesCharacteristicUuid;
    case 'CASIO_ALL_FEATURES_CHARACTERISTIC_UUID':
      return CasioConstants.casioAllFeaturesCharacteristicUuid;
    case 'CASIO_NOTIFICATION_CHARACTERISTIC_UUID':
      return CasioConstants.casioNotificationCharacteristicUuid;
    case 'CASIO_DATA_REQUEST_SP_CHARACTERISTIC_UUID':
      return CasioConstants.casioDataRequestSpCharacteristicUuid;
    case 'CASIO_CONVOY_CHARACTERISTIC_UUID':
      return CasioConstants.casioConvoyCharacteristicUuid;
    case 'CASIO_SET_CONFIGURATION_CHARACTERISTIC_UUID':
      return CasioConstants.casioSetConfigurationCharacteristicUuid;
    case 'CASIO_GET_CONFIGURATION_CHARACTERISTIC_UUID':
      return CasioConstants.casioGetConfigurationCharacteristicUuid;
    case 'SERIAL_NUMBER_STRING':
      return CasioConstants.serialNumberString;
  }
  throw ArgumentError('unknown UUID name: $pythonName');
}
