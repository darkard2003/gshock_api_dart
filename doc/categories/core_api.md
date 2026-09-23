# Core API

The Core API provides the primary developer facade and connection primitives for communicating with Casio G-Shock Bluetooth watches.

## Key Classes
- `GshockApi`: High-level facade for watch operations (syncing time, setting alarms, querying battery, reading step counts, sending app notifications, and listening to button events).
- `GshockConnection`: Logical BLE connection handling handle-to-UUID translation, notification routing, and write-without-response modes.
- `GshockScanner`: Device discovery interface.
- `BleDevice`: Discovered Bluetooth Low Energy peripheral model.
- `BleTransport`: Low-level BLE interface injected into `GshockConnection` (e.g. Flutter Blue Plus, Linux BlueZ, or Mock).
