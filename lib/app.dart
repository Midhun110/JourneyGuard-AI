import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'screens/auth/auth_gate.dart';
import 'services/theme_provider.dart';
import 'services/notification_service.dart';
import 'widgets/heads_up_notification_overlay.dart';

class JourneyGuardApp extends StatelessWidget {
  final ThemeProvider? themeProvider;

  const JourneyGuardApp({super.key, this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => themeProvider ?? ThemeProvider(),
        ),
        ChangeNotifierProvider<NotificationService>(
          create: (_) => NotificationService.instance,
        ),
      ],
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
            builder: (context, child) {
              return HeadsUpNotificationOverlay(
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}
