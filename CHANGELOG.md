## 0.0.1

- Initial release of pure-Dart G-Shock BLE library.
- Multi-protocol support: Standard, MIP (GW-BX5600/GMW-BZ5000 4-step SP), Analogue (MTG-B1000/MTG-B3000), and Lifelog (ABL-100WE step counter).
- Comprehensive feature set: automatic time sync, world cities & DST, alarms, countdown timer, reminders, battery & temperature telemetry, and encrypted app notifications.
- Pluggable BLE transports: Linux BlueZ (`package:bluez`), Flutter (`flutter_blue_plus`), and `MockTransport` for deterministic testing.
- Verified byte-for-byte wire parity with Python `gshock_api` reference implementation.
