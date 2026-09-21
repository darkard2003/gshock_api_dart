#!/usr/bin/env python3
"""Generates `python_reference.dart` — golden data extracted by *executing*
the Python reference implementation.

The Dart migration test suite compares the Dart port against these goldens.
A fully green run means the Dart library is behaviorally equivalent to the
Python implementation on every covered surface.

Run from the `gshock_api/` directory:

    uv run python ../gshock_api_dart/tool/golden/generate_python_goldens.py

Output: gshock_api_dart/test/migration/golden/python_reference.dart
"""

from __future__ import annotations

import dataclasses
import json
from datetime import datetime

from gshock_api import watch_info as watch_info_module
from gshock_api.app_notification import AppNotification, NotificationType
from gshock_api.casio_constants import CasioConstants
from gshock_api.casio_time_zone_helper import CasioTimeZoneHelper
from gshock_api.iolib.alarms_io import AlarmsIOFunctional
from gshock_api.iolib.app_info_io import AppInfoIOFunctional
from gshock_api.iolib.app_notification_io import AppNotificationIO
from gshock_api.iolib.button_pressed_io import ButtonPressedIOFunctional
from gshock_api.iolib.events_io import EventsIOFunctional
from gshock_api.iolib.gw_bx5600_time_io import GwBx5600TimeIO
from gshock_api.iolib.settings_io import SettingsIOFunctional
from gshock_api.iolib.step_counter_io import StepCounterIOFunctional
from gshock_api.iolib.time_adjustment_io import TimeAdjustmentIOFunctional
from gshock_api.iolib.time_io import TimeEncoderPure
from gshock_api.iolib.timer_io import TimerIOFunctional
from gshock_api.iolib.watch_condition_io import WatchConditionIOFunctional
from gshock_api.iolib.world_cities_io import WorldCitiesIO
from gshock_api.watch_info import WatchModel, resolve_model_info

OUT = "../gshock_api_dart/test/migration/golden/python_reference.dart"


def _esc(value: str) -> str:
    """Escape a value for a Dart single-quoted string literal."""
    return value.replace("\\", "\\\\").replace("'", "\\'")


def dart_bytes(data: bytes) -> str:
    if not data:
        return "const <int>[]"
    return "const <int>[" + ", ".join(f"0x{b:02X}" for b in data) + "]"


def dart_actions(actions: list) -> str:
    parts = []
    for action in actions:
        handle = getattr(action, "handle", None)
        data = getattr(action, "data", None)
        parts.append(f"      GoldenAction(handle: 0x{handle:04X}, data: {dart_bytes(bytes(data))}),")
    return "<GoldenAction>[\n" + "\n".join(parts) + "\n    ]"


def dart_string_map(mapping: dict[str, str], indent: str = "    ") -> str:
    parts = [f"{indent}'{k}': '{v}'," for k, v in mapping.items()]
    return "<String, String>{\n" + "\n".join(parts) + "\n  }"


def dart_int_map(mapping: dict[str, int], indent: str = "    ") -> str:
    parts = [f"{indent}'{k}': 0x{v:02X}," for k, v in mapping.items()]
    return "<String, int>{\n" + "\n".join(parts) + "\n  }"


