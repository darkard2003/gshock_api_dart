# Linux BlueZ D-Bus Adapter for G-Shock API

This folder contains the native Linux BLE transport and scanner connecting `gshock_api_dart` directly to the system BlueZ daemon over D-Bus via [`package:bluez`](https://pub.dev/packages/bluez).

## Setup in your Linux Dart Project

### 1. Add Dependencies to your `pubspec.yaml`

```yaml
dependencies:
  gshock_api_dart: ^0.1.0
  bluez: ^0.8.3
```

### 2. Copy or Reference `bluez_transport.dart`

Copy `bluez_transport.dart` into your project's `lib/` or `src/` directory.

### 3. Usage Example

```dart
import 'package:gshock_api_dart/gshock_api_dart.dart';
import 'bluez_transport.dart';

Future<void> main() async {
  final connection = GshockConnection(
    transport: BluezTransport(),
    scanner: const BluezScanner(),
  );

  print('Press the lower-left button on your G-Shock to connect...');
  final connected = await connection.connect(
    timeout: const Duration(seconds: 45),
  );
  if (!connected) {
    print('Failed to connect to watch.');
    return;
  }

  final api = GshockApi(connection);
  print('Connected to: ${await api.getWatchName()}');

  // Synchronize clock to current system time
  await api.setTime();
  print('Time synchronized successfully!');

  await connection.disconnect();
  api.reset();
}
```
