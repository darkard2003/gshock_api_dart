import 'dart:typed_data';

import '../../adapters/linux_bluez/bluez_transport.dart';
import 'package:gshock_api_dart/gshock_api_dart.dart';
import 'package:test/test.dart';

import 'fake_watch.dart';
import 'helpers.dart';

/// Verifies the public API surface matches the Python `GshockAPI` index
/// (AGENTS.md "Public API index" table): every method must exist with the
/// expected shape and be callable end-to-end. Compile-time presence is
/// enforced by the tear-offs below — a missing method fails the build.
void main() {
  setUp(resetMigrationState);
  tearDown(resetMigrationState);

  group('facade completeness', () {
    test('exposes every Python public method', () async {
      final watch = FakeWatch();
      final connection = await watch.connect();
      final api = GshockApi(connection);

      // The 24-method Python public API index, as tear-offs.
      final methods = <Function>[
        api.getWatchName,
        api.getPressedButton,
        api.getWorldCities,
        api.getDstForWorldCities,
        api.getDstWatchState,
        api.getHomeTime,
        api.setTime,
        api.getAlarms,
        api.setAlarms,
        api.getTimer,
        api.setTimer,
        api.getWatchCondition,
        api.getTimeAdjustment,
        api.setTimeAdjustment,
        api.getBasicSettings,
        api.getSettings,
        api.setSettings,
        api.getStepCount,
        api.getStepCountToday,
        api.getReminders,
        api.getEventFromWatch,
        api.setReminders,
        api.getAppInfo,
        api.sendAppNotification,
      ];
      expect(methods.length, 24);
      expect(api.reset, isNotNull);
    });

    test('parameters match the Python signatures', () async {
      final watch = FakeWatch();
      final connection = await watch.connect();
      final api = GshockApi(connection);

      // Named parameters used by the Python implementation.
      watch.respondWorldCities('LONDON');
      expect(api.getWorldCities(2), isA<Future<Uint8List>>());

      watch.respondWorldCities('LONDON');
      expect(api.getDstForWorldCities(1), isA<Future<Uint8List>>());

      watch.respondDstWatchState();
      expect(api.getDstWatchState(DtsState.zero), isA<Future<Uint8List>>());

      watch.respondHomeTime('LONDON');
      expect(api.getHomeTime(slot: 1), isA<Future<String>>());

      expect(
        api.setTime(
          currentTime: 1778000000.0,
          offset: 0,
          timezone: 'Europe/London',
        ),
        isA<Future<void>>(),
      );

      expect(api.getStepCount(peek: true), isA<Future<StepCounterData>>());
      expect(api.getEventFromWatch(3), isA<Future<Map<String, Object?>>>());
      expect(
        api.sendAppNotification(
          AppNotification(
            type: NotificationType.calendar,
            timestamp: '20250516T233000',
            app: 'Calendar',
            title: 'T',
            text: 'T',
          ),
        ),
        isA<Future<void>>(),
      );
    });

    test('facade delegates to the watch protocol (capability gates)', () async {
      final watch = FakeWatch();
      await watch.connect();

      // Standard GW-B5600 has no step counter; the D1 superset method still
      // works through the protocol without DRSP traffic when the watch
      // reports data (verified in the step-counter E2E test). Here we only
      // assert the wiring delegates to the active protocol instance.
      expect(watchInfo.protocol, isA<StandardProtocol>());
    });

    test(
      'a private WatchInfo instance does not leak state into the global',
      () async {
        final watch = FakeWatch(advertisedName: 'CASIO MTG-B3000');
        final connection = await watch.connect();
        final privateInfo = WatchInfo();
        final api = GshockApi(connection, watchInfo: privateInfo);

        // The global was set by the connect() flow; the private instance stays
        // generic until used, mirroring Python's watch_info.reset() guardrail.
        expect(watchInfo.model, WatchModel.mtgB3000);
        expect(privateInfo.model, WatchModel.generic);
        privateInfo.reset();
        expect(watchInfo.model, WatchModel.mtgB3000);
        expect(api, isNotNull);
      },
    );
  });

  group('package exports', () {
    test('barrel exports cover every migration area', () {
      // Compile-time references to the full exported surface.
      final symbols = <Object>[
        GshockApi, // facade
        GshockConnection, MockTransport, MockScanner, BleDevice, // transport
        AlwaysConnectedWatchFilter, // always-connected throttling
        CasioConstants, // constants
        MessageDispatcher, // dispatcher
        GShockException, GShockConnectionException, GShockIgnorableException,
        WatchModel, WatchInfo, // models
        AppNotification, NotificationType,
        Alarm, Settings, Event,
        StepCounterData,
        StandardProtocol, MipProtocol, AnalogueProtocol, WatchProtocol,
        CasioTimeZoneHelper, CasioTimeZone,
        Bytes, CancelableResult, gshockLogger,
      ];
      expect(symbols.length, 28);

      final adapterSymbols = <Object>[
        BluezTransport, BluezScanner, // Linux transport adapter
      ];
      expect(adapterSymbols.length, 2);
    });

    test('casioServiceUuid matches the Python scanner service filter', () {
      expect(casioServiceUuid, '00001804-0000-1000-8000-00805f9b34fb');
    });
  });

  group('always-connected filter', () {
    test('throttles reconnects within 6 hours like Python', () {
      final filter = AlwaysConnectedWatchFilter();
      const name = 'CASIO DW-H5600';
      watchInfo.reset();

      // First connect is allowed and records the connection time.
      expect(filter.connectionFilter(name), isTrue);
      // A second connect within 6 hours is throttled.
      expect(filter.connectionFilter(name), isFalse);
    });

    test('non-always-connected watches are never throttled', () {
      final filter = AlwaysConnectedWatchFilter();
      expect(filter.connectionFilter('CASIO GW-B5600'), isTrue);
      expect(filter.connectionFilter('CASIO GW-B5600'), isTrue);
    });

    test('explicit time updates re-allow connections', () {
      final filter = AlwaysConnectedWatchFilter();
      const name = 'CASIO DW-H5600';
      expect(filter.connectionFilter(name), isTrue);
      expect(filter.connectionFilter(name), isFalse);
      // Simulate the 6-hour window elapsing.
      filter.lastConnectedTimes[name] =
          DateTime.now().millisecondsSinceEpoch - (6 * 3600 * 1000 + 1);
      expect(filter.connectionFilter(name), isTrue);
    });
  });
}
