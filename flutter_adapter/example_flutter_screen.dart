import 'package:flutter/material.dart';
import 'package:gshock_api_dart/gshock_api_dart.dart';

import 'flutter_blue_plus_scanner.dart';
import 'flutter_blue_plus_transport.dart';

/// Sample Flutter screen demonstrating connection and feature interactions
/// with a Casio G-Shock watch using [GshockApi] and [FlutterBluePlusTransport].
class GshockWatchScreen extends StatefulWidget {
  const GshockWatchScreen({super.key});

  @override
  State<GshockWatchScreen> createState() => _GshockWatchScreenState();
}

class _GshockWatchScreenState extends State<GshockWatchScreen> {
  GshockConnection? _connection;
  GshockApi? _api;

  bool _isConnecting = false;
  String _status = 'Disconnected';
  String? _watchName;
  String? _batteryLevel;
  int? _stepsToday;

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
      _status = 'Scanning for watch (hold lower-left button)...';
    });

    try {
      final transport = FlutterBluePlusTransport();
      final scanner = FlutterBluePlusScanner();
      final conn = GshockConnection(transport: transport, scanner: scanner);

      final connected = await conn.connect(
        timeout: const Duration(seconds: 15),
      );

      if (!connected) {
        setState(() {
          _isConnecting = false;
          _status = 'Watch not found or connection rejected.';
        });
        return;
      }

      final api = GshockApi(conn);
      _connection = conn;
      _api = api;

      setState(() => _status = 'Reading watch info...');

      final name = await api.getWatchName();
      final condition = await api.getWatchCondition();
      int? steps;
      try {
        steps = await api.getStepCountToday();
      } catch (_) {
        // Step counter not supported on all models
      }

      setState(() {
        _isConnecting = false;
        _status = 'Connected';
        _watchName = name;
        _batteryLevel = condition['battery_level']?.toString() ?? 'Unknown';
        _stepsToday = steps;
      });
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _syncTime() async {
    if (_api == null) return;
    setState(() => _status = 'Setting time to current clock...');
    try {
      await _api!.setTime();
      setState(() => _status = 'Time synchronized successfully!');
    } catch (e) {
      setState(() => _status = 'Failed to set time: $e');
    }
  }

  Future<void> _disconnect() async {
    if (_connection == null) return;
    await _connection!.disconnect();
    _api?.reset();
    setState(() {
      _connection = null;
      _api = null;
      _status = 'Disconnected';
      _watchName = null;
      _batteryLevel = null;
      _stepsToday = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isConnected =
        _connection != null && _connection!.transport.isConnected;

    return Scaffold(
      appBar: AppBar(title: const Text('G-Shock Controller')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Status: $_status',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (_watchName != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Watch: $_watchName',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                    if (_batteryLevel != null) ...[
                      const SizedBox(height: 8),
                      Text('Battery: $_batteryLevel'),
                    ],
                    if (_stepsToday != null) ...[
                      const SizedBox(height: 8),
                      Text('Steps Today: $_stepsToday'),
                    ],
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (!isConnected)
              ElevatedButton(
                onPressed: _isConnecting ? null : _connect,
                child: _isConnecting
                    ? const CircularProgressIndicator.adaptive()
                    : const Text('Connect to G-Shock'),
              )
            else ...[
              ElevatedButton(
                onPressed: _syncTime,
                child: const Text('Sync Time to Phone'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _disconnect,
                child: const Text('Disconnect'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
