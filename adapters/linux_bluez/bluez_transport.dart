import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluez/bluez.dart';

import 'package:gshock_api_dart/gshock_api_dart.dart';

/// {@category Connection & Transport}
///
/// Pure-Dart Linux Bluetooth transport for desktop, Raspberry Pi, and servers.
///
/// Communicates directly with the system BlueZ daemon over D-Bus via `package:bluez`.
/// Handles pairing, connection, MTU negotiation, characteristic discovery, and notifications.
class BluezTransport implements BleTransport {
  /// Creates a Linux BlueZ transport optionally targeting [deviceAddress].
  BluezTransport({this.deviceAddress});

  String? deviceAddress;
  BlueZClient? _client;
  BlueZDevice? _device;
  final Map<String, BlueZGattCharacteristic> _characteristics =
      <String, BlueZGattCharacteristic>{};
  final Map<String, StreamSubscription<dynamic>> _subscriptions =
      <String, StreamSubscription<dynamic>>{};
  final Map<String, void Function(Uint8List)> _callbacks =
      <String, void Function(Uint8List)>{};
  bool _connected = false;
  StreamSubscription<dynamic>? _disconnectSub;

  @override
  void Function(String? reason)? onDisconnected;

  @override
  bool get isConnected => _connected && (_device?.connected ?? false);

  @override
  String? get deviceName {
    final dev = _device;
    if (dev == null) return null;
    return dev.name.isNotEmpty ? dev.name : dev.alias;
  }

  static String _normalizeUuid(String uuid) {
    final lower = uuid.toLowerCase();
    if (lower.length == 4) {
      return '0000$lower-0000-1000-8000-00805f9b34fb';
    }
    return lower;
  }

  @override
  Future<bool> connect(String address) async {
    deviceAddress = address;
    try {
      final client = BlueZClient();
      await client.connect();
      _client = client;

      if (client.adapters.isEmpty) {
        throw GShockConnectionException(
          'No Bluetooth adapter available on this system.',
        );
      }

      final adapter = client.adapters.first;
      if (!adapter.powered) {
        await adapter.setPowered(true);
      }

      final targetAddr = address.toUpperCase();
      BlueZDevice? dev = _findDevice(targetAddr);

      // If device is not already connected, wait for watch advertisement
      if (dev == null || !dev.connected) {
        final completer = Completer<BlueZDevice>();
        late final StreamSubscription<BlueZDevice> devSub;
        final propSubs = <StreamSubscription<dynamic>>[];

        void checkDevice(BlueZDevice d) {
          final addr = d.address.toUpperCase();
          final name = (d.name.isNotEmpty ? d.name : d.alias).toUpperCase();
          final isMatch =
              addr == targetAddr ||
              name.contains('CASIO') ||
              name.contains('GA-B2100');

          if (isMatch && !completer.isCompleted) {
            stdout.writeln(
              'Detected watch: "${d.name.isNotEmpty ? d.name : d.alias}" ($addr)',
            );
            completer.complete(d);
          }
        }

        // Check if any existing device already qualifies
        for (final d in client.devices) {
          if (d.connected) {
            checkDevice(d);
          }
        }

        devSub = client.deviceAdded.listen(checkDevice);
        for (final d in client.devices) {
          propSubs.add(d.propertiesChanged.listen((_) => checkDevice(d)));
        }

        if (!adapter.discovering) {
          try {
            await adapter.startDiscovery();
          } catch (_) {}
        }

        stdout.writeln('Scanning for watch broadcast (waiting up to 60s)...');

        try {
          dev = await completer.future.timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              final cached = _findDevice(targetAddr);
              if (cached != null) return cached;
              throw TimeoutException(
                'Timed out waiting for watch BLE advertisement from $address. '
                'Make sure to press the connect button on your watch.',
              );
            },
          );
        } finally {
          for (final s in propSubs) {
            await s.cancel();
          }
          await devSub.cancel();
          if (adapter.discovering) {
            try {
              await adapter.stopDiscovery();
            } catch (_) {}
          }
        }
      }

      _device = dev;
      stdout.writeln(
        'Connecting to ${dev.name.isNotEmpty ? dev.name : dev.alias} (${dev.address})...',
      );

      if (!dev.connected) {
        await dev.connect();
      }
      stdout.writeln('Bluetooth link connected. Resolving GATT services...');

