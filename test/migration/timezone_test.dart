import 'package:gshock_api_dart/gshock_api_dart.dart';
import 'package:test/test.dart';

import 'golden/python_reference.dart';
import 'helpers.dart';

/// Verifies the timezone tables against Python's
/// `casio_time_zone_helper.py` — the full TIME_ZONE_TABLE (49 rows),
/// WORLD_CITY_COORDINATES, and the helper behaviors the time-set flow
/// depends on.
void main() {
  setUp(resetMigrationState);
  tearDown(resetMigrationState);

  group('TIME_ZONE_TABLE', () {
    test('has exactly 49 rows like Python', () {
      expect(pythonTimeZoneTable.length, 49);
      expect(CasioTimeZoneHelper.timeZoneTable.length, 49);
    });

    test('every row matches Python (name, zone name, DST rules)', () {
      final dartTable = CasioTimeZoneHelper.timeZoneTable;
      for (var i = 0; i < pythonTimeZoneTable.length; i++) {
        final expected = pythonTimeZoneTable[i];
        final row = dartTable[i];
        expect(
          row.name,
          expected.$1,
          reason: 'TIME_ZONE_TABLE[$i].name: ${row.name} != ${expected.$1}',
        );
        expect(
          row.zoneName,
          expected.$2,
          reason:
              'TIME_ZONE_TABLE[$i].zoneName: '
              '${row.zoneName} != ${expected.$2}',
        );
        expect(
          row.dstRulesValue,
          expected.$3,
          reason: 'TIME_ZONE_TABLE[$i].dstRules mismatch',
        );
      }
    });

    test('timeZoneMap covers every table zone name', () {
      // Python builds TIME_ZONE_MAP from the table; Dart mirrors it.
      expect(
        CasioTimeZoneHelper.timeZoneMap.length,
        CasioTimeZoneHelper.timeZoneTable.length,
      );
      for (final entry in CasioTimeZoneHelper.timeZoneMap.entries) {
        expect(entry.value.zoneName, entry.key);
      }
    });
  });

  group('WORLD_CITY_COORDINATES', () {
    test('every coordinate entry matches Python', () {
      var matched = 0;
      for (final entry in pythonWorldCityCoordinates.entries) {
        final coords = CasioTimeZoneHelper.worldCityCoordinates[entry.key];
        expect(
          coords,
          isNotNull,
          reason: 'missing coordinates for ${entry.key}',
        );
        expect(
          coords!.lat,
          closeTo(entry.value.$1, 1e-9),
          reason: '${entry.key} latitude mismatch',
        );
        expect(
          coords.lon,
          closeTo(entry.value.$2, 1e-9),
          reason: '${entry.key} longitude mismatch',
        );
        matched++;
      }
      expect(matched, 52);
      expect(
        CasioTimeZoneHelper.worldCityCoordinates.length,
        pythonWorldCityCoordinates.length,
      );
    });

    test('getWorldCityCoordinates resolves exact and fallback entries', () {
      final london = CasioTimeZoneHelper.getWorldCityCoordinates(
        'Europe/London',
      );
      expect(london.exact, isTrue);
      expect(london.lat, closeTo(51.5074, 1e-9));
      // Fallback path: an IANA zone without a table entry approximates by
      // offset (like Python's coordinates fallback).
      final fallback = CasioTimeZoneHelper.getWorldCityCoordinates(
        'Europe/Berlin',
      );
      expect(fallback.exact, isFalse);
    });
  });

  group('world city lookup', () {
    test('parseCity matches Python for sample zones', () {
      // Python `WorldCitiesIO.parse_city`: last path segment, upper-cased,
      // ':'-segment split.
      for (final entry in pythonParsedCity.entries) {
        expect(
          WorldCitiesIO.parseCity(entry.key),
          entry.value,
          reason: 'parseCity(${entry.key}) mismatch',
        );
      }
      expect(WorldCitiesIO.parseCity('Europe/London'), 'LONDON');
      expect(WorldCitiesIO.parseCity('America/New_York'), 'NEW_YORK');
      expect(WorldCitiesIO.parseCity('UTC'), 'UTC');
    });
  });

  group('setTimezone', () {
    test('stores the active Casio timezone like Python', () {
      CasioTimeZoneHelper.setTimezone('Europe/London');
      final tzLondon = CasioTimeZoneHelper.getCasioTimeZone();
      expect(tzLondon.zoneName, 'Europe/London');
      expect(tzLondon.name, 'LONDON');

      CasioTimeZoneHelper.setTimezone('Asia/Tokyo');
      final tzTokyo = CasioTimeZoneHelper.getCasioTimeZone();
      expect(tzTokyo.zoneName, 'Asia/Tokyo');
      expect(tzTokyo.name, 'TOKYO');
    });

    test('invalid timezone names are rejected like Python ValueError', () {
      expect(
        () => CasioTimeZoneHelper.setTimezone('Not/AZone'),
        throwsArgumentError,
      );
    });

    test('null falls back to the local system timezone', () {
      CasioTimeZoneHelper.setTimezone(null);
      final local = CasioTimeZoneHelper.getCasioTimeZone();
      expect(local.zoneName, isNotEmpty);
      // Local fallback must resolve to a real table entry.
      expect(
        CasioTimeZoneHelper.timeZoneTable.any(
          (e) => e.zoneName == local.zoneName,
        ),
        isTrue,
      );
    });

    test('findTimeZone resolves named zones to table entries', () {
      final utc = CasioTimeZoneHelper.findTimeZone('UTC');
      expect(utc.name, 'UTC');
      final ny = CasioTimeZoneHelper.findTimeZone('America/New_York');
      expect(ny.name, 'NEW YORK');
      // Fixed-offset style zones like 'UTC-12' are table entries.
      expect(CasioTimeZoneHelper.findTimeZone('UTC-12').name, 'BAKER ISLAND');
    });

    test('getLocalCasioTimeZone always resolves', () {
      final local = CasioTimeZoneHelper.getLocalCasioTimeZone();
      expect(local, isNotNull);
      expect(local.zoneName, isNotEmpty);
    });
  });
}
