import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_constants.dart';
import '../models/incident_report.dart';

/// Module D (Incident Reporting & PostGIS Storage) & Module E (Supabase Auth)
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  static const String _prefKeyDemoGuestSession = 'journeyguard_demo_guest_active';
  static const String _prefKeyDemoUserEmail = 'journeyguard_demo_user_email';

  bool _isInitialized = false;
  bool _isAvailable = false;
  String? _lastError;

  bool _isDemoGuest = false;
  String? _demoUserEmail;

  /// Reactive notifier for active session state (used by AuthGate)
  final ValueNotifier<bool> sessionNotifier = ValueNotifier<bool>(false);

  bool get isAvailable => _isAvailable;
  String? get lastError => _lastError;

  SupabaseClient? get client {
    if (!_isInitialized || !_isAvailable) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Initialize Supabase with project credentials and restore persisted session
  Future<void> init({String? url, String? anonKey}) async {
    if (_isInitialized) return;

    // 1. Restore local session flags (guest or demo auth)
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDemoGuest = prefs.getBool(_prefKeyDemoGuestSession) ?? false;
      _demoUserEmail = prefs.getString(_prefKeyDemoUserEmail);
    } catch (_) {}

    final supabaseUrl = url ?? SupabaseConstants.supabaseUrl;
    final supabaseAnonKey = anonKey ?? SupabaseConstants.supabaseAnonKey;

    // Check if using default placeholder credentials
    if (supabaseUrl.contains('xyzcompany') || supabaseAnonKey.contains('dummy_key')) {
      _isInitialized = true;
      _isAvailable = false;
      sessionNotifier.value = _isDemoGuest || (_demoUserEmail != null);
      debugPrint('[SupabaseService] Operating in Resilient Local Demo Mode (default placeholder keys detected)');
      return;
    }

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        debug: kDebugMode,
      );
      _isInitialized = true;
      _isAvailable = true;

      // Check for live persisted session
      final hasLiveSession = client?.auth.currentSession != null;
      sessionNotifier.value = hasLiveSession || _isDemoGuest || (_demoUserEmail != null);

      // Listen for session changes
      client?.auth.onAuthStateChange.listen((data) {
        final hasSession = data.session != null || _isDemoGuest || (_demoUserEmail != null);
        sessionNotifier.value = hasSession;
      });

      debugPrint('[SupabaseService] Connected successfully to $supabaseUrl (Session active: ${sessionNotifier.value})');
    } catch (e) {
      _isInitialized = true;
      _isAvailable = false;
      _lastError = e.toString();
      sessionNotifier.value = _isDemoGuest || (_demoUserEmail != null);
      debugPrint('[SupabaseService] Initialization warning (falling back to resilient local mode): $e');
    }
  }

  // ─── Module E: Supabase Authentication ─────────────────────────────────────

  User? get currentUser => client?.auth.currentUser;
  String? get currentUserId => client?.auth.currentUser?.id ?? (_isDemoGuest ? 'guest-demo-id' : 'demo-user-id');
  bool get isAuthenticated =>
      (client?.auth.currentSession != null) || _isDemoGuest || (_demoUserEmail != null);
  bool get isAnonymous =>
      (client?.auth.currentUser?.isAnonymous ?? false) || _isDemoGuest;

  String? get userEmail =>
      client?.auth.currentUser?.email ?? _demoUserEmail ?? (_isDemoGuest ? 'guest@journeyguard.demo' : null);

  Stream<AuthState>? get authStateChanges => client?.auth.onAuthStateChange;

  /// Module E: Email & Password Sign In
  Future<AuthResponse?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    _demoUserEmail = email.trim();
    _isDemoGuest = false;

    if (!_isAvailable || client == null) {
      debugPrint('[SupabaseService] Offline/demo login simulation for: $email');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyDemoUserEmail, email.trim());
      await prefs.remove(_prefKeyDemoGuestSession);
      sessionNotifier.value = true;
      return null;
    }
    try {
      final response = await client!.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyDemoUserEmail, email.trim());
      await prefs.remove(_prefKeyDemoGuestSession);
      sessionNotifier.value = true;
      return response;
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    }
  }

  /// Module E: Email & Password Sign Up
  Future<AuthResponse?> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    _demoUserEmail = email.trim();
    _isDemoGuest = false;

    if (!_isAvailable || client == null) {
      debugPrint('[SupabaseService] Offline/demo signup simulation for: $email');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyDemoUserEmail, email.trim());
      await prefs.remove(_prefKeyDemoGuestSession);
      sessionNotifier.value = true;
      return null;
    }
    try {
      final response = await client!.auth.signUp(
        email: email.trim(),
        password: password,
      );
      if (response.session != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefKeyDemoUserEmail, email.trim());
        await prefs.remove(_prefKeyDemoGuestSession);
        sessionNotifier.value = true;
      }
      return response;
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    }
  }

  /// Module E: 1-Tap Anonymous Guest Demo Sign-In
  ///
  /// As specified for hackathon demo: allows immediate incident reporting
  /// and exploration without forcing judges to register an email account.
  Future<AuthResponse?> signInAnonymously() async {
    _isDemoGuest = true;
    _demoUserEmail = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyDemoGuestSession, true);
      await prefs.remove(_prefKeyDemoUserEmail);
    } catch (_) {}

    if (!_isAvailable || client == null) {
      debugPrint('[SupabaseService] Anonymous session active (local simulation)');
      sessionNotifier.value = true;
      return null;
    }
    try {
      final response = await client!.auth.signInAnonymously();
      debugPrint('[SupabaseService] Anonymous guest signed in: ${response.user?.id}');
      sessionNotifier.value = true;
      return response;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[SupabaseService] signInAnonymously fallback: $e');
      sessionNotifier.value = true;
      return null;
    }
  }

  /// Module E: Forgot Password / Password Reset Email
  Future<void> resetPasswordForEmail({required String email}) async {
    if (!_isAvailable || client == null) {
      debugPrint('[SupabaseService] Demo password reset email sent to: $email');
      return;
    }
    try {
      await client!.auth.resetPasswordForEmail(email.trim());
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    }
  }

  /// Sign Out and clear local session flags
  Future<void> signOut() async {
    _isDemoGuest = false;
    _demoUserEmail = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyDemoGuestSession);
      await prefs.remove(_prefKeyDemoUserEmail);
    } catch (_) {}

    if (_isAvailable && client != null) {
      try {
        await client!.auth.signOut();
      } catch (_) {}
    }
    sessionNotifier.value = false;
  }

  // ─── Module D: Supabase Storage for Incident Photos ────────────────────────

  /// Uploads photo to Supabase Storage bucket 'incident-photos' and returns public URL
  Future<String?> uploadIncidentPhoto(File photoFile) async {
    if (!_isAvailable || client == null) {
      debugPrint('[SupabaseService] Storage offline: using local file reference ${photoFile.path}');
      return photoFile.path;
    }

    try {
      final ext = photoFile.path.split('.').last.toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${photoFile.hashCode}.$ext';
      final path = 'reports/$fileName';

      final fileBytes = await photoFile.readAsBytes();
      await client!.storage
          .from(SupabaseConstants.storageBucketIncidentPhotos)
          .uploadBinary(
            path,
            fileBytes,
            fileOptions: FileOptions(
              contentType: 'image/${ext == 'png' ? 'png' : 'jpeg'}',
              upsert: true,
            ),
          );

      final publicUrl = client!.storage
          .from(SupabaseConstants.storageBucketIncidentPhotos)
          .getPublicUrl(path);

      debugPrint('[SupabaseService] Photo uploaded successfully to: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('[SupabaseService] Storage upload fallback: $e');
      return photoFile.path;
    }
  }

  // ─── Module D: PostgreSQL + PostGIS Incident Database Operations ───────────

  /// Insert newly reported incident into PostgreSQL 'incidents' table
  Future<IncidentReport?> insertIncident(IncidentReport report) async {
    if (!_isAvailable || client == null) {
      debugPrint('[SupabaseService] Local mode: Incident logged locally: ${report.toJson()}');
      return report;
    }

    try {
      final insertData = report.toSupabaseInsertMap();
      insertData['reporter_id'] = currentUserId;

      final res = await client!
          .from(SupabaseConstants.tableIncidents)
          .insert(insertData)
          .select()
          .single();

      debugPrint('[SupabaseService] Incident persisted in PostGIS database: ${res['id']}');
      return IncidentReport.fromSupabase(res);
    } catch (e) {
      debugPrint('[SupabaseService] Database insert fallback (using local cache): $e');
      return report;
    }
  }

  /// Module D & B: Query nearby incidents using PostGIS RPC (ST_DWithin)
  Future<List<IncidentReport>> fetchNearbyIncidents({
    required double lat,
    required double lng,
    double radiusMeters = 10000.0,
  }) async {
    if (!_isAvailable || client == null) {
      return [];
    }

    try {
      // 1. Try PostGIS RPC function
      final response = await client!.rpc(
        SupabaseConstants.rpcGetIncidentsNear,
        params: {
          'lat': lat,
          'lng': lng,
          'radius_meters': radiusMeters,
        },
      );

      if (response is List) {
        return response
            .map((row) => IncidentReport.fromSupabase(row as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // 2. Fallback: Query incidents table directly
      try {
        final rows = await client!
            .from(SupabaseConstants.tableIncidents)
            .select()
            .order('created_at', ascending: false)
            .limit(50);

        return rows
            .map((row) => IncidentReport.fromSupabase(row))
            .toList();
      } catch (_) {}
    }

    return [];
  }
}
