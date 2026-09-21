import 'dart:typed_data';

import 'package:gshock_api_dart/gshock_api_dart.dart';

/// A scriptable G-Shock watch simulator for end-to-end migration tests.
///
/// Wraps [MockTransport] and automatically answers BLE writes with the same
/// wire behavior as a real watch (as observed in the Python implementation):
///
/// * writes to the read-request characteristic (handle 0x0C) are answered
///   with a notification on the notification characteristic (handle 0x0D),
///   keyed by the feature code (first payload byte);
/// * DRSP transaction starts (handle 0x11) announce the expected payload
///   length and deliver the step-counter payload over Convoy;
/// * GW-BX5600 SP requests (handle 0x17) are answered on SP data (0x19) with
///   the exact byte lengths of each of the four time-set steps.
///
/// Every write is recorded (see [writesTo]) so tests can assert the exact
/// bytes and handles the Dart library put on the wire.
class FakeWatch {
  FakeWatch({
    this.advertisedName = 'CASIO GW-B5600',
    this._worldCitiesCount = 6,
    this._stepCounterPayload,
  }) {
    transport = SimulatingTransport(this);
  }

  /// The name this watch advertises (registers the model on connect).
  final String advertisedName;

  final int _worldCitiesCount;
  final List<int>? _stepCounterPayload;

  /// The simulated BLE transport (records every write).
  late final SimulatingTransport transport;

  /// Auto-responses for read-requests, keyed by feature code (first byte).
  final Map<int, List<int>> readResponses = <int, List<int>>{};

  GshockConnection? _connection;

  static String get _readRequestUuid =>
      CasioConstants.casioReadRequestForAllFeaturesCharacteristicUuid;

  static String get _notificationUuid =>
      CasioConstants.casioNotificationCharacteristicUuid;

  static String get _drspUuid =>
      CasioConstants.casioDataRequestSpCharacteristicUuid;

  static String get _convoyUuid => CasioConstants.casioConvoyCharacteristicUuid;

  static String get _spRequestUuid =>
      CasioConstants.casioSetConfigurationCharacteristicUuid;

  static String get _spDataUuid =>
      CasioConstants.casioGetConfigurationCharacteristicUuid;

  /// Connects and returns a live [GshockConnection] talking to this watch.
  Future<GshockConnection> connect() async {
    final connection = GshockConnection(
      address: 'AA:BB:CC:DD:EE:FF',
      transport: transport,
    );
    final connected = await connection.connect();
    if (!connected) {
      throw StateError('FakeWatch: connect failed');
    }
    _connection = connection;
    // Mirrors the Python scanner flow: the advertised name registers the
    // model and capabilities.
    watchInfo.setNameAndModel(advertisedName);
    return connection;
  }

  GshockConnection get connection {
    final conn = _connection;
    if (conn == null) {
      throw StateError('FakeWatch: not connected; call connect() first');
    }
    return conn;
  }

  // ---------------------------------------------------------------------------
  // Response configuration helpers
  // ---------------------------------------------------------------------------

  void respondWatchName([String name = 'CASIO GW-B5600']) {
    readResponses[0x23] = <int>[0x23, ...name.codeUnits, 0x00];
  }

  void respondAlarms({int count = 5}) {
    // Main alarms notification: 0x15 + 4 bytes per alarm.
    final main = <int>[0x15];
    for (var i = 0; i < count; i++) {
      main.addAll(<int>[0x40, 0x40, 6 + i, 10 + i]);
    }
    readResponses[0x15] = main;
    // Secondary alarms notification: 0x16 + remaining alarms.
    final secondary = <int>[0x16];
    for (var i = 0; i < 4; i++) {
      secondary.addAll(<int>[0x40, 0x40, 12 + i, 30 + i]);
    }
    readResponses[0x16] = secondary;
  }

  void respondTimer(int seconds) {
    readResponses[0x18] = TimerIOFunctional.encode(seconds);
  }

  void respondWatchCondition({int batteryRaw = 9, int temperature = 21}) {
    readResponses[0x28] = <int>[0x28, batteryRaw, temperature];
  }

  void respondTimeAdjustment(List<int> payload) {
    readResponses[0x11] = payload;
  }

  void respondSettings(List<int> payload) {
    readResponses[0x13] = payload;
  }

  void respondAppInfo() {
    readResponses[0x22] = <int>[0x22, ...List<int>.filled(10, 0xFF), 0x00];
  }

  void respondWorldCities([String city = 'LONDON']) {
    readResponses[0x1F] = <int>[0x1F, 0x00, ...city.codeUnits, 0x00];
  }

  void respondDstWatchState() {
    readResponses[0x1D] = <int>[0x1D, 0x00, 0x00, 0x01, 0x00];
  }

