import '../protocols/analogue_protocol.dart';
import '../protocols/mip_protocol.dart';
import '../protocols/standard_protocol.dart';
import '../protocols/watch_protocol.dart';

/// Watch model families. Mirrors `WatchModel` in `watch_info.py`.
enum WatchModel {
  ga,
  gw,
  dwB5600,
  dw,
  gmw,
  gpr,
  gst,
  msg,
  gb001,
  gbd,
  gbd800,
  mrgB5000,
  gcwB5000,
  eqb,
  ecb,
  abl100,
  fB100,
  dwH5600,
  gmwBz5000,
  gwBx5600,
  mtgB1000,
  mtgB3000,
  generic,
  unknown, // legacy fallback alias for generic
}

/// Protocol singletons used as `ModelInfo` defaults.
final WatchProtocol standardProtocol = StandardProtocol();
final WatchProtocol mipProtocol = MipProtocol();
final WatchProtocol analogueProtocol = AnalogueProtocol();

/// Per-model capabilities. Mirrors the `ModelInfo` dataclass.
class ModelInfo {
  ModelInfo({
    required this.model,
    this.worldCitiesCount = 2,
    this.dstCount = 1,
    this.alarmCount = 5,
    this.hasAutoLight = false,
    this.hasReminders = false,
    this.shortLightDuration = '1.5s',
    this.longLightDuration = '3s',
    this.weekLanguageSupported = true,
    this.hasBatteryLevel = true,
    this.hasTemperature = true,
    this.batteryLevelLowerLimit = 9,
    this.batteryLevelUpperLimit = 19,
    this.alwaysConnected = false,
    this.findButtonUserDefined = false,
    this.hasPowerSavingMode = true,
    this.chimeInSettings = false,
    this.vibrate = false,
    this.hasHealthFunctions = false,
    this.hasMessages = false,
    this.hasDateFormat = true,
    this.hasWorldCities = true,
    this.hasHomeTime = true,
    this.hasMultipleFonts = false,
    this.hasStepCounter = false,
    this.hasStepCounterMock = false,
    this.hasNewTimeFormat = false,
    this.hasTimeAdjustment = true,
    this.hasSecondDial = false,
    this.hasFineWatchCondition = false,
    this.hasTimeFormat = true,
    this.hasHourlyChime = true,
    this.hasLongTimerKey = false,
    this.settingsSize = 17,
    this.hasAppInfo = true,
    WatchProtocol? protocol,
  }) : protocol = protocol ?? standardProtocol;

  final WatchModel model;
  int worldCitiesCount;
  int dstCount;
  int alarmCount;
  bool hasAutoLight;
  bool hasReminders;
  String shortLightDuration;
  String longLightDuration;
  bool weekLanguageSupported;
  bool hasBatteryLevel;
  bool hasTemperature;
  int batteryLevelLowerLimit;
  int batteryLevelUpperLimit;
  bool alwaysConnected;
  bool findButtonUserDefined;
  bool hasPowerSavingMode;
  bool chimeInSettings;
  bool vibrate;
  bool hasHealthFunctions;
  bool hasMessages;
  bool hasDateFormat;
  bool hasWorldCities;
  bool hasHomeTime;
  bool hasMultipleFonts;
  bool hasStepCounter;
  bool hasStepCounterMock;
  bool hasNewTimeFormat;
  bool hasTimeAdjustment;
  bool hasSecondDial;
  bool hasFineWatchCondition;
  bool hasTimeFormat;
  bool hasHourlyChime;
  bool hasLongTimerKey;
  int settingsSize;
  bool hasAppInfo;
  WatchProtocol protocol;
}

