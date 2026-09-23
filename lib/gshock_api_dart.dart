/// Pure-Dart library for communicating with Casio G-Shock Bluetooth Low Energy watches.
///
/// This package provides complete Bluetooth communication, time synchronization,
/// alarm management, reminder setting, step-count/lifelog decoding, and app notification
/// delivery across dozens of G-Shock, Edifice, Baby-G, and Oceanus watch models.
///
/// ## Architecture
///
/// The library is organized into three distinct layers:
///
/// 1. **Public API Facade ([GshockApi])**: High-level consumer methods (`setTime`,
///    `getAlarms`, `getStepCount`, `sendAppNotification`, etc.) that abstract away
///    Casio BLE packet formats and model-specific dialect differences.
/// 2. **Logical Connection ([GshockConnection])**: Handles Casio static handle-to-UUID
///    mapping, write-without-response semantics, notification routing, and step-counter
///    packet reassembly.
/// 3. **Pluggable BLE Transport ([BleTransport])**: Pure Dart interface for underlying
///    Bluetooth operations. Platform adapters implement this contract without adding
///    native or platform baggage to the core library:
///    - **Flutter**: Use `FlutterBluePlusTransport` (reference adapter in `adapters/flutter_blue_plus/`).
///    - **Linux**: Use `BluezTransport` (reference adapter in `adapters/linux_bluez/`).
///    - **Unit/Integration Tests**: Use [MockTransport] (in-memory simulation).
///
/// ## Quickstart
///
/// ### 1. Connecting and Reading Watch Info
///
/// ```dart
/// import 'package:gshock_api_dart/gshock_api_dart.dart';
///
/// Future<void> main() async {
///   // Create connection with your chosen BleTransport adapter
///   final transport = MockTransport(); // Or your platform adapter from adapters/
///   final connection = GshockConnection(transport: transport);
///   final api = GshockApi(connection);
///
///   await connection.connect();
///
///   // Read watch identity and battery state
///   final name = await api.getWatchName();
///   final condition = await api.getWatchCondition();
///   print('Connected to $name, battery: ${condition['battery']}%');
/// }
/// ```
///
/// ### 2. Synchronizing Time and Timezone
///
/// Calling [GshockApi.setTime] automatically negotiates the correct protocol for your watch:
/// - Standard 10-byte time packets for digital/hybrid watches (GW-B5600, GA-B2100).
/// - 4-step SP configuration handshake for MIP display watches (GW-BX5600, GMW-BZ5000).
/// - Motor alignment and second-dial bracketing for analogue models (MTG-B1000, MTG-B3000).
///
/// ```dart
/// // Sync watch to current local time and IANA timezone
/// await api.setTime(timezone: 'America/New_York');
/// ```
///
/// ### 3. Reading and Setting Alarms
///
/// ```dart
/// // Read all watch alarms
/// final alarms = await api.getAlarms();
/// for (final alarm in alarms) {
///   print('${alarm['hour']}:${alarm['minute']} - Enabled: ${alarm['enabled']}');
/// }
///
/// // Update first alarm and hourly chime
/// alarms[0] = {
///   'hour': 7,
///   'minute': 30,
///   'enabled': true,
///   'hasHourlyChime': true,
/// };
/// await api.setAlarms(alarms);
/// ```
///
/// ### 4. Reading Step Counts (Lifelog Models)
///
/// Models such as the ABL-100WE, F-B100W, and GBD-200 support step tracking:
///
/// ```dart
/// final stepData = await api.getStepCount();
/// print('Steps today: ${stepData.stepCount}');
/// for (var hour = 0; hour < 24; hour++) {
///   final hourly = stepData.hourlySteps[hour];
///   if (hourly != StepCounterData.unrecordedHour) {
///     print('Hour $hour: $hourly steps');
///   }
/// }
/// ```
///
/// ### 5. Sending App Notifications (DW-H5600, GBD-H2000)
///
/// Encrypted with Casio's XOR-255 cipher and transmitted over characteristic handle `0x0D`:
///
/// ```dart
/// final notification = AppNotification(
///   type: NotificationType.sms,
///   title: 'John Doe',
///   message: 'Meeting at 3 PM in Conference Room A.',
/// );
/// await api.sendAppNotification(notification);
/// ```
///
/// ## Watch Compatibility
///
/// | Series | Exemplar Models | Protocol Strategy | Notes |
/// |---|---|---|---|
/// | **Square 5600** | GW-B5600, DW-B5600, GMW-B5000 | [StandardProtocol] | 5 alarms, reminders, world cities |
/// | **Casioak 2100** | GA-B2100, GM-B2100, GBM-2100 | [StandardProtocol] | Hand retract, basic settings |
/// | **MIP Displays** | GW-BX5600, GMW-BZ5000 | [MipProtocol] | 4-step SP configuration flow |
/// | **Step Trackers**| ABL-100WE, F-B100W, GBD-200 | [StandardProtocol] | DRSP (0x11) / Convoy (0x14) lifelog |
/// | **Analogue / MT-G** | MTG-B1000, MTG-B3000, GST-B100 | [AnalogueProtocol] | Second-dial reset sequence, 12B settings |
/// | **Smart / Fitness** | DW-H5600, GBD-H2000 | [StandardProtocol] | App notifications (XOR-255) |
///
/// > **Important**: Always call [GshockApi.reset] or [WatchInfo.reset] when disconnecting
/// > or before connecting to a different watch model so cached capability state does not leak.
library;

