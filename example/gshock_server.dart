import 'dart:io';
import 'dart:typed_data';

import '../adapters/linux_bluez/bluez_transport.dart';
import 'package:gshock_api_dart/gshock_api_dart.dart';

/// Formatted logger for the G-Shock Time Sync Server supporting console and file logs.
class ServerLogger {
  ServerLogger({this.verbose = false, this.logFile});

  final bool verbose;
  final File? logFile;
  IOSink? _fileSink;

  void init() {
    if (logFile != null) {
      _fileSink = logFile!.openWrite(mode: FileMode.append);
    }
  }

  void log(String level, String message) {
    final now = DateTime.now().toIso8601String().replaceFirst('T', ' ');
    final tag = level.padRight(5);
    final line = '[$now] [$tag] $message';
    if (level == 'ERROR') {
      stderr.writeln(line);
    } else {
      stdout.writeln(line);
    }
    _fileSink?.writeln(line);
  }

  void info(String message) => log('INFO', message);
  void debug(String message) {
    if (verbose) log('DEBUG', message);
  }

  void warn(String message) => log('WARN', message);
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    log('ERROR', message);
    if (error != null) {
      log('ERROR', '  Details: $error');
    }
    if (verbose && stackTrace != null) {
      log('ERROR', '  Stack trace:\n$stackTrace');
    }
  }

  Future<void> close() async {
    await _fileSink?.flush();
    await _fileSink?.close();
  }
}

void printBanner() {
  stdout.writeln(
    '==============================================================================================',
  );
  stdout.writeln('  G-SHOCK TIME SYNCHRONIZATION SERVER (Dart / Linux BlueZ)');
  stdout.writeln(
    '==============================================================================================',
  );
  stdout.writeln('Short-press lower-right button on your watch to set time.');
  stdout.writeln(
    'If Auto-time is enabled on the watch, it will connect automatically up to 4 times per day.',
  );
  stdout.writeln(
    '==============================================================================================\n',
  );
}

void printUsage() {
  stdout.writeln('''
Usage: dart run example/gshock_server.dart [options]

Options:
  --address <MAC>       Target specific watch address (e.g. DC:17:9B:0B:87:29)
  --timezone <TZ>       Specify IANA timezone (e.g. Asia/Kolkata, Europe/London)
  --offset <seconds>    Fine clock adjustment in seconds (default: 0)
  --log-file <path>     Write logs to file in addition to standard output
  -v, --verbose         Enable verbose/debug log output
  --mock                Run in simulated mode without hardware
  -h, --help            Show this help message
''');
}