final List<ModelInfo> _modelList = <ModelInfo>[
  ModelInfo(
    model: WatchModel.gw,
    worldCitiesCount: 6,
    dstCount: 3,
    hasAutoLight: true,
    hasReminders: true,
    shortLightDuration: '2s',
    longLightDuration: '4s',
    batteryLevelLowerLimit: 9,
    batteryLevelUpperLimit: 19,
    hasStepCounterMock: false,
  ),
  ModelInfo(
    model: WatchModel.dwB5600,
    worldCitiesCount: 6,
    dstCount: 3,
    hasAutoLight: false,
    hasReminders: true,
    shortLightDuration: '2s',
    longLightDuration: '4s',
    batteryLevelLowerLimit: 9,
    batteryLevelUpperLimit: 19,
  ),
  ModelInfo(
    model: WatchModel.gmwBz5000,
    worldCitiesCount: 6,
    dstCount: 3,
    hasAutoLight: true,
    hasReminders: false,
    shortLightDuration: '1.5s',
    longLightDuration: '3s',
    batteryLevelLowerLimit: 9,
    batteryLevelUpperLimit: 19,
    hasMultipleFonts: true,
  ),
  ModelInfo(
    model: WatchModel.gwBx5600,
    worldCitiesCount: 6,
    dstCount: 3,
    hasAutoLight: true,
    hasReminders: false,
    shortLightDuration: '1.5s',
    longLightDuration: '3s',
    batteryLevelLowerLimit: 14,
    batteryLevelUpperLimit: 24,
    hasMultipleFonts: true,
    hasNewTimeFormat: true,
    protocol: mipProtocol,
  ),
  ModelInfo(
    model: WatchModel.mtgB1000,
    worldCitiesCount: 6,
    dstCount: 3,
    alarmCount: 1,
    hasAutoLight: true,
    hasReminders: true,
    shortLightDuration: '2s',
    longLightDuration: '4s',
    batteryLevelLowerLimit: 9,
    batteryLevelUpperLimit: 19,
    hasSecondDial: true,
    hasFineWatchCondition: true,
    hasHourlyChime: false,
    protocol: analogueProtocol,
  ),
  ModelInfo(
    model: WatchModel.mtgB3000,
    worldCitiesCount: 2,
    dstCount: 1,
    alarmCount: 1,
    hasAutoLight: false,
    hasReminders: false,
    shortLightDuration: '1.5s',
    longLightDuration: '3s',
    hasHomeTime: true,
    hasDateFormat: false,
    weekLanguageSupported: false,
    hasTimeFormat: false,
    settingsSize: 12,
    batteryLevelLowerLimit: 0,
    batteryLevelUpperLimit: 100,
    hasSecondDial: true,
    hasFineWatchCondition: true,
    hasPowerSavingMode: false,
    hasHourlyChime: false,
    hasLongTimerKey: true,
    protocol: analogueProtocol,
  ),
  ModelInfo(
    model: WatchModel.mrgB5000,
    worldCitiesCount: 6,
    dstCount: 3,
    hasAutoLight: true,
    hasReminders: true,
    shortLightDuration: '2s',
    longLightDuration: '4s',
    batteryLevelLowerLimit: 9,
    batteryLevelUpperLimit: 19,
  ),
  ModelInfo(
    model: WatchModel.gcwB5000,
    worldCitiesCount: 6,
    dstCount: 3,
    hasAutoLight: true,
    hasReminders: true,
    shortLightDuration: '2s',
    longLightDuration: '4s',
    batteryLevelLowerLimit: 9,
    batteryLevelUpperLimit: 19,
  ),
  ModelInfo(
    model: WatchModel.gmw,
    worldCitiesCount: 6,
    dstCount: 3,
    hasAutoLight: true,
    hasReminders: true,
    shortLightDuration: '2s',
    longLightDuration: '4s',
    batteryLevelLowerLimit: 9,
    batteryLevelUpperLimit: 19,
  ),
  ModelInfo(model: WatchModel.gst, hasAutoLight: false, hasReminders: true),
  ModelInfo(
    model: WatchModel.abl100,
    hasAutoLight: false,
    hasReminders: false,
    hasTemperature: false,
    hasBatteryLevel: false,
    hasWorldCities: false,
    hasHomeTime: false,
    hasStepCounter: true,
    hasDateFormat: false,
    weekLanguageSupported: false,
    hasAppInfo: true,
  ),
  ModelInfo(
    model: WatchModel.fB100,
    hasAutoLight: false,
    hasReminders: false,
    hasTemperature: false,
    hasBatteryLevel: false,
    hasWorldCities: false,
    hasHomeTime: false,
    hasStepCounter: true,
    hasDateFormat: false,
    weekLanguageSupported: false,
    hasAppInfo: true,
  ),
  ModelInfo(model: WatchModel.ga, hasAutoLight: false, hasReminders: true),
  ModelInfo(model: WatchModel.gb001, hasAutoLight: true, hasReminders: false),
  ModelInfo(model: WatchModel.msg, hasAutoLight: false, hasReminders: true),
  ModelInfo(
    model: WatchModel.gpr,
    hasAutoLight: true,
    hasReminders: false,
    weekLanguageSupported: false,
  ),
  ModelInfo(
    model: WatchModel.dwH5600,
    alarmCount: 4,
    hasAutoLight: true,
    hasReminders: false,
    vibrate: true,
    chimeInSettings: true,
    findButtonUserDefined: true,
    shortLightDuration: '1.5s',
    longLightDuration: '5s',
    hasBatteryLevel: false,
    alwaysConnected: true,
    hasDateFormat: false,
    weekLanguageSupported: false,
    hasStepCounter: false,
  ),
  ModelInfo(model: WatchModel.dw, hasAutoLight: true, hasReminders: false),
  ModelInfo(
    model: WatchModel.gbd,
    hasAutoLight: true,
    hasReminders: false,
    hasWorldCities: false,
    hasTemperature: false,
  ),
  ModelInfo(
    model: WatchModel.gbd800,
    hasAutoLight: true,
    hasReminders: false,
    hasTemperature: false,
    hasBatteryLevel: false,
    hasWorldCities: false,
    hasHomeTime: false,
  ),
  ModelInfo(
    model: WatchModel.eqb,
    hasAutoLight: true,
    hasReminders: false,
    hasWorldCities: false,
    hasTemperature: false,
  ),
  ModelInfo(
    model: WatchModel.ecb,
    hasAutoLight: true,
    hasReminders: false,
    hasTemperature: false,
    hasBatteryLevel: false,
    alwaysConnected: true,
    findButtonUserDefined: true,
    hasPowerSavingMode: false,
  ),
  ModelInfo(model: WatchModel.generic),
];