def main() -> None:
    # ------------------------------------------------------------------
    # 1. Constants
    # ------------------------------------------------------------------
    uuid_names = [
        "CASIO_GET_DEVICE_NAME",
        "CASIO_APPEARANCE",
        "TX_POWER_LEVEL_CHARACTERISTIC_UUID",
        "CASIO_READ_REQUEST_FOR_ALL_FEATURES_CHARACTERISTIC_UUID",
        "CASIO_ALL_FEATURES_CHARACTERISTIC_UUID",
        "CASIO_NOTIFICATION_CHARACTERISTIC_UUID",
        "CASIO_DATA_REQUEST_SP_CHARACTERISTIC_UUID",
        "CASIO_CONVOY_CHARACTERISTIC_UUID",
        "CASIO_SET_CONFIGURATION_CHARACTERISTIC_UUID",
        "CASIO_GET_CONFIGURATION_CHARACTERISTIC_UUID",
        "SERIAL_NUMBER_STRING",
    ]
    uuids = {name: getattr(CasioConstants, name) for name in uuid_names}

    handle_names = [
        "HANDLE_DEVICE_NAME_LEGACY",
        "HANDLE_APPEARANCE",
        "HANDLE_DEVICE_NAME_GW",
        "HANDLE_TX_POWER",
        "HANDLE_READ_ALL_FEATURES",
        "HANDLE_ALL_FEATURES_NOTIFICATION",
        "HANDLE_ALL_FEATURES_WRITE",
        "HANDLE_DATA_REQUEST_SP",
        "HANDLE_CONVOY_NOTIFICATION",
        "HANDLE_SP_NOTIFY",
        "HANDLE_SP_REQUEST",
        "HANDLE_SP_DATA",
    ]
    handles = {name: getattr(CasioConstants, name) for name in handle_names}
    characteristics = dict(CasioConstants.CHARACTERISTICS)

    # ------------------------------------------------------------------
    # 2. Watch model map + capability matrix
    # ------------------------------------------------------------------
    exact_model_map = {
        name: model.name for name, model in watch_info_module.EXACT_MODEL_MAP.items()
    }

    capability_fields = [
        f.name
        for f in dataclasses.fields(resolve_model_info(WatchModel.GENERIC))
        if f.name != "protocol"
    ]
    capability_matrix: dict[str, dict[str, object]] = {}
    for model in WatchModel:
        info = resolve_model_info(model)
        entry: dict[str, object] = {
            "protocol": type(info.protocol).__name__,
        }
        for field in capability_fields:
            entry[field] = getattr(info, field)
        capability_matrix[model.name] = entry

    # ------------------------------------------------------------------
    # 3. Timezone tables
    # ------------------------------------------------------------------
    tz_table = [
        (tz.name, tz.zone_name, tz._dst_rules)
        for tz in CasioTimeZoneHelper.TIME_ZONE_TABLE
    ]
    world_city_coordinates = {
        zone: (coords.lat, coords.lon)
        for zone, coords in CasioTimeZoneHelper.WORLD_CITY_COORDINATES.items()
    }

    # ------------------------------------------------------------------
    # 4. Time encoding goldens
    # ------------------------------------------------------------------
    dt1 = datetime(2026, 5, 30, 8, 45, 30, 123456)
    dt2 = datetime(2030, 12, 31, 23, 59, 59, 999999)
    dt3 = datetime(2000, 1, 1, 0, 0, 0, 0)
    time_goldens = {
        "2026-05-30T08:45:30.123456": TimeEncoderPure.encode_current_time(dt1),
        "2030-12-31T23:59:59.999999": TimeEncoderPure.encode_current_time(dt2),
        "2000-01-01T00:00:00": TimeEncoderPure.encode_current_time(dt3),
    }

    # ------------------------------------------------------------------
    # 5. Alarms goldens
    # ------------------------------------------------------------------
    alarms_set_json = json.dumps(
        {
            "value": [
                {"enabled": True, "hasHourlyChime": False, "hour": 7, "minute": 25},
                {"enabled": False, "hasHourlyChime": True, "hour": 8, "minute": 30},
                {"enabled": True, "hasHourlyChime": False, "hour": 9, "minute": 35},
                {"enabled": False, "hasHourlyChime": False, "hour": 10, "minute": 40},
                {"enabled": True, "hasHourlyChime": True, "hour": 11, "minute": 45},
            ]
        }
    )
    alarms_mtg_b3000_json = json.dumps(
        {"value": [{"enabled": True, "hasHourlyChime": False, "hour": 7, "minute": 25}]}
    )
    alarms_set_actions = AlarmsIOFunctional.prepare_watch_commands_set(alarms_set_json)
    alarms_mtg_b3000_actions = AlarmsIOFunctional.prepare_watch_commands_set_mtg_b3000(
        alarms_mtg_b3000_json
    )
    # 0x15 main-alarms notification: command byte + 4 bytes per alarm x 5.
    alarm_packet = bytes([0x15] + [0x40, 0x40, 7, 25] * 5)
    # Python's parse_packet returns a list of JSON strings; normalize to dicts
    # (the shape Dart returns directly) for comparison.
    alarms_parsed = [json.loads(item) for item in AlarmsIOFunctional.parse_packet(alarm_packet)]

    # ------------------------------------------------------------------
    # 6. Settings goldens (model context: GW-B5600, whose longLightDuration
    #    is "4s")
    # ------------------------------------------------------------------
    watch_info_module.watch_info.set_name_and_model("CASIO GW-B5600")
    settings_dict = {
        "time_format": "24h",
        "button_tone": True,
        "auto_light": False,
        "power_saving_mode": True,
        "light_duration": "4s",
        "date_format": "DD:MM",
        "language": "French",
    }
    settings_encoded = SettingsIOFunctional.encode(settings_dict)
    settings_decoded = SettingsIOFunctional.decode(settings_encoded)
    watch_info_module.watch_info.set_name_and_model("CASIO MTG-B3000")
    settings_mtg_b3000_encoded = SettingsIOFunctional.encode_mtg_b3000(settings_dict)
    settings_mtg_b3000_decoded = SettingsIOFunctional.decode_mtg_b3000(
        settings_mtg_b3000_encoded
    )
    watch_info_module.watch_info.reset()

    # ------------------------------------------------------------------
    # 7. Timer goldens
    # ------------------------------------------------------------------
    timer_encoded = TimerIOFunctional.encode(3665)
    timer_decoded = TimerIOFunctional.decode(timer_encoded)
    timer_mtg_b3000 = TimerIOFunctional.encode_mtg_b3000(600)
    timer_set_actions = TimerIOFunctional.prepare_watch_commands_set(
        json.dumps({"value": 3665})
    )
    timer_mtg_b3000_set_actions = TimerIOFunctional.prepare_watch_commands_set_mtg_b3000(
        json.dumps({"value": 600})
    )

    # ------------------------------------------------------------------
    # 8. Time adjustment goldens
    # ------------------------------------------------------------------
    ta_original_hex = "0x11 0F 0F 0F 06 00 50 00 04 00 01 00 80 10 D2"
    ta_encoded = TimeAdjustmentIOFunctional.encode(ta_original_hex, True, 25)
    ta_decoded = TimeAdjustmentIOFunctional.decode(ta_encoded)

    # ------------------------------------------------------------------
    # 9. World cities goldens
    # ------------------------------------------------------------------
    wc_padded = WorldCitiesIO.encode_and_pad("LONDON", 2)
    wc_parsed_city = {
        "Europe/London": WorldCitiesIO.parse_city("Europe/London"),
        "America/New_York": WorldCitiesIO.parse_city("America/New_York"),
        "Asia/Tokyo": WorldCitiesIO.parse_city("Asia/Tokyo"),
    }

    # ------------------------------------------------------------------
    # 10. App notification goldens
    # ------------------------------------------------------------------
    notification = AppNotification(
        type=NotificationType.CALENDAR,
        timestamp="20250516T233000",
        app="Calendar",
        title="Meeting",
        text="Discuss project",
        short_text="Meet",
    )
    notification_encoded = AppNotificationIO.encode_notification_packet(notification)
    notification_xor = AppNotificationIO.xor_encode_buffer(notification_encoded)
    notification_decoded = AppNotificationIO.decode_notification_packet(
        AppNotificationIO().xor_decode_buffer(notification_xor)
    )

    # ------------------------------------------------------------------
    # 11. Events / reminders goldens
    # ------------------------------------------------------------------
    events_json = json.dumps(
        {
            "value": [
                {
                    "title": "Standup",
                    "time": {
                        "enabled": True,
                        "repeat_period": "WEEKLY",
                        "start_date": {"year": 2025, "month": "MAY", "day": 16},
                        "end_date": {"year": 2025, "month": "MAY", "day": 17},
                        "days_of_week": ["MONDAY", "FRIDAY"],
                    },
                }
            ]
        }
    )
    events_set_actions = EventsIOFunctional.prepare_watch_commands_set(events_json)
    # Notification frame as delivered on 0x31: [0x31, slot, tp, start(3), end(3), dow].
    reminder_time_frame = bytes(
        [0x31, 0x01, 0x01 | 0x04, 0x25, 0x05, 0x16, 0x25, 0x05, 0x17, 0x02 | 0x20]
    )
    from gshock_api.utils import to_hex_string

    events_decoded_time = EventsIOFunctional.decode_time(
        to_hex_string(reminder_time_frame)[2:]
    )

    # ------------------------------------------------------------------
    # 12. Step counter goldens
    # ------------------------------------------------------------------
    payload = bytearray(400)
    payload[0] = 0x26
    payload[1] = 0x26  # year 2026 BCD
    payload[2] = 0x05  # month
    payload[3] = 0x30  # day
    payload[4] = 0x08  # hour
    payload[5] = 0x45  # minute
    for i in range(144):
        offset = 6 + i * 2
        value = 10 + i
        payload[offset] = value & 0xFF
        payload[offset + 1] = (value >> 8) & 0xFF
    # Two sentinel buckets.
    payload[6] = 0xFE
    payload[7] = 0xFF
    payload[8] = 0xFE
    payload[9] = 0xFF
    for i in range(14):
        offset = 318 + i * 4
        value = 5000 + i
        payload[offset] = value & 0xFF
        payload[offset + 1] = (value >> 8) & 0xFF
        payload[offset + 2] = (value >> 16) & 0xFF
        payload[offset + 3] = (value >> 24) & 0xFF
    # One sentinel day in the history.
    payload[318] = 0xFE
    payload[319] = 0xFF
    payload[320] = 0xFF
    payload[321] = 0xFF
    steps = 12345
    payload[374] = steps & 0xFF
    payload[375] = (steps >> 8) & 0xFF
    payload[376] = (steps >> 16) & 0xFF
    payload[377] = (steps >> 24) & 0xFF

    step_data = StepCounterIOFunctional.parse(bytes(payload))
    step_golden = {
        "timestamp": (
            step_data.timestamp.isoformat() if step_data.timestamp is not None else None
        ),
        "currentDaySteps": step_data.current_day_steps,
        "dayOfWeek": step_data.day_of_week,
        "month": step_data.month,
        "dayOfMonth": step_data.day_of_month,
        "hourlySteps": step_data.hourly_steps,
        "dailyHistory": step_data.daily_history,
        "dailyDistances": step_data.daily_distances,
        "distanceMeters": step_data.distance_meters,
        "totalDistanceMeters": step_data.total_distance_meters,
        "bcdTotalSteps": step_data.bcd_total_steps,
        "warnings": step_data.warnings,
    }

    # ------------------------------------------------------------------
    # 13. GW-BX5600 world-city records
    # ------------------------------------------------------------------
    gw_bx5600_records = GwBx5600TimeIO._build_world_city_records()

    # ------------------------------------------------------------------
    # 14. Button pressed + watch condition goldens
    # ------------------------------------------------------------------
    button_payloads = {
        "upperLeft": bytes([0x10, 0x17, 0x62, 0x07, 0x38, 0x85, 0xCD, 0x7F, 0x01] + [0] * 10),
    }
    button_decodes = {}
    for name, payload_bytes in button_payloads.items():
        button_decodes[name] = ButtonPressedIOFunctional.decode(payload_bytes).name

    condition_payload = bytes([0x28, 9, 21])
    condition_decoded = {
        k: (v.value if hasattr(v, "value") else v)
        for k, v in WatchConditionIOFunctional.decode(condition_payload).items()
    }

    # ------------------------------------------------------------------
    # 16. App info response golden
    # ------------------------------------------------------------------
    app_info_trigger = bytes([0x22] + [0xFF] * 10 + [0x00])
    app_info_response = AppInfoIOFunctional.prepare_watch_response(app_info_trigger)

    # ------------------------------------------------------------------
    # Emit Dart
    # ------------------------------------------------------------------
    lines: list[str] = []
    a = lines.append
    a("// GENERATED by tool/golden/generate_python_goldens.py — do not edit.")
    a("// Golden data extracted by executing the Python reference")
    a("// implementation (gshock_api v2.0.47).")
    a("// Regenerate: cd gshock_api && uv run python \\")
    a("//   ../gshock_api_dart/tool/golden/generate_python_goldens.py")
    a("")
    a("// ignore_for_file: constant_identifier_names")
    a("")
    a("/// A recorded BLE write produced by the Python implementation.")
    a("class GoldenAction {")
    a("  const GoldenAction({required this.handle, required this.data});")
    a("")
    a("  final int handle;")
    a("  final List<int> data;")
    a("}")
    a("")

    a("/// Characteristic UUIDs from `casio_constants.py`.")
    a("const Map<String, String> pythonUuids = <String, String>{")
    for name, value in uuids.items():
        a(f"  '{name}': '{value}',")
    a("};")
    a("")

    a("/// Static handle constants from `casio_constants.py`.")
    a("const Map<String, int> pythonHandles = <String, int>{")
    for name, value in handles.items():
        a(f"  '{name}': 0x{value:02X},")
    a("};")
    a("")

    a("/// CHARACTERISTICS dict (characteristic name -> command code).")
    a("const Map<String, int> pythonCharacteristics = <String, int>{")
    for name, value in characteristics.items():
        a(f"  '{name}': 0x{value:02X},")
    a("};")
    a("")

    a("/// Full EXACT_MODEL_MAP (watch name -> WatchModel enum name).")
    a("const Map<String, String> pythonExactModelMap = <String, String>{")
    for name, model in exact_model_map.items():
        a(f"  '{name}': '{model}',")
    a("};")
    a("")

    a("/// Capability matrix per WatchModel from `resolve_model_info`.")
    a("const Map<String, Map<String, Object?>> pythonModelCapabilities =")
    a("    <String, Map<String, Object?>>{")
    for model_name, entry in capability_matrix.items():
        a(f"  '{model_name}': <String, Object?>{{")
        for field, value in entry.items():
            if isinstance(value, bool):
                a(f"    '{field}': {str(value).lower()},")
            elif isinstance(value, int):
                a(f"    '{field}': {value},")
            else:
                a(f"    '{field}': '{value}',")
        a("  },")
    a("};")
    a("")

    a("/// TIME_ZONE_TABLE rows: (name, zone_name, dst_rules).")
    a("const List<(String, String, int)> pythonTimeZoneTable = <(String, String, int)>[")
    for name, zone_name, rules in tz_table:
        a(
            f"  ('{_esc(name)}', '{_esc(zone_name)}', {rules}),")
    a("];")
    a("")

    a("/// WORLD_CITY_COORDINATES: zone name -> (lat, lon).")
    a("const Map<String, (double, double)> pythonWorldCityCoordinates =")
    a("    <String, (double, double)>{")
    for zone, (lat, lon) in world_city_coordinates.items():
        a(f"  '{zone}': ({lat!r}, {lon!r}),")
    a("};")
    a("")

    a("/// Time encoding goldens (`TimeEncoderPure.encode_current_time`).")
    a("const Map<String, List<int>> pythonTimeEncodings =")
    a("    <String, List<int>>{")
    for key, value in time_goldens.items():
        a(f"  '{key}': {dart_bytes(value)},")
    a("};")
    a("")

    a("/// SET_ALARMS write sequence for a standard watch.")
    a(f"const List<GoldenAction> pythonAlarmsSetActions = {dart_actions(alarms_set_actions)};")
    a("")
    a("/// SET_ALARMS write sequence for MTG-B3000 (first alarm only).")
    a(f"const List<GoldenAction> pythonAlarmsMtgB3000Actions = {dart_actions(alarms_mtg_b3000_actions)};")
    a("")
    a("/// Parsed alarms from a fixed 0x15 notification.")
    a("const List<Map<String, Object?>> pythonAlarmsParsed = <Map<String, Object?>>[")
    for alarm in alarms_parsed:
        a("  <String, Object?>{")
        for k, v in alarm.items():
            if isinstance(v, bool):
                a(f"    '{k}': {str(v).lower()},")
            elif isinstance(v, int):
                a(f"    '{k}': {v},")
            else:
                a(f"    '{k}': '{v}',")
        a("  },")
    a("];")
    a("")

    a("/// Settings encode golden (standard).")
    a(f"const List<int> pythonSettingsEncoded = {dart_bytes(settings_encoded)};")
    a("/// Settings decode golden (standard).")
    a("const Map<String, Object?> pythonSettingsDecoded = <String, Object?>{")
    for k, v in settings_decoded.items():
        if isinstance(v, bool):
            a(f"  '{k}': {str(v).lower()},")
        elif isinstance(v, int):
            a(f"  '{k}': {v},")
        else:
            a(f"  '{k}': '{v}',")
    a("};")
    a("/// Settings encode golden (MTG-B3000).")
    a(f"const List<int> pythonSettingsMtgB3000Encoded = {dart_bytes(settings_mtg_b3000_encoded)};")
    a("/// Settings decode golden (MTG-B3000).")
    a("const Map<String, Object?> pythonSettingsMtgB3000Decoded = <String, Object?>{")
    for k, v in settings_mtg_b3000_decoded.items():
        if isinstance(v, bool):
            a(f"  '{k}': {str(v).lower()},")
        elif isinstance(v, int):
            a(f"  '{k}': {v},")
        else:
            a(f"  '{k}': '{v}',")
    a("};")
    a("")

    a(f"const List<int> pythonTimerEncoded = {dart_bytes(timer_encoded)};")
    a(f"const int pythonTimerDecoded = {timer_decoded};")
    a(f"const List<int> pythonTimerMtgB3000 = {dart_bytes(timer_mtg_b3000)};")
    a(f"const List<GoldenAction> pythonTimerSetActions = {dart_actions(timer_set_actions)};")
    a(f"const List<GoldenAction> pythonTimerMtgB3000SetActions = {dart_actions(timer_mtg_b3000_set_actions)};")
    a("")

    a(f"const List<int> pythonTimeAdjustmentEncoded = {dart_bytes(ta_encoded)};")
    a("const Map<String, String> pythonTimeAdjustmentDecoded = "
        f"{dart_string_map(ta_decoded)};")
    a("")

    a(f"const List<int> pythonWorldCitiesPadded = {dart_bytes(wc_padded)};")
    a("const Map<String, String> pythonParsedCity = "
        f"{dart_string_map(wc_parsed_city)};")
    a("")

    a(f"const List<int> pythonNotificationEncoded = {dart_bytes(notification_encoded)};")
    a(f"const String pythonNotificationXor = '{notification_xor}';")
    a("const Map<String, Object?> pythonNotificationDecoded = <String, Object?>{")
    for k, v in {
        "type": notification_decoded.type.name,
        "timestamp": notification_decoded.timestamp,
        "app": notification_decoded.app,
        "title": notification_decoded.title,
        "text": notification_decoded.text,
        "short_text": notification_decoded.short_text,
    }.items():
        a(f"  '{k}': '{v}',")
    a("};")
    a("")

    a("/// SET_REMINDERS write sequence for a weekly reminder.")
    a(f"const List<GoldenAction> pythonEventsSetActions = {dart_actions(events_set_actions)};")
    a("/// decode_time golden for a fixed weekly reminder frame (JSON).")
    a("const String pythonEventsDecodedTimeJson =")
    a(f"    '{_esc(events_decoded_time)}';")
    a("")

    a("/// Step counter parse golden (synthetic payload with sentinels).")
    a("const Map<String, Object?> pythonStepCounterParsed = <String, Object?>{")
    for k, v in step_golden.items():
        if isinstance(v, bool):
            a(f"  '{k}': {str(v).lower()},")
        elif isinstance(v, (int, float)):
            a(f"  '{k}': {v},")
        elif isinstance(v, list):
            a(f"  '{k}': {json.dumps(v)},")
        else:
            a(f"  '{k}': {json.dumps(v)},")
    a("};")
    a("/// The synthetic 400-byte payload used for the parse golden.")
    a(f"const List<int> pythonStepCounterPayload = {dart_bytes(bytes(payload))};")
    a("")

    a(f"const List<int> pythonGwBx5600Records = {dart_bytes(gw_bx5600_records)};")
    a("")

    a("const Map<String, String> pythonButtonDecodes = "
        f"{dart_string_map(button_decodes)};")
    a("const Map<String, Object?> pythonConditionDecoded = <String, Object?>{")
    for k, v in condition_decoded.items():
        if isinstance(v, bool):
            a(f"  '{k}': {str(v).lower()},")
        elif isinstance(v, int):
            a(f"  '{k}': {v},")
        else:
            a(f"  '{k}': '{v}',")
    a("};")
    a("")

    a("/// App-info response writes for the 0xFF trigger payload.")
    a(f"const List<GoldenAction> pythonAppInfoResponse = {dart_actions(app_info_response)};")
    a("")

    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")

    print(f"Wrote {OUT}")
    print(f"  models={len(exact_model_map)} capabilities={len(capability_matrix)}")
    print(f"  characteristics={len(characteristics)} tz_table={len(tz_table)}")
    print(f"  coords={len(world_city_coordinates)}")


if __name__ == "__main__":
    main()
