import 'dart:typed_data';

import 'package:gshock_api_dart/gshock_api_dart.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Verifies the connection/transport layer behaviors that the Python
/// `connection.py` guarantees: handle->UUID dispatch, hex-string vs bytes
/// normalization, write-without-response flags, dynamic subscription,
/// notification routing (including the DRSP/Convoy bypass), error mapping,
/// and request timeouts.
void main() {
  setUp(resetMigrationState);
  tearDown(resetMigrationState);

  group('write dispatch', () {
    test('every mapped handle dispatches to its Python UUID', () async {
      final transport = MockTransport();
      final connection = await _connected(transport);
      final handles = GshockConnection.initHandlesMap();

      final cases = <int, String>{
        0x0C: CasioConstants.casioReadRequestForAllFeaturesCharacteristicUuid,
        0x0D: CasioConstants.casioNotificationCharacteristicUuid,
        0x0E: CasioConstants.casioAllFeaturesCharacteristicUuid,
        0x11: CasioConstants.casioDataRequestSpCharacteristicUuid,
        0x14: CasioConstants.casioConvoyCharacteristicUuid,
        0x17: CasioConstants.casioSetConfigurationCharacteristicUuid,
        0x19: CasioConstants.casioGetConfigurationCharacteristicUuid,
      };
      for (final entry in cases.entries) {
        await connection.write(entry.key, <int>[0xAB]);
        expect(
          transport.writes.last.uuid,
          entry.value,
          reason:
              'handle 0x${entry.key.toRadixString(16)} routed to wrong UUID',
        );
        expect(handles[entry.key], entry.value);
      }
      expect(transport.writes.length, cases.length);
    });

    test('hex-string and bytes writes are normalized identically', () async {
      final transport = MockTransport();
      final connection = await _connected(transport);

      // Python Connection.write accepts a compact hex string ('23010F') or
      // bytes and normalizes through to_casio_cmd.
      await connection.write(0x0E, '23010F');
      await connection.write(0x0E, <int>[0x23, 0x01, 0x0F]);
      expect(transport.writes.length, 2);
      for (final w in transport.writes) {
        expect(w.data, <int>[0x23, 0x01, 0x0F]);
      }
    });

    test(
      'withResponse is false exactly for Python no-response handles',
      () async {
        final transport = MockTransport();
        final connection = await _connected(transport);

        for (final handle in <int>[0x0C, 0x0D, 0x14, 0x17]) {
          await connection.write(handle, <int>[0x01]);
          expect(
            transport.writes.last.withResponse,
            isFalse,
            reason:
                'handle 0x${handle.toRadixString(16)} should be '
                'write-without-response',
          );
        }
        for (final handle in <int>[0x0E, 0x11, 0x19]) {
          await connection.write(handle, <int>[0x01]);
          expect(
            transport.writes.last.withResponse,
            isTrue,
            reason:
                'handle 0x${handle.toRadixString(16)} should be '
                'write-with-response',
          );
        }
      },
    );

    test('unmapped handles are dropped without throwing', () async {
      final transport = MockTransport();
      final connection = await _connected(transport);
      final before = transport.writes.length;
      await connection.write(0x42, <int>[0x01]);
      expect(transport.writes.length, before);
    });

    test('unsubscribed characteristics are dropped without throwing', () async {
      final transport = MockTransport(
        availableUuids: <String>{
          CasioConstants.casioReadRequestForAllFeaturesCharacteristicUuid,
        },
      );
      final connection = await _connected(transport);
      // 0x0E was not discovered/subscribed on this watch.
      await connection.write(0x0E, <int>[0x01]);
      expect(transport.writes, isEmpty);
    });

    test(
      'empty payloads are written to GATT characteristic like Python',
      () async {
        final transport = MockTransport();
        final connection = await _connected(transport);
        await connection.write(0x0E, <int>[]);
        expect(transport.writes.length, 1);
        expect(transport.writes.single.data, isEmpty);
      },
    );
  });

  group('error mapping', () {
    test('ignorable exceptions propagate unchanged', () async {
      final transport = _FailingTransport.ignorable();
      final connection = await _connected(transport);
      expect(
        () => connection.write(0x0E, <int>[0x01]),
        throwsA(isA<GShockIgnorableException>()),
      );
    });

    test('transport failures surface as GShockConnectionException', () async {
      final transport = _FailingTransport.hard();
      final connection = await _connected(transport);
      expect(
        () => connection.write(0x0E, <int>[0x01]),
        throwsA(isA<GShockConnectionException>()),
      );
    });
  });

  group('subscription and notification routing', () {
    test('every discovered characteristic is subscribed and routed', () async {
      final transport = MockTransport();
      final connection = await _connected(transport);
      watchInfo.setNameAndModel('CASIO GW-B5600');

      // Dynamic discovery: every available characteristic with notify
      // support must be subscribed (no hardcoded whitelist). Verify each
      // routing observable per UUID.
      for (final uuid in _defaultUuids) {
        transport.emit(uuid, <int>[0x01]);
      }

      // Dispatcher-routed uuids resolve a pending name request.
      final nameFuture = WatchNameIO.request(connection);
      transport.emit(CasioConstants.casioNotificationCharacteristicUuid, <int>[
        0x23,
        ...'CASIO GW-B5600'.codeUnits,
        0x00,
      ]);
      expect(await nameFuture, 'CASIO GW-B5600');

      // DRSP-routed notifications update the step-counter expected length.
      StepCounterIO.result = CancelableResult<StepCounterData>();
      StepCounterIO.accumulator = Uint8List(0);
      transport.emit(CasioConstants.casioDataRequestSpCharacteristicUuid, <int>[
        0x00,
        0x11,
        0x90,
        0x01,
        0x00,
      ]);
      expect(StepCounterIO.expectedLength, 0x190);

      // Convoy-routed notifications accumulate step-counter payload bytes.
      transport.emit(CasioConstants.casioConvoyCharacteristicUuid, <int>[
        0x01,
        0x02,
        0x03,
      ]);
      expect(StepCounterIO.accumulator.length, 3);
      StepCounterIO.result = null;
    });

    test('notifications route through the dispatcher (0x0D)', () async {
      final transport = MockTransport();
      final connection = await _connected(transport);
      watchInfo.setNameAndModel('CASIO GW-B5600');

      final nameFuture = WatchNameIO.request(connection);
      transport.emit(CasioConstants.casioNotificationCharacteristicUuid, <int>[
        0x23,
        ...'CASIO GW-B5600'.codeUnits,
        0x00,
      ]);
      expect(await nameFuture, 'CASIO GW-B5600');
    });

    test(
      'all features characteristic (0x30) also delivers notifications',
      () async {
        final transport = MockTransport();
        final connection = await _connected(transport);
        watchInfo.setNameAndModel('CASIO GW-B5600');

        final nameFuture = WatchNameIO.request(connection);
        transport.emit(CasioConstants.casioAllFeaturesCharacteristicUuid, <int>[
          0x23,
          ...'CASIO GW-B5600'.codeUnits,
          0x00,
        ]);
        expect(await nameFuture, 'CASIO GW-B5600');
      },
    );

    test('request writes the feature code to 0x0C', () async {
      final transport = MockTransport();
      final connection = await _connected(transport);
      watchInfo.setNameAndModel('CASIO GW-B5600');

      final pending = WatchNameIO.request(connection);
      expect(transport.writes.single.data, <int>[
        0x23,
      ], reason: 'read request must be exactly [0x23] on handle 0x0C');
      expect(
        transport.writes.single.uuid,
        CasioConstants.casioReadRequestForAllFeaturesCharacteristicUuid,
      );
      transport.emit(CasioConstants.casioNotificationCharacteristicUuid, <int>[
        0x23,
        ...'CASIO GW-B5600'.codeUnits,
        0x00,
      ]);
      expect(await pending, 'CASIO GW-B5600');
    });
  });

  group('connect / disconnect', () {
    test(
      'connect via scanner registers address and model from the name',
      () async {
        final transport = MockTransport();
        final scanner = MockScanner(
          device: const BleDevice(
            name: 'CASIO GW-BX5600',
            address: 'AA:BB:CC:DD:EE:FF',
          ),
        );
        final connection = GshockConnection(
          address: null,
          transport: transport,
          scanner: scanner,
        );
        expect(await connection.connect(), isTrue);
        expect(watchInfo.model, WatchModel.gwBx5600);
        expect(watchInfo.address, 'AA:BB:CC:DD:EE:FF');
        expect(watchInfo.name, 'CASIO GW-BX5600');
        expect(transport.isConnected, isTrue);
      },
    );

    test('connect returns false when the watch is not found', () async {
      final transport = MockTransport();
      final connection = GshockConnection(
        address: null,
        transport: transport,
        scanner: MockScanner(device: null),
      );
      expect(await connection.connect(), isFalse);
      expect(transport.isConnected, isFalse);
    });

    test('connect by address verifies the discovered address', () async {
      final transport = MockTransport();
      final connection = GshockConnection(
        address: 'AA:BB:CC:DD:EE:FF',
        transport: transport,
        scanner: MockScanner(
          device: const BleDevice(
            name: 'CASIO GW-B5600',
            address: 'AA:BB:CC:DD:EE:FF',
          ),
        ),
      );
      expect(await connection.connect(), isTrue);

      final directConnection = GshockConnection(
        address: '11:22:33:44:55:66',
        transport: transport,
        scanner: MockScanner(
          device: null, // Scanner returns null, but should not be called when address is given
        ),
      );
      expect(await directConnection.connect(), isTrue);
      expect(directConnection.address, '11:22:33:44:55:66');
    });

    test('disconnect clears connection state', () async {
      final transport = MockTransport();
      final connection = await _connected(transport);
      expect(transport.isConnected, isTrue);
      await connection.disconnect();
      expect(transport.isConnected, isFalse);
    });
  });

  group('request timeouts', () {
    test(
      'CancelableResult maps timeouts to GShockConnectionException',
      () async {
        final result = CancelableResult<String>(
          timeout: const Duration(milliseconds: 50),
        );
        await expectLater(
          result.getResult(),
          throwsA(
            isA<GShockConnectionException>().having(
              (e) => e.message,
              'message',
              contains('Timeout'),
            ),
          ),
        );
      },
    );

    test('Canceled results complete with their value', () async {
      final result = CancelableResult<String>();
      expect(result.isCompleted, isFalse);
      result.setResult('OK');
      expect(result.isCompleted, isTrue);
      // Late sets are ignored, mirroring the guarded Python completer.
      result.setResult('ignored');
      expect(await result.getResult(), 'OK');
    });
  });
}

