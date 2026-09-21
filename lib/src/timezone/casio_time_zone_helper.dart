import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Latitude/longitude pair.
class LatLon {
  const LatLon(this.lat, this.lon);

  final double lat;
  final double lon;
}

/// Result of a world-city coordinate lookup.
class WorldCityCoordinates {
  const WorldCityCoordinates(this.lat, this.lon, this.exact);

  final double lat;
  final double lon;
  final bool exact;
}

bool _tzInitialized = false;

/// Lazily initializes the embedded IANA timezone database.
void ensureTimeZonesInitialized() {
  if (!_tzInitialized) {
    tzdata.initializeTimeZones();
    _tzInitialized = true;
  }
}

/// A Casio timezone entry. Mirrors `CasioTimeZone` in Python.
class CasioTimeZone {
  CasioTimeZone(this.name, this.zoneName, [this.dstRulesValue = 0]);

  final String name;
  final String zoneName;
  final int dstRulesValue;

  /// Resolved IANA location (UTC on failure).
  tz.Location get zoneId {
    ensureTimeZonesInitialized();
    try {
      return tz.getLocation(zoneName);
    } catch (_) {
      return tz.UTC;
    }
  }

  /// Standard offset in 15-minute intervals.
  int get offset {
    try {
      return _standardOffsetSeconds ~/ 900;
    } catch (_) {
      return 0;
    }
  }

  /// DST offset in 15-minute intervals.
  int get dstOffset => getDstDuration().inSeconds ~/ 900;

  /// DST rule byte (0 when the zone has no DST).
  int get dstRules => dstOffset > 0 ? dstRulesValue : 0;

  bool isInDst() {
    try {
      final now = DateTime.now();
      final current = tz.TZDateTime.from(now, zoneId).timeZoneOffset.inSeconds;
      return current != _standardOffsetSeconds;
    } catch (_) {
      return false;
    }
  }

  bool hasRules() => dstRules != 0;

  int? _cachedYear;
  List<int>? _cachedOffsets;

  /// Returns the DST offset duration for the current year.
  Duration getDstDuration() {
    try {
      final offsets = _seasonalOffsets();
      final maxOffset = offsets.reduce((a, b) => a > b ? a : b);
      final minOffset = offsets.reduce((a, b) => a < b ? a : b);
      return Duration(seconds: maxOffset - minOffset);
    } catch (_) {
      return Duration.zero;
    }
  }

  int get _standardOffsetSeconds {
    final offsets = _seasonalOffsets();
    return offsets.reduce((a, b) => a < b ? a : b);
  }

  List<int> _seasonalOffsets() {
    final currentYear = DateTime.now().year;
    final cached = _cachedOffsets;
    if (cached != null && _cachedYear == currentYear) {
      return cached;
    }
    ensureTimeZonesInitialized();
    final location = zoneId;
    final jan = tz.TZDateTime(location, currentYear, 1, 15);
    final jul = tz.TZDateTime(location, currentYear, 7, 15);
    final dec = tz.TZDateTime(location, currentYear, 12, 15);
    final offsets = <int>{
      jan.timeZoneOffset.inSeconds,
      jul.timeZoneOffset.inSeconds,
      dec.timeZoneOffset.inSeconds,
    }.toList(growable: false);
    _cachedYear = currentYear;
    _cachedOffsets = offsets;
    return offsets;
  }
}

/// Helper providing Casio timezone mapping and coordinate lookup.
class CasioTimeZoneHelper {
  CasioTimeZoneHelper._();

  static String _currentTimezone = 'UTC';
  static CasioTimeZone? _casioTimezone;

