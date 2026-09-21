import 'dart:typed_data';

/// BLE action ADT mirroring `gshock_api/src/gshock_api/iolib/actions.py`.
sealed class BleAction {
  const BleAction();
}

/// A write to a BLE handle.
class WriteAction extends BleAction {
  const WriteAction({required this.handle, required this.data});

  final int handle;
  final Uint8List data;

  @override
  String toString() => 'WriteAction(0x${handle.toRadixString(16)}, $data)';
}

/// A read from a BLE handle.
class ReadAction extends BleAction {
  const ReadAction({required this.handle});

  final int handle;

  @override
  String toString() => 'ReadAction(0x${handle.toRadixString(16)})';
}
