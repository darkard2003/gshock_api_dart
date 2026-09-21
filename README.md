# G-Shock API for Dart & Flutter

[![pub package](https://img.shields.io/pub/v/gshock_api_dart.svg)](https://pub.dev/packages/gshock_api_dart)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A cross-platform Dart and Flutter library for communicating with Casio G-Shock Bluetooth Low Energy (BLE) watches.

Provides full feature support including automatic time synchronization, alarms, countdown timers, reminders, battery and temperature telemetry, step counting and activity logs, app notification forwarding, and watch configuration settings.

---

## Key Features

- **Pure-Dart Core Engine**: All packet codecs, protocol state machines, Casio timezone tables, models, and dispatcher logic are pure Dart (`dart:typed_data`, `dart:async`, and `package:timezone`). Runs headless in CI, backend server daemons, Raspberry Pi, desktop, and Flutter mobile apps.
- **Pluggable BLE Hardware Transports**: Connect to watches using the transport best suited for your platform:
  - **Flutter (Android, iOS, macOS)**: Drop-in adapters powered by [`flutter_blue_plus`](https://pub.dev/packages/flutter_blue_plus) (available under `flutter_adapter/`).
  - **Linux (Desktop, Raspberry Pi, Servers)**: Native D-Bus transport powered by `package:bluez` (no Flutter or external CLI wrappers required).
  - **Testing & Simulation**: Built-in `MockTransport` and `MockScanner` with recorded watch packet fixtures for fast, deterministic unit and integration tests.
- **Adaptive Protocol Negotiation**: Automatically detects watch capabilities and selects the correct communication strategy:
  - **Standard Protocol**: GW-B5600, DW-B5600, GA-B2100, GM-B2100, GST-B100, etc.
  - **MIP Protocol**: GW-BX5600, GMW-BZ5000 (special 4-step SP configuration flow over handles `0x17`/`0x19`).
  - **Analogue Multi-Dial Protocol**: MTG-B1000 (second-dial reset sequence), MTG-B3000 (12-byte settings, 15-byte timer, `0x24` home times).
  - **Lifelog / Step Counter Protocol**: ABL-100WE, F-B100W (DRSP `0x11` and Convoy `0x14` fragmentation streaming).

---

## Supported Watch Models

| Model Series | Protocol | Key Features Supported |
|---|---|---|
| **GW-B5600 / GMW-B5000** | Standard | Time sync, World Cities, Alarms, Timer, Reminders, Battery |
| **GA-B2100 / GM-B2100** | Standard | Time sync, World Cities, Alarms, Timer, Battery & Temp |
| **DW-B5600** | Standard | Time sync, Alarms, Timer, Basic Settings |
| **GW-BX5600 / GMW-BZ5000** | MIP | 4-step SP configuration, World Cities, Alarms, Timer |
| **MTG-B1000** | Analogue | Second-dial alignment, Alarms, Timer, Battery |
| **MTG-B3000** | Analogue | 12-byte settings, 15-byte timer, Home Time `0x24` |
| **ABL-100WE / F-B100W** | Standard + Lifelog | Step counting, Daily history & 15-minute activity bins |

---

## Getting Started

### Installation

Add `gshock_api_dart` from [pub.dev](https://pub.dev/packages/gshock_api_dart):

```bash
# Dart projects
dart pub add gshock_api_dart

# Flutter projects
flutter pub add gshock_api_dart
```

Or add it directly to your `pubspec.yaml`:

```yaml
dependencies:
  gshock_api_dart: ^0.0.1
```

If you are building a **Flutter** app, also add `flutter_blue_plus`:

```bash
flutter pub add flutter_blue_plus
```

---

## Quickstart

### 1. Minimal Time Sync (Linux / Desktop)

```dart
import 'package:gshock_api_dart/gshock_api_dart.dart';

Future<void> main() async {
  // Setup Linux BlueZ transport (connects to any Casio watch or a target MAC)
  final connection = GshockConnection(
    transport: BluezTransport(),
    scanner: const BluezScanner(),
  );

  print('Press the lower-right button on your G-Shock to connect...');
  final connected = await connection.connect(
    timeout: const Duration(seconds: 45),
  );
  if (!connected) {
    print('Failed to connect to watch.');
    return;
  }

  final api = GshockApi(connection);
  print('Connected to: ${await api.getWatchName()}');

  // Synchronize clock to the current system time
  await api.setTime();
  print('Time synchronized successfully!');

  // Read telemetry (battery percentage & temperature)
  final condition = await api.getWatchCondition();
  print('Battery: ${condition['battery_level_percent']}%, Temp: ${condition['temperature']}°C');

  await connection.disconnect();
  api.reset();
}
```

### 2. Flutter Mobile Application

Copy or import the adapters in `flutter_adapter/`:

```dart
import 'package:flutter/material.dart';
import 'package:gshock_api_dart/gshock_api_dart.dart';
import 'flutter_adapter/flutter_blue_plus_transport.dart';
import 'flutter_adapter/flutter_blue_plus_scanner.dart';

Future<void> syncWatchFromFlutter() async {
  final connection = GshockConnection(
    transport: FlutterBluePlusTransport(),
    scanner: const FlutterBluePlusScanner(),
  );

  // Listen for spontaneous remote watch disconnections
  connection.onDisconnected = (reason) {
    print('Watch disconnected: $reason');
  };

  // Scan and connect to nearby Casio G-Shock
  final connected = await connection.connect(
    timeout: const Duration(seconds: 30),
  );
  if (!connected) return;

  final api = GshockApi(connection);

  // Read watch info and sync time
  final watchName = await api.getWatchName();
  final battery = await api.getWatchCondition();
  await api.setTime();

  print('Synced $watchName (Battery: ${battery['battery_level_percent']}%)');

  await connection.disconnect();
  api.reset();
}
```

---

## Feature Guide

### Time & Timezone Synchronization

Synchronize the watch with the local system time or specify an explicit IANA timezone and fine adjustment offset in seconds:

```dart
// Auto-detect system local time and IANA timezone:
await api.setTime();

// Explicit timezone and fine offset (+2 seconds):
await api.setTime(timezone: 'Europe/London', offset: 2);
```

### Battery Status & Temperature

Read battery charge level and temperature telemetry from the watch sensor:

```dart
final condition = await api.getWatchCondition();
final int batteryPercent = condition['battery_level_percent'] ?? 0;
final int temperature = condition['temperature'] ?? 0;
print('Battery: $batteryPercent% | Temperature: ${temperature}°C');
```

### Alarms & Hourly Chime

Read and configure watch alarms and hourly time signal (chime):

```dart
// Read current alarms
final alarms = await api.getAlarms();
for (var i = 0; i < alarms.length; i++) {
  print('Alarm #${i + 1}: ${alarms[i].hour}:${alarms[i].minute} (enabled=${alarms[i].enabled})');
}

// Enable 7:30 AM alarm with hourly chime
alarms[0] = alarms[0].copyWith(
  hour: 7,
  minute: 30,
  enabled: true,
  hasHourlyChime: true,
);
await api.setAlarms(alarms);
```

### Countdown Timer

Read and set the countdown timer duration (hours, minutes, seconds):

```dart
// Read countdown timer duration
final int currentSeconds = await api.getTimer();
print('Current timer duration: ${currentSeconds}s');

// Set timer to 15 minutes (900 seconds)
await api.setTimer(15 * 60);
```

### Reminders & Calendar Events

Program calendar reminders with specific recurrence periods:

```dart
final reminder = Event(
  title: 'Project Launch',
  startDate: EventDate(year: 2026, month: 9, day: 25),
  endDate: EventDate(year: 2026, month: 9, day: 25),
  period: RepeatPeriod.never,
  enabled: true,
);

await api.setReminders([reminder]);
```

### Step Counter & Lifelog History

Retrieve daily step counts and 15-minute intraday activity histograms for step-tracking models (such as `ABL-100WE`):

```dart
// Query step count data without ending BLE transaction
final StepCounterData data = await api.getStepCount(peek: false);
print('Steps today: ${data.stepCount}');

for (final day in data.dailySteps) {
  print('${day.date}: ${day.steps} steps');
}
```

### App Notifications

Push encrypted notifications (SMS, Email, Calendar, or Custom app alerts) to supported watches:

```dart
final notification = AppNotification(
  type: NotificationType.sms,
  title: 'Alex',
  body: 'Meeting at 3pm',
);

await api.sendAppNotification(notification);
```

---

## Background Time Sync Daemon (`gshock_server.dart`)

The repository includes a ready-to-run background synchronization daemon for Linux systems (Raspberry Pi, desktop, home servers) that waits for your watch's button press or automatic scheduled connection:

```bash
dart run example/gshock_server.dart [options]
```

### CLI Options:

| Flag | Description | Default |
|---|---|---|
| `--address <MAC>` | Lock to a specific watch MAC address (e.g. `DC:17:9B:0B:87:29`) | Any Casio watch |
| `--timezone <TZ>` | Target IANA timezone (e.g. `Europe/London`, `Asia/Kolkata`) | System local |
| `--offset <seconds>` | Fine second adjustment offset | `0` |
| `--log-file <path>` | Append structured logs to a specified file | Console only |
| `-v, --verbose` | Enable debug logs and raw packet diagnostics | Disabled |
| `--mock` | Run in simulation mode without hardware | Disabled |

#### Example Log Output:

```text
[2026-09-19 22:48:32.813] [INFO ] Initializing G-Shock Time Server...
[2026-09-19 22:48:32.820] [INFO ] Config: target=DC:17:9B:0B:87:29, offset=0s, timezone=Asia/Kolkata
[2026-09-19 22:48:35.120] [INFO ] Discovered watch: "CASIO GA-B2100" (DC:17:9B:0B:87:29)
[2026-09-19 22:48:35.340] [INFO ] Bluetooth link connected. Resolving GATT services...
[2026-09-19 22:48:35.890] [INFO ] Sync initiated by button: WatchButton.lowerRight
[2026-09-19 22:48:35.910] [INFO ] Watch identified: CASIO GA-B2100 (Protocol: StandardProtocol)
[2026-09-19 22:48:36.010] [INFO ] Time set successfully at 2026-09-19 22:48:36 on CASIO GA-B2100
[2026-09-19 22:48:36.050] [INFO ] Telemetry status: Battery 100%, Temperature 34°C
[2026-09-19 22:48:36.120] [INFO ] Watch disconnected cleanly. Standing by for next sync event...
```

---

## Platform Permissions Guide

### Android (`android/app/src/main/AndroidManifest.xml`)

```xml
<!-- Bluetooth permissions for Android 12+ (API 31+) -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

<!-- Legacy Bluetooth permissions for Android 11 and lower -->
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
```

### iOS (`ios/Runner/Info.plist`)

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Required to connect and synchronize with your Casio G-Shock watch.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Required to connect to your Casio G-Shock watch.</string>
```

### macOS (`macos/Runner/DebugProfile.entitlements` & `Release.entitlements`)

```xml
<key>com.apple.security.device.bluetooth</key>
<true/>
```

---

## Repository Structure

```
gshock_api_dart/
├── lib/
│   ├── gshock_api_dart.dart                 # Main package exports
│   └── src/
│       ├── api/gshock_api.dart              # High-level GshockApi facade
│       ├── connection/                      # Connection protocol, BlueZ D-Bus, MockTransport
│       ├── constants/casio_constants.dart   # BLE UUIDs, handles, and command codes
│       ├── dispatcher/message_dispatcher.dart # Command dispatching & notification router
│       ├── io/                              # Feature IO codecs (Alarms, Timer, Events, etc.)
│       ├── model/                           # Value objects (Alarms, Event, Settings, WatchInfo)
│       ├── protocols/                       # WatchProtocol implementations (Standard, MIP, Analogue)
│       ├── timezone/casio_time_zone_helper.dart # 41-zone Casio timezone database
│       └── util/                            # Bytes, CancelableResult, GshockLogger
├── flutter_adapter/                         # Drop-in Flutter BLE adapter layer
│   ├── flutter_blue_plus_transport.dart
│   ├── flutter_blue_plus_scanner.dart
│   └── example_flutter_screen.dart
├── example/                                 # Ready-to-run example programs
│   ├── sync_time_simple.dart                # Minimal 40-line clock synchronization
│   ├── alarms_and_timer.dart                # Reading/setting alarms and countdown timer
│   ├── reminders_simple.dart                # Managing reminders and calendar slots
│   ├── gshock_server.dart                   # Background time sync service daemon
│   ├── step_counter.dart                    # Lifelog and step histogram reporter
│   ├── app_notifications.dart               # Notification packet encoder and XOR cipher
│   └── api_tests.dart                       # Comprehensive interactive API test suite
└── test/                                    # Unit, integration, and packet replay tests
```

---

## Testing & Verification

Run static analysis and the full test suite:

```bash
# Analyze codebase (0 issues)
dart analyze

# Run all unit and integration tests (240 passing tests)
dart test

# Run examples in mock simulation mode (no watch needed)
dart run example/sync_time_simple.dart --mock
dart run example/alarms_and_timer.dart --mock
dart run example/reminders_simple.dart --mock
dart run example/gshock_server.dart --mock
```

---

## Authors & Acknowledgments

- **Dart & Flutter Implementation**: [Kaushik Chowdhury (darkard2003)](https://github.com/darkard2003)
- **Original Python Library**: [Ivo Zivkov](https://github.com/izivkov) ([`izivkov/gshock_api`](https://github.com/izivkov/gshock_api))

Special thanks to the Casio reverse-engineering community for documenting the BLE packet structures and protocol dialects.

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

```text
Portions copyright (c) 2026 Kaushik Chowdhury (darkard2003) (Dart port)
Portions copyright (c) 2023 Ivo Zivkov (Original Python implementation)
```
