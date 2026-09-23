# Flutter Adapter for G-Shock API

This folder contains the concrete hardware BLE adapters connecting `gshock_api_dart` to real Bluetooth devices using the popular [`flutter_blue_plus`](https://pub.dev/packages/flutter_blue_plus) package.

## Setup in your Flutter App

### 1. Add Dependencies to your `pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter
  gshock_api_dart: ^0.1.0
  flutter_blue_plus: ^1.35.0
```

### 2. Configure Permissions

#### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<!-- Required for Bluetooth LE -->
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />

<!-- Android 12+ (API 31+) -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

#### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app requires Bluetooth to connect and synchronize with your Casio G-Shock watch.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app requires Bluetooth to connect to your G-Shock watch.</string>
```

#### macOS (`macos/Runner/DebugProfile.entitlements` and `Release.entitlements`)
```xml
<key>com.apple.security.device.bluetooth</key>
<true/>
```

---

## 3. Usage Example

```dart
import 'package:flutter/material.dart';
import 'package:gshock_api_dart/gshock_api_dart.dart';
import 'flutter_blue_plus_transport.dart';
import 'flutter_blue_plus_scanner.dart';

Future<void> connectToWatch() async {
  final transport = FlutterBluePlusTransport();
  final scanner = FlutterBluePlusScanner();

  final connection = GshockConnection(
    transport: transport,
    scanner: scanner,
  );

  print('Scanning for watch... Hold the lower-left button on your G-Shock for 3 seconds.');
  final connected = await connection.connect();

  if (!connected) {
    print('Could not find or connect to watch.');
    return;
  }

  final api = GshockApi(connection);
  final name = await api.getWatchName();
  final condition = await api.getWatchCondition();
  print('Connected to $name! Battery condition: $condition');

  // Sync time to current time
  await api.setTime();

  await connection.disconnect();
  api.reset();
}
```