final Map<WatchModel, ModelInfo> _modelMap = {
  for (final info in _modelList) info.model: info,
};

/// Exact official Casio model map. Mirrors `EXACT_MODEL_MAP` in Python.
const Map<String, WatchModel> exactModelMap = <String, WatchModel>{
  // Module 3452: GPR-B1000
  'GPR-B1000': WatchModel.gpr,
  // Module 3459: GMW-B5000, GW-B5000
  'GMW-B5000': WatchModel.gmw,
  'GW-B5000': WatchModel.gw,
  // Module 3461: GW-B5600, MRG-B5000
  'GW-B5600': WatchModel.gw,
  'MRG-B5000': WatchModel.gw,
  // Module 3464: GBD-800, GMD-B800
  'GBD-800': WatchModel.gbd800,
  'GMD-B800': WatchModel.gbd800,
  // Module 3475: GBD-H1000
  'GBD-H1000': WatchModel.gbd,
  // Module 3481: GBD-100
  'GBD-100': WatchModel.gbd,
  // Module 3482: GBX-100
  'GBX-100': WatchModel.gbd,
  // Module 3491: GSR-H1000
  'GSR-H1000': WatchModel.generic,
  // Module 3506: GBD-200
  'GBD-200': WatchModel.gbd,
  // Module 3509: DW-B5600
  'DW-B5600': WatchModel.dwB5600,
  // Module 3515: GBD-H2000, DW-GH5600
  'GBD-H2000': WatchModel.dwH5600,
  'DW-GH5600': WatchModel.dwH5600,
  // Module 3516: DW-H5600
  'DW-H5600': WatchModel.dwH5600,
  // Module 3539
  'GMW-B5000#': WatchModel.gcwB5000,
  'GW-B5600#': WatchModel.gcwB5000,
  'MRG-B5000#': WatchModel.gcwB5000,
  'TRN-50': WatchModel.gcwB5000,
  'GCW-B5000': WatchModel.gcwB5000,
  'PRJ-BW002': WatchModel.gcwB5000,
  // Module 3552 / 3520: GD-B500
  'GD-B500': WatchModel.generic,
  // Module 3554: GPR-H1000
  'GPR-H1000': WatchModel.gpr,
  // Module 3565: ABL-100WE
  'ABL-100WE': WatchModel.abl100,
  'ABL-100': WatchModel.abl100,
  // Module 3568: GBD-300
  'GBD-300': WatchModel.gbd,
  // Module 3575: GMW-BZ5000
  'GMW-BZ5000': WatchModel.gmwBz5000,
  // Module 3577: GM-H5600
  'GM-H5600': WatchModel.dwH5600,
  // Module 3586: GBX-H5600
  'GBX-H5600': WatchModel.gbd,
  // Module 3587: GDG-B100
  'GDG-B100': WatchModel.gbd,
  // Module 3599: GWF-300
  'GWF-300': WatchModel.generic,
  // Module 5537: ECB-800
  'ECB-800': WatchModel.ecb,
  // Module 5554: GBA-800
  'GBA-800': WatchModel.ga,
  // Module 5582: ECB-900, ECB-950, GST-B200, GST-B300
  'ECB-900': WatchModel.gst,
  'ECB-950': WatchModel.gst,
  'GST-B200': WatchModel.gst,
  'GST-B300': WatchModel.gst,
  // Module 5588: GWR-B1000
  'GWR-B1000': WatchModel.gw,
  // Module 5594: GMC-B100
  'GMC-B100': WatchModel.generic,
  // Module 5597: OCW-B1300
  'OCW-B1300': WatchModel.generic,
  // Module 5602: PRT-B70
  'PRT-B70': WatchModel.generic,
  // Module 5603: OCW-S5000
  'OCW-S5000': WatchModel.generic,
  // Module 5604: EQB-1000
  'EQB-1000': WatchModel.eqb,
  // Module 5618: ECB-10
  'ECB-10': WatchModel.ecb,
  // Module 5623: GWF-A1000
  'GWF-A1000': WatchModel.generic,
  // Module 5624: OCW-P2000
  'OCW-P2000': WatchModel.generic,
  // Module 5636: MTG-B2000, MRG-BF1000
  'MTG-B2000': WatchModel.generic,
  'MRG-BF1000': WatchModel.generic,
  // Module 5641: GBA-900
  'GBA-900': WatchModel.ga,
  // Module 5657: GST-B400
  'GST-B400': WatchModel.gst,
  // Module 5672: MTG-B3000
  'MTG-B3000': WatchModel.mtgB3000,
  // Module 5701: OCW-S7000
  'OCW-S7000': WatchModel.generic,
  // Module 5713: GWG-B1000
  'GWG-B1000': WatchModel.gw,
  // Module 5728: OCW-S400
  'OCW-S400': WatchModel.generic,
  // Module 5736: GA-B010
  'GA-B010': WatchModel.ga,
  // Module 5737 / 5725: GBA-950
  'GBA-950': WatchModel.ga,
  // Module 5744: GG-B100X
  'GG-B100X': WatchModel.generic,
  // Module 5748 / 5631: GST-B1000
  'GST-B1000': WatchModel.gst,
  // Module 5712: EQB-1300
  'EQB-1300': WatchModel.eqb,
  // Module 5756 / 5775: GWR-B3000
  'GWR-B3000': WatchModel.gw,

  'GB-5600A': WatchModel.ga,
  'GB-6900A': WatchModel.ga,
  'GB-5600B': WatchModel.ga,
  'GB-6900B': WatchModel.ga,
  'GB-X6900B': WatchModel.ga,
  'GBA-400': WatchModel.ga,
  'GA-B2100': WatchModel.ga,
  'GM-B2100': WatchModel.ga,
  'GBM-2100': WatchModel.ga,
  'GA-B001': WatchModel.ga,
  'GST-B100': WatchModel.gst,
  'GST-B500': WatchModel.gst,
  'GST-B600': WatchModel.gst,
  'GST-W1000': WatchModel.gst,
  'MSG-B100': WatchModel.msg,
  'G-B001': WatchModel.gb001,
  'EQB-500': WatchModel.eqb,
  'EQB-510': WatchModel.eqb,
  'EQB-600': WatchModel.eqb,
  'EQB-700': WatchModel.eqb,
  'EQB-501': WatchModel.eqb,
  'EQB-800': WatchModel.eqb,
  'EQB-900': WatchModel.eqb,
  'EQB-1100': WatchModel.eqb,
  'EQB-1200': WatchModel.eqb,
  'EQB-2000': WatchModel.eqb,
  'ECB-500': WatchModel.ecb,
  'ECB-20': WatchModel.ecb,
  'ECB-30': WatchModel.ecb,
  'ECB-40': WatchModel.ecb,
  'ECB-S100': WatchModel.ecb,
  'ECB-2000': WatchModel.ecb,
  'ECB-2300': WatchModel.ecb,
  'ECB-2200': WatchModel.ecb,
  'ECB-S10': WatchModel.ecb,
  'GW-BX5600': WatchModel.gwBx5600,
  'MTG-B1000': WatchModel.mtgB1000,
  'STB-1000': WatchModel.generic,
  'SHB-100': WatchModel.generic,
  'SHB-200': WatchModel.generic,
  'GPW-2000': WatchModel.generic,
  'GPW-G2000': WatchModel.generic,
  'MRG-G2000': WatchModel.generic,
  'OCW-G2000': WatchModel.generic,
  'MRG-B1000': WatchModel.generic,
  'LIW-B1000': WatchModel.generic,
  'OCW-S4000': WatchModel.generic,
  'OCW-T3000': WatchModel.generic,
  'OCW-T4000': WatchModel.generic,
  'OCW-T6000': WatchModel.generic,
  'OCW-T4000A': WatchModel.generic,
  'OCW-T4000B': WatchModel.generic,
  'OCW-T4000C': WatchModel.generic,
  'GR-B300': WatchModel.generic,
  'MRG-B2100': WatchModel.ga,
  'GMC-B2100': WatchModel.ga,
  'OCW-SG1000': WatchModel.generic,
  'MTG-B4000': WatchModel.generic,
  'BSA-B100': WatchModel.generic,
  'GMA-B800': WatchModel.generic,
  'GR-B100': WatchModel.generic,
  'GG-B100': WatchModel.generic,
  'PRT-B50': WatchModel.generic,
  'GR-B200': WatchModel.generic,
  'OCW-T200': WatchModel.generic,
  'OCW-B1200': WatchModel.generic,
  'OCW-S6000': WatchModel.generic,
  'OCW-T5000': WatchModel.generic,
  'OCW-B1400': WatchModel.generic,
  'MRG-B2000': WatchModel.generic,
  'PRJ-B001': WatchModel.gb001,
  'OCW-5700': WatchModel.generic,
  'MTG-B3100': WatchModel.mtgB3000,
  'OCW-5800': WatchModel.generic,
  'PRW-B1000': WatchModel.generic,
  'GMD-B300': WatchModel.generic,
  'WS-B1000': WatchModel.generic,
  'F-B100W': WatchModel.fB100,
  'OCW-P3000': WatchModel.generic,
};