      // Wait for GATT services to resolve
      if (!dev.servicesResolved) {
        final resolvedCompleter = Completer<void>();
        final sub = dev.propertiesChanged.listen((props) {
          if (dev!.servicesResolved && !resolvedCompleter.isCompleted) {
            resolvedCompleter.complete();
          }
        });
        await resolvedCompleter.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            gshockLogger.warning(['ServicesResolved timeout on $address']);
          },
        );
        await sub.cancel();
      }
      stdout.writeln('GATT services resolved successfully.');

      _connected = true;

      // Monitor for remote disconnection
      final activeDev = dev;
      _disconnectSub?.cancel();
      _disconnectSub = activeDev.propertiesChanged.listen((_) {
        if (_connected && !activeDev.connected) {
          _connected = false;
          gshockLogger.info(['[BlueZ] Watch disconnected.']);
          onDisconnected?.call('BlueZ device disconnected');
        }
      });

      return true;
    } catch (e) {
      gshockLogger.warning(['Linux BlueZ connection failed: $e']);
      await disconnect();
      return false;
    }
  }

  BlueZDevice? _findDevice(String addressUpper) {
    final client = _client;
    if (client == null) return null;
    for (final dev in client.devices) {
      if (dev.address.toUpperCase() == addressUpper) {
        return dev;
      }
    }
    return null;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _disconnectSub?.cancel();
    _disconnectSub = null;

    for (final sub in _subscriptions.values) {
      await sub.cancel();
    }
    _subscriptions.clear();
    _callbacks.clear();
    _characteristics.clear();

    final dev = _device;
    if (dev != null && dev.connected) {
      try {
        await dev.disconnect();
      } catch (_) {}
    }
    _device = null;

    final client = _client;
    if (client != null) {
      try {
        await client.close();
      } catch (_) {}
      _client = null;
    }
    _connected = false;
  }

  @override
  Future<Map<String, bool>> discoverCharacteristics() async {
    final dev = _device;
    if (dev == null) {
      throw GShockConnectionException('No device connected for discovery');
    }

    final result = <String, bool>{};
    _characteristics.clear();

    for (final service in dev.gattServices) {
      for (final char in service.characteristics) {
        final uuid = _normalizeUuid(char.uuid.toString());
        _characteristics[uuid] = char;
        final canNotify =
            char.flags.contains(BlueZGattCharacteristicFlag.notify) ||
            char.flags.contains(BlueZGattCharacteristicFlag.indicate);
        result[uuid] = canNotify;
      }
    }

    // Ensure all standard Casio characteristics are mapped
    return result;
  }

  @override
  Future<void> subscribe(String uuid, void Function(Uint8List) onData) async {
    final normUuid = _normalizeUuid(uuid);
    final char = _characteristics[normUuid];
    if (char == null) {
      gshockLogger.warning(['Characteristic $uuid not found for subscribe']);
      return;
    }

    _callbacks[normUuid] = onData;

    try {
      if (!char.notifying) {
        await char.startNotify();
      }
      await _subscriptions[normUuid]?.cancel();
      _subscriptions[normUuid] = char.propertiesChanged.listen((props) {
        if (props.contains('Value')) {
          final data = Uint8List.fromList(char.value);
          _callbacks[normUuid]?.call(data);
        }
      });
    } catch (e) {
      gshockLogger.warning(['Failed to subscribe to $uuid: $e']);
    }
  }

  @override
  Future<void> write(
    String uuid,
    Uint8List data, {
    required bool withResponse,
  }) async {
    final normUuid = _normalizeUuid(uuid);
    final char = _characteristics[normUuid];
    if (char == null) {
      throw GShockConnectionException(
        'Characteristic $uuid not found for write',
      );
    }

    try {
      await char.writeValue(
        data,
        type: withResponse
            ? BlueZGattCharacteristicWriteType.request
            : BlueZGattCharacteristicWriteType.command,
      );
    } catch (e) {
      throw GShockConnectionException('BlueZ GATT write failed for $uuid: $e');
    }
  }

  /// Dispatches a notification byte buffer received from the watch.
  void handleIncomingNotification(String uuid, Uint8List data) {
    _callbacks[_normalizeUuid(uuid)]?.call(data);
  }
}

/// {@category Connection & Transport}
///
/// Linux BLE scanner using `package:bluez` over the system D-Bus.
///
/// Scans for Bluetooth Low Energy devices advertising the Casio service UUID (`0x1804`)
/// or matching watch names.
class BluezScanner implements GshockScanner {
  /// Creates a const [BluezScanner] instance.
  const BluezScanner();

  @override
  Future<BleDevice?> scan({
    String? deviceAddress,
    bool Function(String name)? watchFilter,
    int? maxRetries = 3,
    Duration? timeout = const Duration(seconds: 30),
  }) async {
    final client = BlueZClient();
    try {
      await client.connect();
      if (client.adapters.isEmpty) {
        return null;
      }

      final adapter = client.adapters.first;
      if (!adapter.powered) {
        await adapter.setPowered(true);
      }

      final completer = Completer<BleDevice?>();

      bool checkDevice(BlueZDevice dev) {
        final addr = dev.address.toUpperCase();
        final name = dev.name.isNotEmpty ? dev.name : dev.alias;

        if (deviceAddress != null) {
          if (addr == deviceAddress.toUpperCase()) {
            if (!completer.isCompleted) {
              completer.complete(BleDevice(name: name, address: dev.address));
            }
            return true;
          }
          return false;
        }

        // Generic discovery for CASIO watches
        final matchesCasio =
            name.toUpperCase().contains('CASIO') ||
            dev.uuids.any((u) => u.toString().toLowerCase().contains('1804'));

        if (matchesCasio && (watchFilter == null || watchFilter(name))) {
          if (!completer.isCompleted) {
            completer.complete(BleDevice(name: name, address: dev.address));
          }
          return true;
        }
        return false;
      }

      // Check existing connected devices first
      for (final dev in client.devices) {
        if (dev.connected && checkDevice(dev)) {
          break;
        }
      }

      if (!completer.isCompleted) {
        final devSub = client.deviceAdded.listen(checkDevice);
        final propSubs = <StreamSubscription<dynamic>>[];
        for (final dev in client.devices) {
          propSubs.add(dev.propertiesChanged.listen((_) => checkDevice(dev)));
        }

        if (!adapter.discovering) {
          try {
            await adapter.startDiscovery();
          } catch (_) {}
        }

        final result = await completer.future.timeout(
          timeout ?? const Duration(seconds: 30),
          onTimeout: () => null,
        );

        for (final s in propSubs) {
          await s.cancel();
        }
        await devSub.cancel();

        if (adapter.discovering) {
          try {
            await adapter.stopDiscovery();
          } catch (_) {}
        }

        return result;
      } else {
        return await completer.future;
      }
    } catch (e) {
      gshockLogger.warning(['BluezScanner error: $e']);
      return null;
    } finally {
      await client.close();
    }
  }
}