import 'src/api/gshock_api.dart';
import 'src/connection/gshock_connection.dart';
import 'src/connection/gshock_scanner.dart';
import 'src/model/watch_info.dart';
import 'src/protocols/analogue_protocol.dart';
import 'src/protocols/mip_protocol.dart';
import 'src/protocols/standard_protocol.dart';

// API facade
export 'src/api/gshock_api.dart';

// Connection / transport
export 'src/connection/always_connected_watch_filter.dart';
export 'src/connection/gshock_connection.dart';
export 'src/connection/gshock_scanner.dart';

// Constants
export 'src/constants/casio_constants.dart';

// Dispatcher
export 'src/dispatcher/message_dispatcher.dart';

// Exceptions
export 'src/exceptions.dart';

// IO
export 'src/io/app_info_io.dart';
export 'src/io/app_notification_io.dart';
export 'src/io/alarms_io.dart';
export 'src/io/ble_action.dart';
export 'src/io/button_pressed_io.dart';
export 'src/io/connection_protocol.dart';
export 'src/io/dst_for_world_cities_io.dart';
export 'src/io/dst_watch_state_io.dart';
export 'src/io/error_io.dart';
export 'src/io/events_io.dart';
export 'src/io/gw_bx5600_time_io.dart';
export 'src/io/home_time_io.dart';
export 'src/io/packet.dart';
export 'src/io/second_dial_io.dart';
export 'src/io/settings_io.dart';
export 'src/io/step_counter_io.dart';
export 'src/io/time_adjustment_io.dart';
export 'src/io/time_io.dart';
export 'src/io/timer_io.dart';
export 'src/io/unknown_io.dart';
export 'src/io/watch_condition_io.dart';
export 'src/io/watch_name_io.dart';
export 'src/io/world_cities_io.dart';

// Models
export 'src/model/alarms.dart';
export 'src/model/app_notification.dart';
export 'src/model/event.dart';
export 'src/model/settings.dart';
export 'src/model/step_counter_data.dart';
export 'src/model/watch_info.dart';

// Protocols
export 'src/protocols/analogue_protocol.dart';
export 'src/protocols/mip_protocol.dart';
export 'src/protocols/standard_protocol.dart';
export 'src/protocols/watch_protocol.dart';

// Timezone
export 'src/timezone/casio_time_zone_helper.dart';

// Util
export 'src/util/bytes.dart';
export 'src/util/cancelable_result.dart';
export 'src/util/logger.dart';
