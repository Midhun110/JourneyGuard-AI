import 'package:flutter/material.dart';
import '../../widgets/lovable_bottom_nav.dart';
import 'tabs/lovable_home_tab.dart';
import 'tabs/lovable_plan_tab.dart';
import 'tabs/lovable_weather_tab.dart';
import 'tabs/lovable_profile_tab.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          LovableHomeTab(
            onSwitchToPlan: () => _onItemTapped(1),
          ),
          const LovablePlanTab(),
          const LovableWeatherTab(),
          const LovableProfileTab(),
        ],
      ),
      bottomNavigationBar: LovableBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
