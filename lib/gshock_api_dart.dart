/// Dart port of the Python `gshock_api` BLE library for Casio G-Shock watches.
///
/// The core is pure Dart (no Flutter imports). BLE transport is injected via
/// the [BleTransport] abstraction; platform adapters (flutter_blue_plus) live
/// outside this library and are wired through [GshockConnection].
library;

// API facade
export 'src/api/gshock_api.dart';

// Connection / transport
export 'src/connection/always_connected_watch_filter.dart';
export 'src/connection/bluez_transport.dart';
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
