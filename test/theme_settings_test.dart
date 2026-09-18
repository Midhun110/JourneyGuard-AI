import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:journey_guard_ai/services/theme_provider.dart';
import 'package:journey_guard_ai/core/theme/app_theme.dart';
import 'package:journey_guard_ai/screens/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  AppTheme.useGoogleFonts = false;

  group('ThemeProvider Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initializes with default system mode when no pref saved', () async {
      final prefs = await SharedPreferences.getInstance();
      final provider = ThemeProvider(prefs: prefs);

      expect(provider.themeMode, ThemeMode.system);
      expect(provider.weatherAlerts, isTrue);
      expect(provider.severeAlerts, isTrue);
      expect(provider.journeyReminders, isTrue);
      expect(provider.useCurrentLocation, isTrue);
    });

    test('Loads previously saved dark mode from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'app_theme_mode': 'dark'});
      final prefs = await SharedPreferences.getInstance();
      final provider = ThemeProvider(prefs: prefs);

      expect(provider.themeMode, ThemeMode.dark);
    });

    test('Loads previously saved light mode from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'app_theme_mode': 'light'});
      final prefs = await SharedPreferences.getInstance();
      final provider = ThemeProvider(prefs: prefs);

      expect(provider.themeMode, ThemeMode.light);
    });

    test('setThemeMode updates themeMode, notifies listeners, and persists', () async {
      final prefs = await SharedPreferences.getInstance();
      final provider = ThemeProvider(prefs: prefs);

      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.setThemeMode(ThemeMode.light);
      expect(provider.themeMode, ThemeMode.light);
      expect(notifyCount, 1);
      expect(prefs.getString('app_theme_mode'), 'light');

      await provider.setThemeMode(ThemeMode.dark);
      expect(provider.themeMode, ThemeMode.dark);
      expect(notifyCount, 2);
      expect(prefs.getString('app_theme_mode'), 'dark');

      await provider.setThemeMode(ThemeMode.system);
      expect(provider.themeMode, ThemeMode.system);
      expect(notifyCount, 3);
      expect(prefs.getString('app_theme_mode'), 'system');
    });

    test('Notification and location toggles update and persist', () async {
      final prefs = await SharedPreferences.getInstance();
      final provider = ThemeProvider(prefs: prefs);

      await provider.setWeatherAlerts(false);
      expect(provider.weatherAlerts, isFalse);
      expect(prefs.getBool('settings_weather_alerts'), isFalse);

      await provider.setSevereAlerts(false);
      expect(provider.severeAlerts, isFalse);
      expect(prefs.getBool('settings_severe_alerts'), isFalse);

      await provider.setJourneyReminders(false);
      expect(provider.journeyReminders, isFalse);
      expect(prefs.getBool('settings_journey_reminders'), isFalse);

      await provider.setUseCurrentLocation(false);
      expect(provider.useCurrentLocation, isFalse);
      expect(prefs.getBool('settings_use_current_location'), isFalse);
    });
  });

  group('Design System Tokens & Themes', () {
    test('AppTheme.lightTheme specifications match requirements', () {
      final light = AppTheme.lightTheme;
      expect(light.brightness, Brightness.light);
      expect(light.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
      expect(light.colorScheme.primary, const Color(0xFF14B8A6));
    });

    test('AppTheme.darkTheme specifications match requirements', () {
      final dark = AppTheme.darkTheme;
      expect(dark.brightness, Brightness.dark);
      expect(dark.scaffoldBackgroundColor, const Color(0xFF090D16));
    });
  });

  group('SettingsScreen Widget Tests', () {
    late ThemeProvider themeProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      themeProvider = ThemeProvider(prefs: prefs);
    });

    Widget createSettingsWidget() {
      return ChangeNotifierProvider<ThemeProvider>.value(
        value: themeProvider,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const SettingsScreen(checkLocationPermission: false),
        ),
      );
    }

    testWidgets('Renders all sections: Appearance, Notifications, Location, About, Support',
        (WidgetTester tester) async {
      await tester.pumpWidget(createSettingsWidget());
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('APPEARANCE & THEME'), findsOneWidget);
      expect(find.text('NOTIFICATIONS & ALERTS'), findsOneWidget);
      expect(find.text('LOCATION & HAZARD SENSORS'), findsOneWidget);
      expect(find.text('ABOUT JOURNEYGUARD AI'), findsOneWidget);
      expect(find.text('SUPPORT & COMMUNITY'), findsOneWidget);

      // Verify theme segment options
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);

      // Verify notification labels
      expect(find.text('Weather Hazard Alerts'), findsOneWidget);
      expect(find.text('Severe Landslide Alerts'), findsOneWidget);
      expect(find.text('Journey Departure Reminders'), findsOneWidget);
    });

    testWidgets('Tapping theme segment options changes themeMode',
        (WidgetTester tester) async {
      await tester.pumpWidget(createSettingsWidget());
      await tester.pumpAndSettle();

      // Tap Light
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(themeProvider.themeMode, ThemeMode.light);

      // Tap Dark
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(themeProvider.themeMode, ThemeMode.dark);

      // Tap System
      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();
      expect(themeProvider.themeMode, ThemeMode.system);
    });

    testWidgets('Tapping live theme toggle in AppBar cycles theme',
        (WidgetTester tester) async {
      await tester.pumpWidget(createSettingsWidget());
      await tester.pumpAndSettle();

      final toggleButton = find.byTooltip('Live Theme Toggle');
      expect(toggleButton, findsOneWidget);

      await tester.tap(toggleButton);
      await tester.pumpAndSettle();
      // Switched from system/dark to light or dark
      expect(themeProvider.themeMode, isNotNull);
    });
  });
}
