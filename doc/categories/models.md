# Data Models

Strongly-typed value objects and capability metadata representing watch states, alarms, events, notifications, and model profiles.

## Models
- `Alarm` & `Alarms`: Watch alarms and hourly chime configuration.
- `AppNotification` & `NotificationType`: Push alerts and XOR-255 encrypted notifications.
- `Event` & `EventDate`: Calendar reminders and repeat schedules.
- `Settings`: Display preferences, key tones, auto light switch, illumination duration, and power-saving modes.
- `StepCounterData`: Lifelog step counts, daily totals, and 24-hour hourly buckets.
- `WatchInfo` & `ModelInfo` & `WatchModel`: Watch family capability detection and dialect flags.