Future<void> main(List<String> args) async {
  if (args.contains('-h') || args.contains('--help')) {
    printUsage();
    return;
  }

  final isMock = args.contains('--mock');
  final isVerbose = args.contains('-v') || args.contains('--verbose');

  int offset = 0;
  String? timezone;
  String? targetAddress;
  String? logFilePath;

  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--offset') {
      offset = int.tryParse(args[i + 1]) ?? 0;
    } else if (args[i] == '--timezone') {
      timezone = args[i + 1];
    } else if (args[i] == '--address') {
      targetAddress = args[i + 1];
    } else if (args[i] == '--log-file') {
      logFilePath = args[i + 1];
    }
  }

  final logger = ServerLogger(
    verbose: isVerbose,
    logFile: logFilePath != null ? File(logFilePath) : null,
  )..init();

  // Wire internal gshockLogger to our formatted server logger
  gshockLogger = GshockLogger(
    level: isVerbose ? GshockLogLevel.debug : GshockLogLevel.info,
    sink: (level, message) {
      switch (level) {
        case GshockLogLevel.debug:
          logger.debug(message);
        case GshockLogLevel.info:
          logger.info(message);
        case GshockLogLevel.warning:
          logger.warn(message);
        case GshockLogLevel.error:
          logger.error(message);
      }
    },
  );

  printBanner();

  logger.info('Initializing G-Shock Time Server...');
  logger.info(
    'Config: target=${targetAddress ?? "Any CASIO watch"}, '
    'offset=${offset}s, '
    'timezone=${timezone ?? "system local"}, '
    'verbose=$isVerbose, '
    'logFile=${logFilePath ?? "none"}',
  );

  final filter = AlwaysConnectedWatchFilter();

  if (isMock) {
    logger.info('[MOCK MODE] Simulating watch time sync server loop...');
    final transport = MockTransport();
    final connection = GshockConnection(
      address: targetAddress ?? 'AA:BB:CC:DD:EE:FF',
      transport: transport,
    );

    watchInfo.setNameAndModel('CASIO GW-B5600');
    transport.onWrite = (uuid, data) {
      if (uuid ==
              CasioConstants.casioReadRequestForAllFeaturesCharacteristicUuid &&
          data.isNotEmpty) {
        final code = data[0];
        if (code == 0x10) {
          transport.emit(
            CasioConstants.casioNotificationCharacteristicUuid,
            Uint8List.fromList(<int>[
              0x10, 0x17, 0x62, 0x07, 0x38, 0x85, 0xCD, 0x7F,
              0x04, // Lower right
              ...List<int>.filled(10, 0),
            ]),
          );
        } else if (code == 0x23) {
          transport.emit(
            CasioConstants.casioNotificationCharacteristicUuid,
            Uint8List.fromList(<int>[
              0x23,
              ...'CASIO GW-B5600'.codeUnits,
              0x00,
            ]),
          );
        } else if (code == 0x28) {
          transport.emit(
            CasioConstants.casioNotificationCharacteristicUuid,
            Uint8List.fromList(<int>[0x28, 9, 21]),
          );
        } else if (code == 0x1D) {
          transport.emit(
            CasioConstants.casioNotificationCharacteristicUuid,
            Uint8List.fromList(<int>[0x1D, 0x00, 0x00, 0x01, 0x00]),
          );
        } else if (code == 0x1E) {
          transport.emit(
            CasioConstants.casioNotificationCharacteristicUuid,
            Uint8List.fromList(<int>[0x1E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]),
          );
        } else if (code == 0x1F || code == 0x24) {
          transport.emit(
            CasioConstants.casioNotificationCharacteristicUuid,
            Uint8List.fromList(<int>[code, 0x00, ...'LONDON'.codeUnits, 0x00]),
          );
        }
      }
    };

    await connection.connect();
    final api = GshockApi(connection);
    final button = await api.getPressedButton();
    logger.info('Trigger button verified: $button');

    if (button != WatchButton.lowerRight &&
        button != WatchButton.noButton &&
        button != WatchButton.lowerLeft) {
      logger.warn(
        'Ignoring connection: button $button is not a time sync trigger.',
      );
      await logger.close();
      return;
    }

    final name = await api.getWatchName();
    logger.info('Watch identified: $name');

    await api.setTime(offset: offset, timezone: timezone);
    logger.info('Time synchronized successfully at ${DateTime.now()} on $name');

    final condition = await api.getWatchCondition();
    logger.info(
      'Watch condition: Battery ${condition["battery_level_percent"]}%, Temperature ${condition["temperature"]}°C',
    );

    if (!watchInfo.alwaysConnected) {
      await connection.disconnect();
      logger.info('Disconnected.');
    }

    api.reset();
    logger.info('[MOCK MODE] Time sync completed successfully.');
    await logger.close();
    return;
  }

  logger.info('Server started. Waiting for watch connection...');

  ProcessSignal.sigint.watch().listen((_) async {
    logger.info('Received SIGINT. Shutting down time server gracefully...');
    await logger.close();
    exit(0);
  });

  while (true) {
    try {
      logger.info('Listening for watch broadcast (waiting for button press)...');
      final transport = BluezTransport(deviceAddress: targetAddress);
      final scanner = const BluezScanner();
      final connection = GshockConnection(
        address: targetAddress,
        transport: transport,
        scanner: scanner,
      );

      final connected = await connection.connect(
        watchFilter: filter.connectionFilter,
        timeout: const Duration(seconds: 60),
      );

      if (!connected) {
        logger.debug('Scan interval elapsed with no connection. Retrying...');
        await Future<void>.delayed(const Duration(seconds: 1));
        continue;
      }

      final api = GshockApi(connection);

      // Verify connection was triggered by a time sync button
      logger.info('Checking trigger button on watch...');
      final button = await api.getPressedButton();
      logger.info('Sync initiated by button: $button');

      if (button != WatchButton.lowerRight &&
          button != WatchButton.noButton &&
          button != WatchButton.lowerLeft) {
        logger.warn(
          'Ignoring connection: button $button is not a time sync trigger (expected lowerRight, noButton, or lowerLeft).',
        );
        await connection.disconnect();
        api.reset();
        continue;
      }

      final name = await api.getWatchName();
      logger.info('Watch identified: $name (Protocol: ${watchInfo.protocol.runtimeType})');

      logger.info(
        'Synchronizing time (offset: ${offset}s, timezone: ${timezone ?? "local"})...',
      );
      await api.setTime(offset: offset, timezone: timezone);
      logger.info(
        'Time set successfully at ${DateTime.now()} on ${watchInfo.name}',
      );

      final condition = await api.getWatchCondition();
      logger.info(
        'Telemetry status: Battery ${condition["battery_level_percent"]}%, Temperature ${condition["temperature"]}°C',
      );

      if (!watchInfo.alwaysConnected) {
        await connection.disconnect();
        logger.info('Watch disconnected cleanly.');
        logger.info('Standing by for next sync event...\n');
      }

      api.reset();
    } catch (e, stackTrace) {
      logger.error('Exception in server sync loop: $e', e, stackTrace);
      logger.info('Pausing 5 seconds before resuming listener...');
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }
}
