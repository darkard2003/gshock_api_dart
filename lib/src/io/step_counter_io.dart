import 'dart:async';
import 'dart:typed_data';

import '../io/connection_protocol.dart';
import '../model/step_counter_data.dart';
import '../model/watch_info.dart';
import '../util/cancelable_result.dart';
import '../util/logger.dart';

const int fallbackExpectedLength = 400;
const int drspCategoryExercise = 0x11;
final Uint8List startTransactionCmd = Uint8List.fromList(<int>[
  0x00,
  drspCategoryExercise,
  0x00,
  0x00,
  0x00,
]);
final Uint8List endTransactionCmd = Uint8List.fromList(<int>[
  0x04,
  drspCategoryExercise,
  0x00,
  0x00,
  0x00,
]);

const int packetHeaderMarker = 0x26;
const int bleHandleDrsp = 0x0011;
const int sentinelBucketValue = 0xFFFE;
const int sentinelDailyValue = 0xFFFFFFFE;
const int bcdBase = 16;
const int bcdMaxDigit = 9;
const int baseCenturyYear = 2000;
const int activityScanLimit = 146;

int _decodeBcd(int byte) {
  final high = byte ~/ bcdBase;
  final low = byte % bcdBase;
  if (high > bcdMaxDigit || low > bcdMaxDigit) {
    throw ArgumentError('invalid BCD byte 0x${byte.toRadixString(16)}');
  }
  return high * 10 + low;
}

int _u16(ByteData bd, int offset) => bd.getUint16(offset, Endian.little);

int _u32(ByteData bd, int offset) => bd.getUint32(offset, Endian.little);

/// Pure functional decoder for ABL-100WE life-log records.
/// @nodoc
class StepCounterIOFunctional {
  StepCounterIOFunctional._();

  static const int headerSize = 6;
  static const int activityRecordSize = 10;
  static const int activityBucketCount = 5;
  static const int historySlotCount = 24;
  static const int dailySummaryOffset = 318;
  static const int dailySummaryCount = 7;
  static const int dailySummarySize = 8;
  static const int committedDistanceOffset = 246;
  static const int committedDistanceEnd = 318;
  static const int currentStepsOffset = 374;
  static const int currentDistanceOffset = 378;
  static const int pendingIntensityOffset = 382;
  static const int pendingDistanceOffset = 392;
  static const int bcdTotalOffset = 396;

  static bool _isValidCalendar(
    int year,
    int month,
    int day,
    int hour,
    int minute,
    int second,
  ) {
    if (month < 1 || month > 12) return false;
    if (hour < 0 || hour > 23) return false;
    if (minute < 0 || minute > 59) return false;
    if (second < 0 || second > 59) return false;
    // Dart normalizes out-of-range days, so validate explicitly.
    final probe = DateTime.utc(year, month, day);
    return probe.year == year && probe.month == month && probe.day == day;
  }

