import 'dart:typed_data';

/// Packet ADTs mirroring `gshock_api/src/gshock_api/iolib/packet.py`.

/// Characteristic protocol/feature codes.
/// @nodoc
enum Protocol {
  appInfo(0x22),
  watchName(0x23),
  bleFeatures(0x10),
  settingForBle(0x11),
  advertiseParameterManager(0x3B),
  connectionParameterManager(0x3A),
  moduleId(0x26),
  watchCondition(0x28),
  versionInformation(0x20),
  dstWatchState(0x1D),
  dstSetting(0x1E),
  serviceDiscoveryManager(0x47),
  currentTime(0x09),
  settingForUserProfile(0x45),
  settingForTargetValue(0x43),
  alertLevel(0x0A),
  settingForAlm(0x15),
  settingForAlm2(0x16),
  settingForBasic(0x13),
  currentTimeManager(0x39),
  worldCities(0x1F),
  reminderTitle(0x30),
  reminderTime(0x31),
  timer(0x18),
  error(0xFF),
  unknown(0x0A),
  cmdSetTimeMode(0x47),
  findPhone(0x0A);

  const Protocol(this.value);

  final int value;

  /// Returns the enum constant for [value] or `null` if unknown.
  static Protocol? fromValue(int value) {
    for (final p in Protocol.values) {
      if (p.value == value) return p;
    }
    return null;
  }
}

/// Packet header.
/// @nodoc
class Header {
  Header({required this.protocol, required this.size});

  final Protocol protocol;
  final int size;
}

/// Packet payload.
/// @nodoc
class Payload {
  Payload({required this.data});

  final Uint8List data;
}

/// Packet trailer.
/// @nodoc
class Trailer {
  Trailer({required this.data, required this.checksum});

  final Uint8List data;
  final int checksum;
}