  static final List<CasioTimeZone> timeZoneTable = <CasioTimeZone>[
    CasioTimeZone('BAKER ISLAND', 'UTC-12'),
    CasioTimeZone('MARQUESAS ISLANDS', 'Pacific/Marquesas', 0xDA),
    CasioTimeZone('POGO POGO', 'Pacific/Pago_Pago'),
    CasioTimeZone('HONOLULU', 'Pacific/Honolulu'),
    CasioTimeZone('ANCHORAGE', 'America/Anchorage', 0x1),
    CasioTimeZone('LOS ANGELES', 'America/Los_Angeles', 0x1),
    CasioTimeZone('DENVER', 'America/Denver', 0x1),
    CasioTimeZone('CHICAGO', 'America/Chicago', 0x1),
    CasioTimeZone('NEW YORK', 'America/New_York', 0x1),
    CasioTimeZone('HALIFAX', 'America/Halifax', 0x1),
    CasioTimeZone("ST.JOHN'S", 'America/St_Johns', 0x1),
    CasioTimeZone('RIO DE JANEIRO', 'America/Sao_Paulo'),
    CasioTimeZone('F.DE NORONHA', 'America/Noronha'),
    CasioTimeZone('PRAIA', 'Atlantic/Cape_Verde'),
    CasioTimeZone('UTC', 'UTC'),
    CasioTimeZone('LONDON', 'Europe/London', 0x02),
    CasioTimeZone('PARIS', 'Europe/Paris', 0x02),
    CasioTimeZone('ATHENS', 'Europe/Athens', 0x02),
    CasioTimeZone('JEDDAH', 'Asia/Riyadh', 0x0),
    CasioTimeZone('JERUSALEM', 'Asia/Jerusalem', 0x2A),
    CasioTimeZone('TEHRAN', 'Asia/Tehran', 0x2B),
    CasioTimeZone('DUBAI', 'Asia/Dubai'),
    CasioTimeZone('KABUL', 'Asia/Kabul'),
    CasioTimeZone('KARACHI', 'Asia/Karachi'),
    CasioTimeZone('DELHI', 'Asia/Kolkata'),
    CasioTimeZone('KATHMANDU', 'Asia/Kathmandu'),
    CasioTimeZone('DHAKA', 'Asia/Dhaka'),
    CasioTimeZone('YANGON', 'Asia/Yangon'),
    CasioTimeZone('BANGKOK', 'Asia/Bangkok'),
    CasioTimeZone('HONG KONG', 'Asia/Hong_Kong'),
    CasioTimeZone('PYONGYANG', 'Asia/Pyongyang'),
    CasioTimeZone('EUCLA', 'Australia/Eucla'),
    CasioTimeZone('TOKYO', 'Asia/Tokyo'),
    CasioTimeZone('ADELAIDE', 'Australia/Adelaide', 0x4),
    CasioTimeZone('SYDNEY', 'Australia/Sydney', 0x4),
    CasioTimeZone('LORD HOWE ISLAND', 'Australia/Lord_Howe', 0x12),
    CasioTimeZone('NOUMEA', 'Pacific/Noumea'),
    CasioTimeZone('WELLINGTON', 'Pacific/Auckland', 0x5),
    CasioTimeZone('CHATHAM ISLANDS', 'Pacific/Chatham', 0x17),
    CasioTimeZone('NUKUALOFA', 'Pacific/Tongatapu'),
    CasioTimeZone('KIRITIMATI', 'Pacific/Kiritimati'),
    CasioTimeZone('CASABLANCA', 'Africa/Casablanca', 0x0F),
    CasioTimeZone('BEIRUT', 'Asia/Beirut', 0x0C),
    CasioTimeZone('NORFOLK ISLAND', 'Pacific/Norfolk', 0x04),
    CasioTimeZone('EASTER ISLAND', 'Pacific/Easter', 0x1C),
    CasioTimeZone('HAVANA', 'America/Havana', 0x15),
    CasioTimeZone('SANTIAGO', 'America/Santiago', 0x1B),
    CasioTimeZone('ASUNCION', 'America/Asuncion', 0x09),
    CasioTimeZone('PONTA DELGADA', 'Atlantic/Azores', 0x02),
  ];

