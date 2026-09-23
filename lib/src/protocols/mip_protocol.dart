import '../io/connection_protocol.dart';
import '../io/gw_bx5600_time_io.dart';
import 'standard_protocol.dart';

/// {@category Protocols & Constants}
///
/// Protocol implementation for Memory-in-Pixel (MIP) watches (GW-BX5600, GMW-BZ5000).
///
/// Overrides [setTime] to drive Casio's 4-step SP configuration handshake
/// over characteristic handles `0x17` and `0x19`.
class MipProtocol extends StandardProtocol {
  @override
  Future<void> setTime(
    ConnectionProtocol connection, {
    double? currentTime,
    int offset = 0,
  }) => GwBx5600TimeIO.request(connection, currentTime, offset);
}