/// Derives the short watch name by stripping `CASIO ` and taking the first word.
String deriveShortName(String name) {
  final clean = name.startsWith('CASIO ')
      ? name.substring('CASIO '.length)
      : name;
  final trimmed = clean.trim();
  final parts = trimmed.split(' ');
  return parts.isNotEmpty ? parts.first : '';
}

/// Resolves a [WatchModel] via exact lookup in the official Casio model map.
WatchModel resolveModel(String name) {
  final modelName =
      (name.startsWith('CASIO ') ? name.substring('CASIO '.length) : name)
          .trim();
  return exactModelMap[modelName] ?? WatchModel.generic;
}

/// Looks up the [ModelInfo] for [model], falling back to `generic`.
ModelInfo resolveModelInfo(WatchModel model) {
  return _modelMap[model] ?? _modelMap[WatchModel.generic]!;
}

/// Tracks characteristics and capabilities of the currently connected watch.
class WatchInfo {
  WatchInfo();

  String name = '';
  String shortName = '';
  String address = '';
  WatchModel model = WatchModel.generic;
  ModelInfo info = resolveModelInfo(WatchModel.generic);

  void setNameAndModel(String name) {
    this.name = name;
    shortName = deriveShortName(name);
    model = resolveModel(name);
    info = resolveModelInfo(model);
  }