  static final Map<String, CasioTimeZone> timeZoneMap = <String, CasioTimeZone>{
    for (final tzEntry in timeZoneTable) tzEntry.zoneName: tzEntry,
  };

  static final Map<String, LatLon> worldCityCoordinates = <String, LatLon>{
    'Asia/Ho_Chi_Minh': const LatLon(10.7958, 106.7062),
    'Europe/Madrid': const LatLon(41.4548, 2.2502),
    'Asia/Shanghai': const LatLon(22.7230, 114.2611),
    'UTC-12': const LatLon(0.1936, -176.4769),
    'Pacific/Marquesas': const LatLon(-8.9167, -140.1000),
    'Pacific/Pago_Pago': const LatLon(-14.2781, -170.7025),
    'Pacific/Honolulu': const LatLon(21.3069, -157.8583),
    'America/Anchorage': const LatLon(61.2181, -149.9003),
    'America/Los_Angeles': const LatLon(34.0522, -118.2437),
    'America/Denver': const LatLon(39.7392, -104.9903),
    'America/Chicago': const LatLon(41.8781, -87.6298),
    'America/New_York': const LatLon(40.7128, -74.0060),
    'America/Halifax': const LatLon(44.6488, -63.5752),
    'America/St_Johns': const LatLon(47.5615, -52.7126),
    'America/Sao_Paulo': const LatLon(-22.9068, -43.1729),
    'America/Noronha': const LatLon(-3.8536, -32.4297),
    'Atlantic/Cape_Verde': const LatLon(14.9330, -23.5133),
    'UTC': const LatLon(0.0, 0.0),
    'Europe/London': const LatLon(51.5074, -0.1278),
    'Europe/Paris': const LatLon(48.8566, 2.3522),
    'Europe/Athens': const LatLon(37.9838, 23.7275),
    'Asia/Riyadh': const LatLon(21.4858, 39.1925),
    'Asia/Jerusalem': const LatLon(31.7683, 35.2137),
    'Asia/Tehran': const LatLon(35.6892, 51.3890),
    'Asia/Dubai': const LatLon(25.2048, 55.2708),
    'Asia/Kabul': const LatLon(34.5553, 69.2075),
    'Asia/Karachi': const LatLon(24.8607, 67.0011),
    'Asia/Kolkata': const LatLon(28.6139, 77.2090),
    'Asia/Kathmandu': const LatLon(27.7172, 85.3240),
    'Asia/Dhaka': const LatLon(23.8103, 90.4125),
    'Asia/Yangon': const LatLon(16.8661, 96.1951),
    'Asia/Bangkok': const LatLon(13.7563, 100.5018),
    'Asia/Hong_Kong': const LatLon(22.3193, 114.1694),
    'Asia/Pyongyang': const LatLon(39.0392, 125.7625),
    'Australia/Eucla': const LatLon(-31.6784, 128.8869),
    'Asia/Tokyo': const LatLon(35.6762, 139.6503),
    'Australia/Adelaide': const LatLon(-34.9285, 138.6007),
    'Australia/Sydney': const LatLon(-33.8688, 151.2093),
    'Australia/Lord_Howe': const LatLon(-31.5553, 159.0821),
    'Pacific/Noumea': const LatLon(-22.2758, 166.4581),
    'Pacific/Auckland': const LatLon(-41.2865, 174.7762),
    'Pacific/Chatham': const LatLon(-43.9500, -176.5500),
    'Pacific/Tongatapu': const LatLon(-21.1789, -175.1982),
    'Pacific/Kiritimati': const LatLon(1.8721, -157.4278),
    'Africa/Casablanca': const LatLon(33.5731, -7.5898),
    'Asia/Beirut': const LatLon(33.8938, 35.5018),
    'Pacific/Norfolk': const LatLon(-29.0408, 167.9547),
    'Pacific/Easter': const LatLon(-27.1127, -109.3497),
    'America/Havana': const LatLon(23.1136, -82.3666),
    'America/Santiago': const LatLon(-33.4489, -70.6693),
    'America/Asuncion': const LatLon(-25.2637, -57.5759),
    'Atlantic/Azores': const LatLon(37.7412, -25.6756),
  };

