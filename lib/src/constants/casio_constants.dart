/// {@category Protocols & Constants}
///
/// Constants defining Casio BLE characteristic UUIDs, static handles, and command codes.
///
/// Casio G-Shock watches utilize fixed 16-bit handles on custom 128-bit UUIDs under
/// the `26eb00xx-b012-49a8-b1f8-394fb2032b0f` base service.
class CasioConstants {
  CasioConstants._();

  // ---------------------------------------------------------------------------
  // BLE Characteristic UUIDs
  // ---------------------------------------------------------------------------

  /// Standard GAP Device Name characteristic UUID.
  static const String casioGetDeviceName =
      '00002a00-0000-1000-8000-00805f9b34fb';

  /// Standard GAP Appearance characteristic UUID.
  static const String casioAppearance = '00002a01-0000-1000-8000-00805f9b34fb';

  /// Standard TX Power Level characteristic UUID.
  static const String txPowerLevelCharacteristicUuid =
      '00002a07-0000-1000-8000-00805f9b34fb';

  /// Characteristic UUID used to initiate read requests for all watch features (`0x0C`).
  static const String casioReadRequestForAllFeaturesCharacteristicUuid =
      '26eb002c-b012-49a8-b1f8-394fb2032b0f';

  /// Characteristic UUID representing all feature operations write endpoint (`0x0E`).
  static const String casioAllFeaturesCharacteristicUuid =
      '26eb002d-b012-49a8-b1f8-394fb2032b0f';

  /// Characteristic UUID for feature notification and indication streams (`0x0D`).
  static const String casioNotificationCharacteristicUuid =
      '26eb0030-b012-49a8-b1f8-394fb2032b0f';

  /// Characteristic UUID for DRSP step counter requests and responses (`0x11`).
  static const String casioDataRequestSpCharacteristicUuid =
      '26eb0023-b012-49a8-b1f8-394fb2032b0f';

  /// Characteristic UUID for Convoy lifelog streaming fragments (`0x14`).
  static const String casioConvoyCharacteristicUuid =
      '26eb0024-b012-49a8-b1f8-394fb2032b0f';

  /// GW-BX5600 SP_REQUEST configuration characteristic UUID (`0x17`).
  static const String casioSetConfigurationCharacteristicUuid =
      '26eb002e-b012-49a8-b1f8-394fb2032b0f';

  /// GW-BX5600 SP_DATA configuration characteristic UUID (`0x19`).
  static const String casioGetConfigurationCharacteristicUuid =
      '26eb002f-b012-49a8-b1f8-394fb2032b0f';

  /// Device serial number string UUID.
  static const String serialNumberString =
      '00002a25-0000-1000-8000-00805f9b34fb';

  // ---------------------------------------------------------------------------
  // Static handles
  // ---------------------------------------------------------------------------

  /// Handle for device name on legacy models (`0x04`).
  static const int handleDeviceNameLegacy = 0x04;

  /// Handle for device appearance (`0x06`).
  static const int handleAppearance = 0x06;

  /// Handle for device name on GW series (`0x07`).
  static const int handleDeviceNameGw = 0x07;

  /// Handle for TX power level (`0x09`).
  static const int handleTxPower = 0x09;

  /// Handle for read requests across all features (`0x0C`, write-without-response).
  static const int handleReadAllFeatures = 0x0C;

  /// Handle for notification stream and app notification writes (`0x0D`, write-without-response).
  static const int handleAllFeaturesNotification = 0x0D;

  /// Handle for all features write requests (`0x0E`, write-with-response).
  static const int handleAllFeaturesWrite = 0x0E;

  /// Handle for DRSP step counter requests (`0x11`).
  static const int handleDataRequestSp = 0x11;

  /// Handle for Convoy lifelog notification fragments (`0x14`, write-without-response).
  static const int handleConvoyNotification = 0x14;

  // GW-BX5600 SP handles
  /// Handle for GW-BX5600 SP notifications (`0x15`).
  static const int handleSpNotify = 0x15;

  /// Handle for GW-BX5600 SP requests (`0x17`, write-without-response).
  static const int handleSpRequest = 0x17;

  /// Handle for GW-BX5600 SP data transactions (`0x19`, write-with-response).
  static const int handleSpData = 0x19;

  // ---------------------------------------------------------------------------
  // Characteristic name -> command/feature code
  // ---------------------------------------------------------------------------

  /// Map of Casio protocol feature names to first-byte command/notification codes.
  static const Map<String, int> characteristics = <String, int>{
    'CASIO_WATCH_NAME': 0x23,
    'CASIO_APP_INFORMATION': 0x22,
    'CASIO_BLE_FEATURES': 0x10,
    'CASIO_SETTING_FOR_BLE': 0x11,
    'CASIO_ADVERTISE_PARAMETER_MANAGER': 0x3B,
    'CASIO_CONNECTION_PARAMETER_MANAGER': 0x3A,
    'CASIO_ACTIVITY_RECORD': 0x26,
    'CASIO_WATCH_CONDITION': 0x28, // battery %
    'CASIO_VERSION_INFORMATION': 0x20,
    'CASIO_DST_WATCH_STATE': 0x1D,
    'CASIO_DST_SETTING': 0x1E,
    'CASIO_SERVICE_DISCOVERY_MANAGER': 0x47,
    'CASIO_CURRENT_TIME': 0x09,
    'CASIO_SETTING_FOR_USER_PROFILE': 0x45,
    'CASIO_SETTING_FOR_TARGET_VALUE': 0x43,
    'ALERT_LEVEL': 0x0A,
    'CASIO_SETTING_FOR_ALM': 0x15,
    'CASIO_SETTING_FOR_ALM2': 0x16,
    'CASIO_SETTING_FOR_BASIC': 0x13,
    'CASIO_CURRENT_TIME_MANAGER': 0x39,
    'CASIO_WORLD_CITIES': 0x1F,
    'CASIO_REMINDER_TITLE': 0x30,
    'CASIO_REMINDER_TIME': 0x31,
    'CASIO_TIMER': 0x18,
    'ERROR': 0xFF,
    'UNKNOWN': 0x0A,

    // ECB-30
    'CMD_SET_TIMEMODE': 0x47,
    'FIND_PHONE': 0x0A,

    // GW-BX5600 SP_DATA notification headers
    'GW_BX5600_SP_DATA_HEADER_03': 0x03,
    'GW_BX5600_SP_DATA_HEADER_05': 0x05,
    'GW_BX5600_SP_DATA_HEADER_06': 0x06,

    'CASIO_HOME_TIME': 0x24,
  };
}
