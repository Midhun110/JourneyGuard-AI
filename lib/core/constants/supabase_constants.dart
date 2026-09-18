import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SupabaseConstants {
  SupabaseConstants._();

  // Supabase Project Credentials
  // Set your active project URL and anon key here or via --dart-define
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xyzcompany.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy_key',
  );

  // Database & Storage Identifiers
  static const String tableIncidents = 'incidents';
  static const String storageBucketIncidentPhotos = 'incident-photos';
  static const String rpcGetIncidentsNear = 'get_incidents_near';

  // Standard Module D Incident Types
  static const String typeFlood = 'flood';
  static const String typeLandslide = 'landslide';
  static const String typeFallenTree = 'fallen_tree';
  static const String typeRoadDamage = 'road_damage';
  static const String typeWaterlogging = 'waterlogging';
  static const String typeOther = 'other';

  static const List<String> allTypes = [
    typeFlood,
    typeLandslide,
    typeFallenTree,
    typeRoadDamage,
    typeWaterlogging,
    typeOther,
  ];

  static String getDisplayName(String type) {
    switch (type.toLowerCase()) {
      case typeFlood:
        return 'Flash Flood';
      case typeLandslide:
        return 'Landslide / Rockfall';
      case typeFallenTree:
        return 'Fallen Tree';
      case typeRoadDamage:
        return 'Road Washout / Crack';
      case typeWaterlogging:
        return 'Severe Waterlogging';
      default:
        return 'Hazard / Obstruction';
    }
  }

  static IconData getIcon(String type) {
    switch (type.toLowerCase()) {
      case typeFlood:
        return Icons.flood_rounded;
      case typeLandslide:
        return Icons.landslide_rounded;
      case typeFallenTree:
        return Icons.park_rounded;
      case typeRoadDamage:
        return Icons.warning_rounded;
      case typeWaterlogging:
        return Icons.water_rounded;
      default:
        return Icons.report_problem_rounded;
    }
  }

  static Color getColor(String type) {
    switch (type.toLowerCase()) {
      case typeFlood:
      case typeLandslide:
        return AppColors.riskCritical;
      case typeRoadDamage:
      case typeWaterlogging:
        return AppColors.riskHigh;
      case typeFallenTree:
        return AppColors.riskModerate;
      default:
        return AppColors.accentIndigo;
    }
  }
}