  static StepCounterData? parse(Uint8List payload) {
    if (payload.isEmpty || payload[0] != packetHeaderMarker) {
      return null;
    }

    final bd = ByteData.sublistView(payload);
    final warnings = <String>[];

    DateTime? timestamp;
    int? dayOfWeek;
    int? month;
    int? dayOfMonth;
    if (payload.length >= 6) {
      try {
        final year = baseCenturyYear + _decodeBcd(payload[0]);
        month = _decodeBcd(payload[1]);
        dayOfMonth = _decodeBcd(payload[2]);
        final hour = _decodeBcd(payload[3]);
        final minute = _decodeBcd(payload[4]);
        final second = _decodeBcd(payload[5]);
        if (!_isValidCalendar(year, month, dayOfMonth, hour, minute, second)) {
          throw ArgumentError('invalid calendar');
        }
        timestamp = DateTime(year, month, dayOfMonth, hour, minute, second);
        dayOfWeek = timestamp.weekday - 1;
      } catch (_) {
        warnings.add('invalid BCD timestamp in step counter header');
      }
    }

    const currentDayOffset = currentStepsOffset;
    final int? currentDaySteps = payload.length >= currentDayOffset + 4
        ? _u32(bd, currentDayOffset)
        : null;

    var pendingSteps = 0;
    List<int> pendingIntensity = const <int>[];
    if (payload.length >= pendingIntensityOffset + 6) {
      pendingIntensity = <int>[
        _u16(bd, pendingIntensityOffset),
        _u16(bd, pendingIntensityOffset + 2),
        _u16(bd, pendingIntensityOffset + 4),
      ];
      pendingSteps = pendingIntensity
          .where((value) => value != sentinelBucketValue)
          .fold(0, (a, b) => a + b);
    }

    var recordEnd = headerSize;
    if (currentDaySteps != null) {
      var bestDiff = -1;
      var bestEnd = headerSize;
      for (var end = 6; end < activityScanLimit; end += activityRecordSize) {
        if (end + activityRecordSize > payload.length) break;
        var frontTotal = 0;
        for (var offset = 6; offset < end; offset += activityRecordSize) {
          if (offset + activityRecordSize > payload.length) break;
          for (var b = 0; b < activityBucketCount; b++) {
            final value = _u16(bd, offset + b * 2);
            if (value != sentinelBucketValue) frontTotal += value;
          }
        }
        final diff = (currentDaySteps - pendingSteps - frontTotal).abs();
        if (bestDiff < 0 || diff < bestDiff) {
          bestDiff = diff;
          bestEnd = end;
        }
      }
      recordEnd = bestEnd;
    }

    final activitySteps = <int?>[];
    final hourlyIntensities = <List<int>>[];
    final hourlyIntervals = <Map<String, Object?>>[];
    var intervalIndex = 0;
    for (var offset = 6; offset < recordEnd; offset += activityRecordSize) {
      if (offset + activityRecordSize > payload.length) break;
      final buckets = <int>[
        for (var b = 0; b < activityBucketCount; b++) _u16(bd, offset + b * 2),
      ];
      final steps = buckets
          .where((value) => value != sentinelBucketValue)
          .fold(0, (a, b) => a + b);
      activitySteps.add(steps == 0 ? null : steps);
      hourlyIntensities.add(buckets);
      hourlyIntervals.add(<String, Object?>{
        'index': intervalIndex,
        'start_minute': 0,
        'end_minute': 59,
        'steps': steps == 0 ? null : steps,
        'intensity': buckets,
      });
      intervalIndex++;
    }

    final dailyHistory = <int?>[];
    final dailyDistances = <int?>[];
    for (var index = 0; index < dailySummaryCount; index++) {
      final offset = dailySummaryOffset + index * dailySummarySize;
      if (offset + dailySummarySize > payload.length) break;
      final steps = _u32(bd, offset);
      final distance = _u32(bd, offset + 4);
      if (steps == sentinelDailyValue && distance == sentinelDailyValue) {
        dailyHistory.add(null);
        dailyDistances.add(null);
      } else {
        dailyHistory.add(steps == sentinelDailyValue ? null : steps);
        dailyDistances.add(distance == sentinelDailyValue ? null : distance);
      }
    }

    int? effectiveCurrentDaySteps = currentDaySteps;
    if (effectiveCurrentDaySteps == sentinelDailyValue) {
      effectiveCurrentDaySteps = null;
    }

    int? distanceMeters;
    int? pendingDistanceMeters;
    int? totalDistanceMeters;
    int? bcdTotalSteps;
    var committedDistances = <int>[];

    if (payload.length < currentDayOffset + 4) {
      warnings.add('step record truncated; missing trailing history fields');
    }

    if (payload.length >= currentDistanceOffset + 4) {
      distanceMeters = _u32(bd, currentDistanceOffset);
      totalDistanceMeters = distanceMeters;
    }

    if (payload.length >= pendingDistanceOffset + 4) {
      pendingDistanceMeters = _u32(bd, pendingDistanceOffset);
    }

    if (distanceMeters != null &&
        pendingDistanceMeters != null &&
        distanceMeters >= pendingDistanceMeters) {
      final committedTarget = distanceMeters - pendingDistanceMeters;
      var distanceSum = 0;
      if (committedTarget != 0) {
        for (
          var offset = committedDistanceOffset;
          offset < committedDistanceEnd;
          offset += 2
        ) {
          if (offset + 2 > payload.length) break;
          final value = _u16(bd, offset);
          if (value == sentinelBucketValue) continue;
          committedDistances.add(value);
          distanceSum += value;
          if (distanceSum == committedTarget) break;
          if (distanceSum > committedTarget) {
            committedDistances = <int>[];
            break;
          }
        }
      }
      if (committedTarget != 0 && distanceSum != committedTarget) {
        committedDistances = <int>[];
        warnings.add(
          'distance components do not reconcile to $committedTarget m',
        );
      }
    }

    if (payload.length >= bcdTotalOffset + 4) {
      final rawBcdTotal = payload.sublist(bcdTotalOffset, bcdTotalOffset + 4);
      if (rawBcdTotal.any((b) => b != 0)) {
        try {
          bcdTotalSteps = 0;
          var factor = 1;
          for (final byte in rawBcdTotal) {
            bcdTotalSteps = bcdTotalSteps! + _decodeBcd(byte) * factor;
            factor *= 100;
          }
        } catch (_) {
          bcdTotalSteps = null;
        }
      }
    }

    if (bcdTotalSteps != null &&
        bcdTotalSteps > 0 &&
        effectiveCurrentDaySteps != null &&
        bcdTotalSteps != effectiveCurrentDaySteps) {
      warnings.add(
        'BCD total $bcdTotalSteps differs from current step count $effectiveCurrentDaySteps',
      );
    }

    final hourlySteps = activitySteps;
    final hourlyByHour = List<int?>.filled(24, null);
    if (timestamp != null) {
      for (var index = 0; index < activitySteps.length; index++) {
        final steps = activitySteps[index];
        if (steps != null) {
          final hour = (timestamp.hour - index - 1) % 24;
          hourlyByHour[hour] = steps;
        }
      }
      if (pendingSteps != 0) {
        hourlyByHour[timestamp.hour] = pendingSteps;
      }
    }

    final dailyHistoryList = <Map<String, Object?>>[
      for (var i = 0; i < dailyHistory.length; i++)
        <String, Object?>{'days_ago': i + 1, 'steps': dailyHistory[i]},
    ];

    return StepCounterData(
      timestamp: timestamp,
      dayOfWeek: dayOfWeek,
      month: month,
      dayOfMonth: dayOfMonth,
      hourlySteps: hourlySteps,
      dailyHistory: dailyHistory,
      dailyDistances: dailyDistances,
      currentDaySteps: effectiveCurrentDaySteps,
      raw: payload.toList(),
      warnings: warnings,
      distanceMeters: distanceMeters,
      pendingDistanceMeters: pendingDistanceMeters,
      totalDistanceMeters: totalDistanceMeters,
      bcdTotalSteps: bcdTotalSteps,
      hourlyIntervals: hourlyIntervals,
      hourlyByHour: hourlyByHour,
      dailyHistoryList: dailyHistoryList,
      hourlyIntensities: hourlyIntensities,
      pendingIntensity: pendingIntensity,
      committedDistances: committedDistances,
    );
  }
}

