import '../io/connection_protocol.dart';
import '../io/gw_bx5600_time_io.dart';
import 'standard_protocol.dart';

/// Protocol for MIP display watches such as the GW-BX5600.
class MipProtocol extends StandardProtocol {
  @override
  Future<void> setTime(
    ConnectionProtocol connection, {
    double? currentTime,
    int offset = 0,
  }) => GwBx5600TimeIO.request(connection, currentTime, offset);
}
