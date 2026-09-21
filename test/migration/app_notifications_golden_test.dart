import 'dart:typed_data';

import 'package:gshock_api_dart/gshock_api_dart.dart';
import 'package:test/test.dart';

void main() {
  group('AppNotification Captured Watch Buffers', () {
    const bufferSms =
        'fdfffffffffef9cdcfcdcacfcaceccabcec7cfcdcdcef7ffb29a8c8c9e989a8cf1ffd7cbcec9d6dfc7ccccd2cdcfc8c7ffffe6ffab97968cdf968cdf9edf8c96928f939adf929a8c8c9e989adf';
    const bufferSms2 =
        'fcfffffffffef9cdcfcdcacfcaceccabcec7cfcdcac6f7ffb29a8c8c9e989a8cf1ffd7cbcec9d6dfc7ccccd2cdcfc8c7fffff4ffbe91908b979a8ddf90919a';
    const bufferGmail =
        'fffffffffffef9cdcfcdcacfcaceceabcfc8cbcccecffaffb8929e9693fdff929affff05ffab97968cdf968cdf9edf899a8d86df93909198df8c8a9d959a9c8bd1dfb29e86899adf9a899a91df8b9090df93909198d1dfbd8a8bdf979a8d9adf968bdf968cd1d1d1f5a8979e8bdf968cdf968bc0f5b6df8b97969194df889adf9c9e91df9b90df9d9a8b8b9a8ddf8b979e91df8b979adf909999969c969e93dfbc9e8c9690dfb8d2ac97909c94dfbe8f8fdedfab97968cdf9e8f8fdf8f8d9089969b9a8cdf8b979adf999093939088969198df9a878b8d9edf999a9e8b8a8d9a8cc5f5ac9a8b8cdf889e8b9c97d88cdf8d9a9296919b';
    const bufferGmailJapanese =
        'fefffffffffef9cdcfcdcacfcacec9abcdcececacdcffaffb8929e9693fdff929affff9aff1a42431a5a4c1c7e501c7c6b1c7d5df51a42431a5a4c1c7e501c7c6b1c7d5d1c7c711c7d6d1a43411c7e7b1c7e601c7d751c7f7e184a4a1c7d6d1970701c7e701c7e511c7e731a5a421c7e721c7e581c7e661c7f7d1c7c551c7d5d1a7a7a1c7e581c7e66f5';
    const bufferCalendar =
        'f7fffffffffefacdcfcdcacfcaceceabcdcdcecfcfcff7ffbc9e939a919b9e8debff1d7f711d7f55b0919ad28b96929a1d7f531d7f71ffffe1ff1d7f711d7f55cecfc5cbcfdf1d7f6cdfcecec5cbcfdfafb21d7f531d7f71';
    const bufferCalendar2 =
        'f9fffffffffefacdcfcdcacfcaceceabcdcdcfc6cfcbf7ffbc9e939a919b9e8ddaff1d7f711d7f55b290919b9e86dfba899a8d86df889a9a94df99908d9a899a8d1d7f531d7f71ffffe1ff1d7f711d7f55cecfc5cccfdf1d7f6cdfcecec5cccfdfafb21d7f531d7f71';
    const bufferAllDayEvent =
        'fdfffffffffefacdcfcdcacfcacec9abcdcccccfcfcff7ffbc9e939a919b9e8de3ff1d7f711d7f55b98a9393df9b9e86df9a899a918bdfcc1d7f531d7f71ffffebff1d7f711d7f55ab9092908d8d90881d7f531d7f71';

    test('decodes and re-encodes bufferSMS round-trip', () {
      final decrypted = AppNotificationIO.xorDecodeBuffer(bufferSms);
      final notif = AppNotificationIO.decodeNotificationPacket(decrypted);

      expect(notif.type, equals(NotificationType.emailSms));
      expect(notif.title, equals('(416) 833-2078'));

      final reEncoded = AppNotificationIO.encodeNotificationPacket(notif);
      final reEncryptedHex = AppNotificationIO.xorEncodeBuffer(reEncoded);
      final reDecrypted = AppNotificationIO.xorDecodeBuffer(reEncryptedHex);

      final reNotif = AppNotificationIO.decodeNotificationPacket(reDecrypted);
      expect(reNotif.type, equals(notif.type));
      expect(reNotif.title, equals(notif.title));
      expect(reNotif.text, equals(notif.text));
    });

    test('decodes bufferSMS2 round-trip', () {
      final decrypted = AppNotificationIO.xorDecodeBuffer(bufferSms2);
      final notif = AppNotificationIO.decodeNotificationPacket(decrypted);

      expect(notif.type, equals(NotificationType.emailSms));
      expect(notif.title, equals('(416) 833-2078'));
    });

    test('decodes bufferGmailJapanese with unicode characters', () {
      final decrypted = AppNotificationIO.xorDecodeBuffer(bufferGmailJapanese);
      final notif = AppNotificationIO.decodeNotificationPacket(decrypted);

      expect(notif.type, equals(NotificationType.emailSms));
      expect(notif.title, equals('me'));
      expect(notif.text.isNotEmpty, isTrue);
    });

    test('rejects incomplete truncated bufferGmail with ArgumentError', () {
      final decrypted = AppNotificationIO.xorDecodeBuffer(bufferGmail);
      expect(
        () => AppNotificationIO.decodeNotificationPacket(decrypted),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('decodes bufferCalendar and bufferCalendar2 correctly', () {
      final dec1 = AppNotificationIO.xorDecodeBuffer(bufferCalendar);
      final notif1 = AppNotificationIO.decodeNotificationPacket(dec1);
      expect(notif1.type, equals(NotificationType.calendar));
      expect(notif1.title.contains('One-time'), isTrue);

      final dec2 = AppNotificationIO.xorDecodeBuffer(bufferCalendar2);
      final notif2 = AppNotificationIO.decodeNotificationPacket(dec2);
      expect(notif2.type, equals(NotificationType.calendar));
      expect(notif2.title.contains('Monday Every week forever'), isTrue);
    });

    test('decodes bufferAllDayEvent correctly', () {
      final decrypted = AppNotificationIO.xorDecodeBuffer(bufferAllDayEvent);
      final notif = AppNotificationIO.decodeNotificationPacket(decrypted);
      expect(notif.type, equals(NotificationType.calendar));
      expect(notif.title.contains('Full day event 3'), isTrue);
    });

    test('XOR encoding is self-inverse: xor(xor(buf)) == buf', () {
      final raw = Uint8List.fromList([1, 2, 3, 4, 5, 250, 255]);
      final hex = AppNotificationIO.xorEncodeBuffer(raw);
      final decoded = AppNotificationIO.xorDecodeBuffer(hex);
      expect(decoded, equals(raw));
    });
  });
}
