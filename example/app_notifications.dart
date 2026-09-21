import 'dart:io';

import 'package:gshock_api_dart/gshock_api_dart.dart';

void main(List<String> args) async {
  final isMock = args.contains('--mock');

  stdout.writeln('=== G-Shock App Notifications Example ===\n');

  // 1. Create a notification model
  final notification = AppNotification(
    type: NotificationType.message,
    timestamp: '20260919T143000',
    app: 'Messages',
    title: 'Alice',
    text: 'Meeting at 3:00 PM today. Let me know if you are free!',
    shortText: 'Meeting 3PM',
  );

  stdout.writeln('Created AppNotification:');
  stdout.writeln('  Type: ${notification.type}');
  stdout.writeln('  Timestamp: ${notification.timestamp}');
  stdout.writeln('  App: ${notification.app}');
  stdout.writeln('  Title: ${notification.title}');
  stdout.writeln('  Text: ${notification.text}');
  stdout.writeln('  Short Text: ${notification.shortText}\n');

  // 2. Encode to length-prefixed packet
  final rawPacket = AppNotificationIO.encodeNotificationPacket(notification);
  stdout.writeln('Encoded packet length: ${rawPacket.length} bytes');

  // 3. Encrypt via XOR-255 cipher for BLE handle 0x0D
  final encryptedHex = AppNotificationIO.xorEncodeBuffer(rawPacket);
  stdout.writeln('Encrypted buffer for handle 0x0D:\n  $encryptedHex\n');

  // 4. Verify round-trip decryption
  final decrypted = AppNotificationIO.xorDecodeBuffer(encryptedHex);
  final decodedNotif = AppNotificationIO.decodeNotificationPacket(decrypted);
  stdout.writeln('Decoded notification from wire:');
  stdout.writeln('  Title: ${decodedNotif.title}');
  stdout.writeln('  Text: ${decodedNotif.text}');

  if (!isMock) {
    stdout.writeln(
      '\nTo send to a live watch, use GshockApi.sendAppNotification(notification).',
    );
  }
}
