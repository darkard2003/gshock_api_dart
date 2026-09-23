# Utilities & Exceptions

Byte manipulation, async notification primitives, logging, and error handling.

## Components
- `Bytes`: High-performance byte manipulation, hex encoding/decoding, bit masking, and endianness helpers.
- `CancelableResult`: Register-before-write async primitive for awaiting BLE notifications with timeout and cancellation support.
- `GshockLogger` & `GshockLogLevel`: Configurable zero-allocation logging sink.
- `GShockException`: Base exception for watch errors.
- `GShockConnectionException`: Raised when connection or BLE transport operations fail.
