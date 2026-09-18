import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _keyThemeMode = 'app_theme_mode';
  static const String _keyWeatherAlerts = 'settings_weather_alerts';
  static const String _keySevereAlerts = 'settings_severe_alerts';
  static const String _keyJourneyReminders = 'settings_journey_reminders';
  static const String _keyUseCurrentLocation = 'settings_use_current_location';

  ThemeMode _themeMode = ThemeMode.system;
  bool _weatherAlerts = true;
  bool _severeAlerts = true;
  bool _journeyReminders = true;
  bool _useCurrentLocation = true;
  bool _isInitialized = false;

  SharedPreferences? _prefs;

  ThemeProvider({SharedPreferences? prefs}) {
    if (prefs != null) {
      _prefs = prefs;
      _loadFromPrefs();
    } else {
      _initPrefs();
    }
  }

  ThemeMode get themeMode => _themeMode;
  bool get weatherAlerts => _weatherAlerts;
  bool get severeAlerts => _severeAlerts;
  bool get journeyReminders => _journeyReminders;
  bool get useCurrentLocation => _useCurrentLocation;
  bool get isInitialized => _isInitialized;

  /// Check whether dark mode is active given context
  bool isDarkMode(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    if (_prefs == null) return;

    final savedMode = _prefs!.getString(_keyThemeMode);
    if (savedMode == 'light') {
      _themeMode = ThemeMode.light;
    } else if (savedMode == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }

    _weatherAlerts = _prefs!.getBool(_keyWeatherAlerts) ?? true;
    _severeAlerts = _prefs!.getBool(_keySevereAlerts) ?? true;
    _journeyReminders = _prefs!.getBool(_keyJourneyReminders) ?? true;
    _useCurrentLocation = _prefs!.getBool(_keyUseCurrentLocation) ?? true;

    _isInitialized = true;
    notifyListeners();
  }

  /// Change and persist the theme mode immediately
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    _prefs ??= await SharedPreferences.getInstance();
    final String modeString;
    switch (mode) {
      case ThemeMode.light:
        modeString = 'light';
        break;
      case ThemeMode.dark:
        modeString = 'dark';
        break;
      case ThemeMode.system:
        modeString = 'system';
        break;
    }
    await _prefs!.setString(_keyThemeMode, modeString);
  }

  Future<void> setWeatherAlerts(bool value) async {
    _weatherAlerts = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_keyWeatherAlerts, value);
  }

  Future<void> setSevereAlerts(bool value) async {
    _severeAlerts = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_keySevereAlerts, value);
  }

  Future<void> setJourneyReminders(bool value) async {
    _journeyReminders = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_keyJourneyReminders, value);
  }

  Future<void> setUseCurrentLocation(bool value) async {
    _useCurrentLocation = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_keyUseCurrentLocation, value);
  }
}
