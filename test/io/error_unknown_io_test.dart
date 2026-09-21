import 'dart:typed_data';

import 'package:gshock_api_dart/src/io/error_io.dart';
import 'package:gshock_api_dart/src/io/unknown_io.dart';
import 'package:test/test.dart';

void main() {
  group('ErrorIO', () {
    test('onReceived handles error bytes without throwing', () {
      expect(
        () => ErrorIO.onReceived(Uint8List.fromList(<int>[0xFF, 0x01])),
        returnsNormally,
      );
    });

    test('request logs message without throwing', () async {
      await expectLater(ErrorIO.request('Test error'), completes);
    });
  });

  group('UnknownIO', () {
    test('onReceived handles unknown bytes without throwing', () {
      expect(
        () => UnknownIO.onReceived(Uint8List.fromList(<int>[0x0A, 0x02])),
        returnsNormally,
      );
    });
  });
}
