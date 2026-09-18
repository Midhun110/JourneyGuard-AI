import 'package:flutter/material.dart';
import '../main/main_screen.dart';

/// Legacy HomeScreen forwarded directly to [MainScreen] (Lovable UI)
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainScreen();
  }
}