  void respondDstForWorldCities() {
    readResponses[0x1E] = <int>[0x1E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
  }

  void respondHomeTime([String city = 'LONDON']) {
    readResponses[0x24] = <int>[0x24, 0x00, ...city.codeUnits, 0x00];
  }

  void respondReminders() {
    // Title notification: 0x30, slot, then 18 bytes of title.
    readResponses[0x30] = <int>[
      0x30,
      0x01,
      ...'Standup'.codeUnits,
      ...List<int>.filled(18 - 'Standup'.length, 0),
    ];
    // Time notification frame (weekly, MONDAY, 2025-05-16 -> 2025-05-17).
    readResponses[0x31] = <int>[
      0x31,
      0x01,
      0x01 | 0x04,
      0x25,
      0x05,
      0x16,
      0x25,
      0x05,
      0x17,
      0x02, // MONDAY
    ];
  }

  void respondButton(WatchButton button) {
    // Wire codes per Python ButtonPressedIO: 0x01=LOWER_LEFT,
    // 0x02=UPPER_LEFT, 0x03=UPPER_RIGHT, 0x04=LOWER_RIGHT.
    final code = switch (button) {
      WatchButton.lowerLeft => 0x01,
      WatchButton.upperLeft => 0x02,
      WatchButton.upperRight => 0x03,
      WatchButton.lowerRight => 0x04,
      _ => 0x00,
    };
    readResponses[0x10] = <int>[
      0x10,
      0x17,
      0x62,
      0x07,
      0x38,
      0x85,
      0xCD,
      0x7F,
      code,
      ...List<int>.filled(10, 0),
    ];
  }

  // ---------------------------------------------------------------------------
  // Write-recording helpers
  // ---------------------------------------------------------------------------

  /// All writes made to [handle] (via its mapped characteristic UUID).
  List<MockWrite> writesTo(int handle) {
    final uuid = GshockConnection.initHandlesMap()[handle];
    if (uuid == null) return const <MockWrite>[];
    return transport.writes
        .where((w) => w.uuid == uuid)
        .toList(growable: false);
  }

  /// The single write made to [handle], if any.
  MockWrite? writeTo(int handle) {
    final all = writesTo(handle);
    return all.isEmpty ? null : all.first;
  }

  /// All writes, as (handle, payload) pairs, in order.
  List<(int, Uint8List)> allWritesByHandle() {
    final handles = GshockConnection.initHandlesMap().map(
      (k, v) => MapEntry(v, k),
    );
    return <(int, Uint8List)>[
      for (final w in transport.writes)
        if (handles[w.uuid] != null) (handles[w.uuid]!, w.data),
    ];
  }

  // ---------------------------------------------------------------------------
  // Write -> notification simulation
  // ---------------------------------------------------------------------------

  void _onWrite(String uuid, Uint8List data) {
    if (data.isEmpty) return;

    if (uuid == _readRequestUuid) {
      final response = readResponses[data[0]];
      if (response != null) {
        transport.emit(_notificationUuid, response);
      }
      return;
    }

    if (uuid == _drspUuid) {
      // DRSP transaction start: [0x00, 0x11, 0x00, 0x00, 0x00].
      if (data[0] == 0x00 && data.length >= 2 && data[1] == 0x11) {
        final payload = _stepCounterPayload;
        if (payload == null) return;
        transport.emit(_drspUuid, <int>[
          0x00,
          0x11,
          payload.length & 0xFF,
          (payload.length >> 8) & 0xFF,
          (payload.length >> 16) & 0xFF,
        ]);
        transport.emit(_convoyUuid, payload);
      }
      return;
    }

    if (uuid == _spRequestUuid) {
      _onSpRequest(data);
    }
  }

  void _onSpRequest(Uint8List data) {
    switch (data[0]) {
      case 0x05: // Step 1: time-slot data -> 101 bytes.
        final response = List<int>.filled(101, 0);
        response[0] = 0x05;
        transport.emit(_spDataUuid, response);
      case 0x03: // Step 2: DST block -> 28 bytes.
        final response = List<int>.filled(28, 0);
        response[0] = 0x03;
        transport.emit(_spDataUuid, response);
      case 0x06: // Step 3: city names -> 1 + worldCitiesCount * 22 bytes.
        final response = List<int>.filled(1 + _worldCitiesCount * 22, 0);
        response[0] = 0x06;
        transport.emit(_spDataUuid, response);
    }
  }
}

/// [MockTransport] that forwards every write to a [FakeWatch] for simulation.
class SimulatingTransport extends MockTransport {
  SimulatingTransport(this._watch);

  final FakeWatch _watch;

  @override
  Future<void> write(
    String uuid,
    Uint8List data, {
    required bool withResponse,
  }) async {
    await super.write(uuid, data, withResponse: withResponse);
    _watch._onWrite(uuid, data);
  }
}
