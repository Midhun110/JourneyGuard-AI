import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'services/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final themeProvider = ThemeProvider(prefs: prefs);
  runApp(JourneyGuardApp(themeProvider: themeProvider));
}
