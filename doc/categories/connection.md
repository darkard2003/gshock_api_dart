# Connection & Transport

Provides transport abstractions, logical handle routing, scanning, and platform BLE integrations.

## Overview
Casio G-Shock watches communicate over proprietary BLE characteristics using fixed 16-bit handles. The connection layer bridges high-level feature requests to low-level BLE writes and notification listeners.

## Components
- `GshockConnection`: Central connection coordinator. Manages the handle map, no-response write modes, and notification dispatching.
- `BleTransport`: Abstract contract for underlying Bluetooth platforms (with reference adapters for Flutter and Linux BlueZ in `adapters/`).
- `MockTransport`: In-memory BLE transport double for tests without hardware.
- `AlwaysConnectedWatchFilter`: Throttling mechanism for watches that maintain permanent BLE connections (ECB-30, ECB-10, EQB-1000).
