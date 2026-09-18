import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'screens/main/main_screen.dart';
import 'services/theme_provider.dart';

class JourneyGuardApp extends StatelessWidget {
  final ThemeProvider? themeProvider;

  const JourneyGuardApp({super.key, this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ThemeProvider>(
      create: (_) => themeProvider ?? ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: 'JourneyGuard AI',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: theme.themeMode,
            themeAnimationDuration: const Duration(milliseconds: 300),
            themeAnimationCurve: Curves.easeInOut,
            home: const MainScreen(),
          );
        },
      ),
    );
  }
}