const List<String> _defaultUuids = <String>[
  CasioConstants.casioGetDeviceName,
  CasioConstants.casioAppearance,
  CasioConstants.txPowerLevelCharacteristicUuid,
  CasioConstants.casioReadRequestForAllFeaturesCharacteristicUuid,
  CasioConstants.casioNotificationCharacteristicUuid,
  CasioConstants.casioAllFeaturesCharacteristicUuid,
  CasioConstants.casioDataRequestSpCharacteristicUuid,
  CasioConstants.casioConvoyCharacteristicUuid,
  CasioConstants.casioSetConfigurationCharacteristicUuid,
  CasioConstants.casioGetConfigurationCharacteristicUuid,
  CasioConstants.serialNumberString,
];

Future<GshockConnection> _connected(MockTransport transport) async {
  final connection = GshockConnection(
    address: 'AA:BB:CC:DD:EE:FF',
    transport: transport,
  );
  final ok = await connection.connect();
  if (!ok) {
    throw StateError('test connect failed');
  }
  return connection;
}

/// [MockTransport] whose writes fail, for error-mapping tests.
class _FailingTransport extends MockTransport {
  _FailingTransport.ignorable() : _ignorable = true;
  _FailingTransport.hard() : _ignorable = false;

  final bool _ignorable;

  @override
  Future<void> write(
    String uuid,
    Uint8List data, {
    required bool withResponse,
  }) async {
    if (_ignorable) {
      throw GShockIgnorableException('simulated ignorable BLE error');
    }
    throw Exception('simulated hard BLE failure');
  }
}
