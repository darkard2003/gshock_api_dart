/// Connection interface mirroring
/// `gshock_api/src/gshock_api/iolib/connection_protocol.py`.
abstract class ConnectionProtocol {
  /// Sends a read request for [code] using the read-request characteristic.
  Future<void> request(Object code);

  /// Writes [data] (bytes or compact hex string) to [handle].
  Future<void> write(int handle, Object data);

  /// Dispatches a JSON action [message] through the message dispatcher.
  Future<void> sendMessage(Object message);
}
