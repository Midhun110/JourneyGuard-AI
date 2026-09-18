import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:journey_guard_ai/core/theme/app_theme.dart';
import 'package:journey_guard_ai/screens/auth/auth_gate.dart';
import 'package:journey_guard_ai/screens/auth/auth_screen.dart';
import 'package:journey_guard_ai/screens/main/main_screen.dart';
import 'package:journey_guard_ai/services/supabase_service.dart';
import 'package:journey_guard_ai/services/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ThemeProvider themeProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    themeProvider = ThemeProvider(prefs: prefs);

    // Initialize Supabase in safe test mode
    await SupabaseService.instance.init();
    await SupabaseService.instance.signOut();
  });

  Widget buildTestableWidget(Widget child) {
    return ChangeNotifierProvider<ThemeProvider>.value(
      value: themeProvider,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        home: child,
      ),
    );
  }

  group('Module E — AuthGate & App Launch Routing Tests', () {
    testWidgets('App launch with no session displays AuthScreen before dashboard', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SupabaseService.instance.sessionNotifier.value = false;

      await tester.pumpWidget(buildTestableWidget(const AuthGate()));
      await tester.pumpAndSettle();

      // Verify AuthScreen is shown
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.byType(MainScreen), findsNothing);
      expect(find.text('JourneyGuard AI'), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Sign In with Email'), findsOneWidget);
      expect(find.text('Continue as Guest (1-Tap Anonymous Auth)'), findsOneWidget);
    });

    testWidgets('App launch with active session directly displays MainScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await SupabaseService.instance.signInAnonymously();

      await tester.pumpWidget(buildTestableWidget(const AuthGate()));
      await tester.pumpAndSettle();

      // Verify MainScreen is shown
      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.byType(AuthScreen), findsNothing);
    });

    testWidgets('Session change dynamically transitions AuthGate between screens', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SupabaseService.instance.sessionNotifier.value = false;

      await tester.pumpWidget(buildTestableWidget(const AuthGate()));
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsOneWidget);

      // Simulate login
      SupabaseService.instance.sessionNotifier.value = true;
      await tester.pumpAndSettle();

      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.byType(AuthScreen), findsNothing);

      // Simulate logout
      SupabaseService.instance.sessionNotifier.value = false;
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsOneWidget);
    });
  });

  group('Module E — AuthScreen UI & Mode Switching Tests', () {
    testWidgets('Renders Login mode initially with email & password fields', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(const AuthScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsNothing);
      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('Switching to Sign Up mode adds Confirm Password field', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(const AuthScreen()));
      await tester.pumpAndSettle();

      // Tap Sign Up link
      final signUpLink = find.text('Sign Up');
      await tester.ensureVisible(signUpLink);
      await tester.tap(signUpLink);
      await tester.pumpAndSettle();

      expect(find.text('Create Your Account'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Already have an account? '), findsOneWidget);
    });

    testWidgets('Switching to Forgot Password mode shows password reset UI', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(const AuthScreen()));
      await tester.pumpAndSettle();

      // Tap Forgot password?
      final forgotLink = find.text('Forgot password?');
      await tester.ensureVisible(forgotLink);
      await tester.tap(forgotLink);
      await tester.pumpAndSettle();

      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Send Reset Instructions'), findsOneWidget);
      expect(find.text('Back to Log In'), findsOneWidget);
      expect(find.text('Password'), findsNothing);
    });

    testWidgets('Continue as Guest activates session and sets isAnonymous true', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestableWidget(const AuthScreen()));
      await tester.pumpAndSettle();

      final guestButton = find.text('Continue as Guest (1-Tap Anonymous Auth)');
      expect(guestButton, findsOneWidget);

      await tester.ensureVisible(guestButton);
      await tester.pumpAndSettle();

      await tester.tap(guestButton);
      await tester.pumpAndSettle();

      expect(SupabaseService.instance.isAuthenticated, isTrue);
      expect(SupabaseService.instance.isAnonymous, isTrue);
      expect(SupabaseService.instance.sessionNotifier.value, isTrue);
    });
  });

  group('Module E — SupabaseService Session Persistence & Methods', () {
    test('signInWithEmailPassword updates session state and persistence', () async {
      await SupabaseService.instance.signInWithEmailPassword(
        email: 'commuter@journeyguard.ai',
        password: 'password123',
      );

      expect(SupabaseService.instance.isAuthenticated, isTrue);
      expect(SupabaseService.instance.userEmail, equals('commuter@journeyguard.ai'));
      expect(SupabaseService.instance.sessionNotifier.value, isTrue);
    });

    test('signOut clears active session and resets sessionNotifier', () async {
      await SupabaseService.instance.signInAnonymously();
      expect(SupabaseService.instance.isAuthenticated, isTrue);

      await SupabaseService.instance.signOut();
      expect(SupabaseService.instance.isAuthenticated, isFalse);
      expect(SupabaseService.instance.sessionNotifier.value, isFalse);
    });

    test('resetPasswordForEmail executes safely', () async {
      expect(
        () => SupabaseService.instance.resetPasswordForEmail(email: 'test@example.com'),
        returnsNormally,
      );
    });
  });
}