/// Stateful manager for requesting, accumulating and decoding lifelog data.
/// @nodoc
class StepCounterIO {
  StepCounterIO._();

  static CancelableResult<StepCounterData>? result;
  static ConnectionProtocol? connection;
  static Uint8List accumulator = Uint8List(0);
  static int expectedLength = fallbackExpectedLength;
  static bool peek = true;
  static StepCounterData? lastData;
  static Future<void>? endTxnTask;

  static Future<StepCounterData> request(
    ConnectionProtocol connection, {
    bool peek = true,
  }) async {
    if (!watchInfo.hasStepCounter) {
      gshockLogger.info([
        'Step counter not supported on watch model: ${watchInfo.model}',
      ]);
      return StepCounterData.unavailable();
    }

    StepCounterIO.connection = connection;
    StepCounterIO.peek = peek;
    accumulator = Uint8List(0);
    expectedLength = fallbackExpectedLength;
    final pending = CancelableResult<StepCounterData>();
    result = pending;

    try {
      try {
        await connection.write(bleHandleDrsp, startTransactionCmd);
      } catch (e) {
        if (e.toString().contains('BleakGATTProtocolError')) {
          gshockLogger.warning(
            'StepCounterIO: Transaction already active on watch.',
          );
          if (lastData != null) {
            return lastData!;
          }
        } else {
          rethrow;
        }
      }

      return await pending.getResult();
    } finally {
      if (identical(result, pending)) {
        result = null;
        accumulator = Uint8List(0);
      }
    }
  }

  static void onDrspReceived(Uint8List data) {
    if (data.length < 5) return;
    final command = data[0];
    final category = data[1];
    if (category != drspCategoryExercise) return;

    if (command == 0x00) {
      final announcedLength = data[2] | (data[3] << 8) | (data[4] << 16);
      if (result != null) {
        expectedLength = announcedLength;
        gshockLogger.debug([
          'StepCounterIO: expected length announced = ${announcedLength}B',
        ]);
      }
    }
  }

  static void onReceived(Uint8List data) {
    if (result == null) return;

    accumulator = Uint8List.fromList(<int>[...accumulator, ...data]);
    gshockLogger.debug([
      'StepCounterIO.on_received: accumulated=${accumulator.length}B / '
          'expected=${expectedLength}B',
    ]);

    if (accumulator.length < expectedLength) return;

    if (connection != null && !peek) {
      try {
        endTxnTask = connection!
            .write(bleHandleDrsp, endTransactionCmd)
            .catchError((Object e) {
              gshockLogger.warning([
                'Failed to send end transaction command: $e',
              ]);
            });
      } catch (e) {
        gshockLogger.warning(['Failed to schedule end transaction task: $e']);
      }
    }

    final fullPayload = accumulator;
    final stepData = StepCounterIOFunctional.parse(fullPayload);

    if (stepData != null) {
      lastData = stepData;
      result!.setResult(stepData);
    } else {
      gshockLogger.warning([
        'Failed to parse activity record from ${fullPayload.length}B payload',
      ]);
      result!.setResult(StepCounterData.unavailable());
    }
  }
}
