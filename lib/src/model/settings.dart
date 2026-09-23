/// {@category Data Models}
///
/// Watch configuration and preferences entity.
///
/// Encapsulates display formatting, button sounds, auto illumination,
/// power saving mode, and automatic Bluetooth time synchronization.
class Settings {
  /// Creates a [Settings] instance.
  Settings({
    this.timeFormat = '',
    this.dateFormat = '',
    this.language = '',
    this.autoLight = false,
    this.lightDuration = '',
    this.powerSavingMode = false,
    this.buttonTone = true,
    this.timeAdjustment = true,
    this.timeAdjustmentMinutesAfterHour = 30,
  });

  /// Time display format (`'12h'` or `'24h'`).
  String timeFormat;

  /// Date format displayed on the LCD (`'DD.MM'` or `'MM.DD'`).
  String dateFormat;

  /// Day of the week language (`'English'`, `'Spanish'`, `'French'`, `'German'`, `'Italian'`, `'Russian'`).
  String language;

  /// Whether auto-light (illuminating display when tilting wrist towards face) is enabled.
  bool autoLight;

  /// Backlight duration (`'1.5s'` or `'3s'`).
  String lightDuration;

  /// Whether power saving sleep mode is active (blanking the display in darkness after inactivity).
  bool powerSavingMode;

  /// Whether button beep sounds / key tone is enabled.
  bool buttonTone;

  /// Whether automatic 4x daily time synchronization is enabled.
  bool timeAdjustment;

  /// Minute offset after the hour for scheduled automatic time synchronization.
  int timeAdjustmentMinutesAfterHour;

  Settings copyWith({
    String? timeFormat,
    String? dateFormat,
    String? language,
    bool? autoLight,
    String? lightDuration,
    bool? powerSavingMode,
    bool? buttonTone,
    bool? timeAdjustment,
    int? timeAdjustmentMinutesAfterHour,
  }) {
    return Settings(
      timeFormat: timeFormat ?? this.timeFormat,
      dateFormat: dateFormat ?? this.dateFormat,
      language: language ?? this.language,
      autoLight: autoLight ?? this.autoLight,
      lightDuration: lightDuration ?? this.lightDuration,
      powerSavingMode: powerSavingMode ?? this.powerSavingMode,
      buttonTone: buttonTone ?? this.buttonTone,
      timeAdjustment: timeAdjustment ?? this.timeAdjustment,
      timeAdjustmentMinutesAfterHour:
          timeAdjustmentMinutesAfterHour ?? this.timeAdjustmentMinutesAfterHour,
    );
  }

  factory Settings.fromJson(Map<String, Object?> json) {
    return Settings(
      timeFormat: (json['time_format'] ?? json['timeFormat'] ?? '') as String,
      dateFormat: (json['date_format'] ?? json['dateFormat'] ?? '') as String,
      language: (json['language'] ?? '') as String,
      autoLight: (json['auto_light'] ?? json['autoLight']) == true,
      lightDuration:
          (json['light_duration'] ?? json['lightDuration'] ?? '') as String,
      powerSavingMode:
          (json['power_saving_mode'] ?? json['powerSavingMode']) == true,
      buttonTone: (json['button_tone'] ?? json['buttonTone']) != false,
      timeAdjustment:
          (json['time_adjustment'] ?? json['timeAdjustment']) != false,
      timeAdjustmentMinutesAfterHour:
          ((json['time_adjustment_minutes_after_hour'] ??
                  json['timeAdjustmentMinutesAfterHour'])
              as int?) ??
          30,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'time_format': timeFormat,
    'date_format': dateFormat,
    'language': language,
    'auto_light': autoLight,
    'light_duration': lightDuration,
    'power_saving_mode': powerSavingMode,
    'button_tone': buttonTone,
    'time_adjustment': timeAdjustment,
    'time_adjustment_minutes_after_hour': timeAdjustmentMinutesAfterHour,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Settings &&
          runtimeType == other.runtimeType &&
          timeFormat == other.timeFormat &&
          dateFormat == other.dateFormat &&
          language == other.language &&
          autoLight == other.autoLight &&
          lightDuration == other.lightDuration &&
          powerSavingMode == other.powerSavingMode &&
          buttonTone == other.buttonTone &&
          timeAdjustment == other.timeAdjustment &&
          timeAdjustmentMinutesAfterHour ==
              other.timeAdjustmentMinutesAfterHour;

  @override
  int get hashCode => Object.hash(
    timeFormat,
    dateFormat,
    language,
    autoLight,
    lightDuration,
    powerSavingMode,
    buttonTone,
    timeAdjustment,
    timeAdjustmentMinutesAfterHour,
  );

  @override
  String toString() =>
      'Settings(timeFormat: $timeFormat, dateFormat: $dateFormat, language: $language, autoLight: $autoLight, lightDuration: $lightDuration, powerSavingMode: $powerSavingMode, buttonTone: $buttonTone, timeAdjustment: $timeAdjustment, timeAdjustmentMinutesAfterHour: $timeAdjustmentMinutesAfterHour)';
}

/// Global settings singleton (mirrors Python's module global `settings`).
final Settings settings = Settings();
