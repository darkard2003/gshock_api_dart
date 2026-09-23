## 0.1.0

- Decoupled platform hardware transports into reference `adapters/` directory (`adapters/flutter_blue_plus/` and `adapters/linux_bluez/`).
- Achieved 100% pure-Dart core with zero native OS dependencies (`package:timezone` only).
- Verified full 6-platform compatibility (iOS, Android, Web, Windows, macOS, Linux) + WASM runtime readiness on pub.dev (150/150 pana score).
- Added comprehensive Dart Doc documentation with 6 structured categories and zero warnings.
- Preserved 100% byte-level wire parity across 240 unit/integration tests and all watch models.

## 0.0.1

- Initial release of pure-Dart G-Shock BLE library.
- Multi-protocol support: Standard, MIP (GW-BX5600/GMW-BZ5000 4-step SP), Analogue (MTG-B1000/MTG-B3000), and Lifelog (ABL-100WE step counter).
- Comprehensive feature set: automatic time sync, world cities & DST, alarms, countdown timer, reminders, battery & temperature telemetry, and encrypted app notifications.
- Pluggable BLE transports: Linux BlueZ (`package:bluez`), Flutter (`flutter_blue_plus`), and `MockTransport` for deterministic testing.
- Verified byte-for-byte wire parity with Python `gshock_api` reference implementation.
