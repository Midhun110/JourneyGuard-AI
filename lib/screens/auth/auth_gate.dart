import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../main/main_screen.dart';
import 'auth_screen.dart';

/// Module E: Authentication Gate
///
/// Directs user flow on app launch:
/// - If no active Supabase session exists → displays [AuthScreen] (Login / Sign Up / Guest Demo).
/// - If an active session exists → displays [MainScreen] (JourneyGuard Home / Dashboard).
///
/// Reacts to login, guest demo authentication, and logout events.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    if (SupabaseService.instance.isAuthenticated) {
      SupabaseService.instance.sessionNotifier.value = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SupabaseService.instance.sessionNotifier,
      builder: (context, isAuthenticated, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: isAuthenticated
              ? const MainScreen(key: ValueKey('MainScreen'))
              : const AuthScreen(key: ValueKey('AuthScreen')),
        );
      },
    );
  }
}
