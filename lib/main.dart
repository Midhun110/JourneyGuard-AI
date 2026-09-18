import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'services/theme_provider.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final themeProvider = ThemeProvider(prefs: prefs);

  // Initialize Supabase Auth, Storage & PostGIS Service
  await SupabaseService.instance.init();

  runApp(JourneyGuardApp(themeProvider: themeProvider));
}
