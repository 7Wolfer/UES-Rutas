import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Inyectado en `main()` una vez que SharedPreferences está listo.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Se sobreescribe en main()'),
);

@immutable
class Settings {
  const Settings({
    this.themeMode = ThemeMode.system,
    this.textScale = 1.0,
    this.highContrast = false,
  });

  final ThemeMode themeMode;
  final double textScale;
  final bool highContrast;

  Settings copyWith({
    ThemeMode? themeMode,
    double? textScale,
    bool? highContrast,
  }) =>
      Settings(
        themeMode: themeMode ?? this.themeMode,
        textScale: textScale ?? this.textScale,
        highContrast: highContrast ?? this.highContrast,
      );
}

class SettingsController extends Notifier<Settings> {
  static const _kTheme = 'ajustes.themeMode';
  static const _kScale = 'ajustes.textScale';
  static const _kContrast = 'ajustes.highContrast';

  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  Settings build() {
    final p = _prefs;
    return Settings(
      themeMode: ThemeMode.values.byNameOr(
        p.getString(_kTheme),
        ThemeMode.system,
      ),
      textScale: p.getDouble(_kScale) ?? 1.0,
      highContrast: p.getBool(_kContrast) ?? false,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(_kTheme, mode.name);
  }

  Future<void> setTextScale(double scale) async {
    final s = scale.clamp(0.85, 1.5).toDouble();
    state = state.copyWith(textScale: s);
    await _prefs.setDouble(_kScale, s);
  }

  Future<void> setHighContrast(bool value) async {
    state = state.copyWith(highContrast: value);
    await _prefs.setBool(_kContrast, value);
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, Settings>(SettingsController.new);

extension<T extends Enum> on Iterable<T> {
  T byNameOr(String? name, T fallback) {
    if (name == null) return fallback;
    for (final v in this) {
      if (v.name == name) return v;
    }
    return fallback;
  }
}
