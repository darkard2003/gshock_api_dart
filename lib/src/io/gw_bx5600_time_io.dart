import 'dart:typed_data';

import '../constants/casio_constants.dart';
import '../io/connection_protocol.dart';
import '../model/watch_info.dart';
import '../timezone/casio_time_zone_helper.dart';
import '../util/cancelable_result.dart';
import '../util/logger.dart';

const int spRequest = CasioConstants.handleSpRequest;
const int spData = CasioConstants.handleSpData;
const int allFeatures = CasioConstants.handleAllFeaturesWrite;

const int cityRecordFlag = 0x01;
const int emptySlotTrailing = 0x00;
const double emptySlotLat = 0.0;
const double emptySlotLon = 0.0;

/// GW-BX5600 / GMW-BZ5000 four-step SP time-set flow.
class GwBx5600TimeIO {
  GwBx5600TimeIO._();

  static ConnectionProtocol? connection;
  static CancelableResult<Uint8List>? result;
  static int step = 0;
  static Uint8List accumulator = Uint8List(0);

  static Future<void> setTime(
    ConnectionProtocol connection, [
    DateTime? now,
  ]) async {
    now ??= DateTime.now();
    gshockLogger.info(['GwBx5600TimeIO.set_time: $now']);

    GwBx5600TimeIO.connection = connection;

    // Step 1
    gshockLogger.info(['Step 1/4: time-slot data']);
    final req1 = <int>[
      0x05,
      0x1D,
      0x00,
      0x1D,
      0x00,
      0x24,
      0x00,
      0x24,
      0x01,
      0x24,
      0x02,
    ];

    final notif1 = await requestStep(connection, 1, _toHex(req1));

    final wb1 = notif1.toList();
    wb1[0] = 0x02;
    gshockLogger.debug(['GwBx5600TimeIO Step1 write: ${wb1.length}B']);
    await connection.write(spData, Uint8List.fromList(wb1));

    // Step 2
    gshockLogger.info(['Step 2/4: world-city data']);
    final req2 = <int>[0x03];
    final blocks = (watchInfo.worldCitiesCount / 2).ceil();
    for (var i = 0; i < blocks; i++) {
      req2.addAll(<int>[
        CasioConstants.characteristics['CASIO_DST_SETTING']!,
        0x00,
      ]);
    }

    final notif2 = await requestStep(connection, 2, _toHex(req2));

    final wb2 = notif2.toList();
    wb2[0] = 0x06;
    final withCityData = Uint8List.fromList(<int>[
      ...wb2,
      ...buildWorldCityRecords(),
    ]);
    gshockLogger.debug([
      'GwBx5600TimeIO Step2 write: ${withCityData.length}B (expect 94)',
    ]);
    await connection.write(spData, withCityData);

    // Step 3
    gshockLogger.info(['Step 3/4: city names']);
    final req3 = <int>[0x06];
    for (var i = 0; i < watchInfo.worldCitiesCount; i++) {
      final idx = (i ~/ 2) + (i % 2 != 0 ? 6 : 0);
      req3.addAll(<int>[
        CasioConstants.characteristics['CASIO_WORLD_CITIES']!,
        idx,
      ]);
    }

    final notif3 = await requestStep(connection, 3, _toHex(req3));
    gshockLogger.debug(['GwBx5600TimeIO Step3 write: ${notif3.length}B']);
    await connection.write(spData, notif3);

    // Step 4
    await writeTimeCommand(connection, now);
    gshockLogger.info(['GwBx5600TimeIO.set_time: complete']);
  }

  static Uint8List buildWorldCityRecords() {
    final casioTz = CasioTimeZoneHelper.getLocalCasioTimeZone();
    final coords = CasioTimeZoneHelper.getWorldCityCoordinates(
      casioTz.zoneName,
    );
    final dstValue = casioTz.isInDst() ? 1 : 0;

    final homeRecord = cityRecord(0, coords.lat, coords.lon, dstValue);
    final emptySlot1 = cityRecord(
      1,
      emptySlotLat,
      emptySlotLon,
      emptySlotTrailing,
    );
    final emptySlot2 = cityRecord(
      2,
      emptySlotLat,
      emptySlotLon,
      emptySlotTrailing,
    );

    return Uint8List.fromList(<int>[
      ...homeRecord,
      ...emptySlot1,
      ...emptySlot2,
    ]);
  }

  static Uint8List cityRecord(
    int slotIndex,
    double lat,
    double lon,
    int trailing,
  ) {
    final data = ByteData(22);
    data.setUint8(0, 0x14);
    data.setUint8(1, 0x00);
    data.setUint8(2, 0x24);
    data.setUint8(3, slotIndex);
    data.setUint8(4, cityRecordFlag);
    data.setFloat64(5, lat, Endian.big);
    data.setFloat64(13, lon, Endian.big);
    data.setUint8(21, trailing);
    return data.buffer.asUint8List();
  }

  static Future<void> request(
    ConnectionProtocol connection, [
    double? currentTime,
    int offset = 0,
  ]) async {
    currentTime ??= DateTime.now().millisecondsSinceEpoch / 1000.0;
    final now = DateTime.fromMillisecondsSinceEpoch(
      ((currentTime + offset) * 1000).round(),
    );
    await setTime(connection, now);
  }

  static void onReceived(Uint8List data) {
    if (result == null) return;

    accumulator = Uint8List.fromList(<int>[...accumulator, ...data]);

    int expected;
    if (step == 1) {
      expected = 101;
    } else if (step == 2) {
      expected = 28;
    } else if (step == 3) {
      expected = 1 + (watchInfo.worldCitiesCount * 22);
    } else {
      expected = 0;
    }

    final accumulated = accumulator.length;
    gshockLogger.debug([
      'GwBx5600TimeIO.on_received: step=$step accumulated=${accumulated}B / expected=${expected}B',
    ]);

    if (accumulated >= expected) {
      result!.setResult(accumulator);
    }
  }

  static Future<Uint8List> requestStep(
    ConnectionProtocol connection,
    int step,
    String reqPayload,
  ) async {
    GwBx5600TimeIO.step = step;
    accumulator = Uint8List(0);
    final pending = CancelableResult<Uint8List>(
      timeout: const Duration(seconds: 5),
    );
    result = pending;
    try {
      await connection.write(spRequest, reqPayload);
      return await pending.getResult();
    } finally {
      if (identical(result, pending)) {
        result = null;
        accumulator = Uint8List(0);
        GwBx5600TimeIO.step = 0;
      }
    }
  }

  static Future<void> writeTimeCommand(
    ConnectionProtocol connection,
    DateTime now,
  ) async {
    final casioDow = now.weekday == 7 ? 7 : now.weekday;
    final subSecond =
        ((now.millisecond * 1000 + now.microsecond) * 256 ~/ 1000000) & 0xFF;

    final timeCmd = Uint8List.fromList(<int>[
      0x09,
      now.year & 0xFF,
      (now.year >> 8) & 0xFF,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
      casioDow,
      subSecond,
      0x01,
    ]);
    gshockLogger.info(['Step 4/4: time command: ${_toHex(timeCmd.toList())}']);
    await connection.write(allFeatures, _toHex(timeCmd.toList()));
  }

  static String _toHex(List<int> bytes) {
    final buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write((b & 0xFF).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
