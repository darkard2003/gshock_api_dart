import 'package:gshock_api_dart/gshock_api_dart.dart';

Future<void> main() async {
  // Pure encoders need no BLE device.
  print(Bytes.fromCasioCmd('A3010C')); // [163, 1, 12]
  print(Bytes.toHexString(<int>[0x01, 0x2A])); // 0x01 2A

  final encodedTime = TimeEncoderPure.encodeCurrentTime(
    DateTime(2026, 5, 30, 8, 45, 30, 123, 456),
  );
  print('time payload: ${Bytes.toHexString(encodedTime)}');

  // A full round-trip can be exercised with the in-memory transport, which is
  // handy on platforms without BLE (or in tests).
  final transport = MockTransport();
  final connection = GshockConnection(
    address: 'AA:BB:CC:DD:EE:FF',
    transport: transport,
  );

  watchInfo.setNameAndModel('CASIO GW-B5600');
  await connection.connect();

  final nameFuture = WatchNameIO.request(connection);
  await Future<void>.delayed(Duration.zero);
  transport.emit(CasioConstants.casioNotificationCharacteristicUuid, <int>[
    0x23,
    ...'G-SHOCK'.codeUnits,
    0x00,
  ]);
  print('watch name: ${await nameFuture}');

  await connection.disconnect();
  watchInfo.reset();
}