  /// Sets the active timezone. When [timezoneName] is `null` the local system
  /// timezone name is used.
  static void setTimezone(String? timezoneName) {
    ensureTimeZonesInitialized();
    if (timezoneName == null) {
      timezoneName = tz.local.name;
      if (timezoneName == 'UTC' || timezoneName.isEmpty) {
        // Best effort: Dart has no IANA local-zone lookup. Fall back to UTC.
        timezoneName = 'UTC';
      }
    } else {
      try {
        tz.getLocation(timezoneName);
      } catch (_) {
        throw ArgumentError.value(
          timezoneName,
          'timezoneName',
          'Invalid timezone name',
        );
      }
    }
    _currentTimezone = timezoneName;
    _casioTimezone = findTimeZone(timezoneName);
  }

  static CasioTimeZone getCasioTimeZone() {
    return _casioTimezone ??= findTimeZone(_currentTimezone);
  }

  /// Compares two timezones by UTC offset and DST at now and 182 days later.
  static bool isEquivalent(String tz1Name, String tz2Name) {
    try {
      ensureTimeZonesInitialized();
      final tz1 = tz.getLocation(tz1Name);
      final tz2 = tz.getLocation(tz2Name);
      final now = DateTime.now();
      final future = now.add(const Duration(days: 182));

      for (final t in <DateTime>[now, future]) {
        final dt1 = tz.TZDateTime.from(t, tz1);
        final dt2 = tz.TZDateTime.from(t, tz2);
        if (dt1.timeZoneOffset != dt2.timeZoneOffset) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Finds the Casio timezone for an IANA zone name.
  static CasioTimeZone findTimeZone(String timeZoneName) {
    final direct = timeZoneMap[timeZoneName];
    if (direct != null) return direct;

    for (final entry in timeZoneTable) {
      if (isEquivalent(entry.zoneName, timeZoneName)) {
        return entry;
      }
    }

    final name = timeZoneName
        .split('/')
        .last
        .replaceAll('_', ' ')
        .toUpperCase();
    return CasioTimeZone(name, timeZoneName, 0x00);
  }

  /// Determines the local system Casio timezone.
  static CasioTimeZone getLocalCasioTimeZone() {
    ensureTimeZonesInitialized();
    final localName = tz.local.name;
    if (timeZoneMap.containsKey(localName)) {
      return timeZoneMap[localName]!;
    }
    return timeZoneMap['UTC'] ?? CasioTimeZone('UTC', 'UTC');
  }

  /// Legacy lookup by Casio name first, then IANA name.
  static CasioTimeZone findTimeZoneLegacy(String timeZoneName) {
    final direct = timeZoneMap[timeZoneName];
    if (direct != null) return direct;
    final upper = timeZoneName.toUpperCase();
    for (final entry in timeZoneTable) {
      if (entry.name == upper) return entry;
    }
    final name = timeZoneName.split('/').last.toUpperCase();
    return CasioTimeZone(name, timeZoneName, 0x00);
  }

  /// Returns coordinates for [zoneId] (exact when present in the table).
  static WorldCityCoordinates getWorldCityCoordinates(String zoneId) {
    final coords = worldCityCoordinates[zoneId];
    if (coords != null) {
      return WorldCityCoordinates(coords.lat, coords.lon, true);
    }

    try {
      ensureTimeZonesInitialized();
      final location = tz.getLocation(zoneId);
      final offsetHours =
          tz.TZDateTime.now(location).timeZoneOffset.inSeconds / 3600.0;
      final approxLon = (offsetHours * 15.0).clamp(-180.0, 180.0);
      return WorldCityCoordinates(0.0, approxLon, false);
    } catch (_) {
      return const WorldCityCoordinates(0.0, 0.0, false);
    }
  }
}