  Map<String, Object?> lookupWatchInfo(String name) {
    final shortName = deriveShortName(name);
    final model = resolveModel(name);
    final info = resolveModelInfo(model);
    return <String, Object?>{
      'name': name,
      'short_name': shortName,
      'model': model,
      'alwaysConnected': info.alwaysConnected,
      'worldCitiesCount': info.worldCitiesCount,
      'dstCount': info.dstCount,
      'alarmCount': info.alarmCount,
      'hasAutoLight': info.hasAutoLight,
      'hasReminders': info.hasReminders,
      'hasStepCounter': info.hasStepCounter,
      'hasNewTimeFormat': info.hasNewTimeFormat,
      'hasSecondDial': info.hasSecondDial,
    };
  }

  void setAddress(String address) => this.address = address;
  String getAddress() => address;
  WatchModel getModel() => model;

  void reset() {
    name = '';
    shortName = '';
    address = '';
    model = WatchModel.generic;
    info = resolveModelInfo(WatchModel.generic);
  }

  // Capability properties forwarded from info.
  int get worldCitiesCount => info.worldCitiesCount;
  int get dstCount => info.dstCount;
  bool get hasAppInfo => info.hasAppInfo;
  int get alarmCount => info.alarmCount;
  bool get hasAutoLight => info.hasAutoLight;
  bool get hasReminders => info.hasReminders;
  String get shortLightDuration => info.shortLightDuration;
  String get longLightDuration => info.longLightDuration;
  bool get weekLanguageSupported => info.weekLanguageSupported;
  bool get hasWorldCities => info.hasWorldCities;
  bool get hasTemperature => info.hasTemperature;
  bool get temperature => info.hasTemperature;
  bool get hasBatteryLevel => info.hasBatteryLevel;
  int get batteryLevelLowerLimit => info.batteryLevelLowerLimit;
  int get batteryLevelUpperLimit => info.batteryLevelUpperLimit;
  bool get alwaysConnected => info.alwaysConnected;
  bool get findButtonUserDefined => info.findButtonUserDefined;
  bool get hasPowerSavingMode => info.hasPowerSavingMode;
  bool get chimeInSettings => info.chimeInSettings;
  bool get vibrate => info.vibrate;
  bool get hasHealthFunctions => info.hasHealthFunctions;
  bool get hasMessages => info.hasMessages;
  bool get hasDateFormat => info.hasDateFormat;
  bool get hasHomeTime => info.hasHomeTime;
  bool get hasMultipleFonts => info.hasMultipleFonts;
  bool get hasStepCounter => info.hasStepCounter;
  bool get hasStepCounterMock => info.hasStepCounterMock;
  bool get hasNewTimeFormat => info.hasNewTimeFormat;
  bool get hasTimeAdjustment => info.hasTimeAdjustment;
  bool get hasSecondDial => info.hasSecondDial;
  bool get hasFineWatchCondition => info.hasFineWatchCondition;
  bool get hasTimeFormat => info.hasTimeFormat;
  bool get hasHourlyChime => info.hasHourlyChime;
  bool get hasLongTimerKey => info.hasLongTimerKey;
  int get settingsSize => info.settingsSize;
  WatchProtocol get protocol => info.protocol;
}

/// Global watch info singleton (mirrors Python's module global).
final WatchInfo watchInfo = WatchInfo();
