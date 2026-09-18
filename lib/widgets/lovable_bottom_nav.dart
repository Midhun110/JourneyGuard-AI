import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class LovableBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const LovableBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF0C1322) : Colors.white;
    final navBorder = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: navBg,
        border: Border(
          top: BorderSide(color: navBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : const Color(0x0F000000),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore_rounded,
                label: 'Home',
                isDark: isDark,
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.alt_route_outlined,
                activeIcon: Icons.alt_route_rounded,
                label: 'Plan',
                isDark: isDark,
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.cloud_outlined,
                activeIcon: Icons.cloud_rounded,
                label: 'Weather',
                isDark: isDark,
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = currentIndex == index;
    final activeColor = isDark ? AppColors.lovableGreen : Colors.white;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected && !isDark ? AppColors.lightHighlightGradient : null,
          color: isSelected
              ? (isDark ? AppColors.lovableGreen.withValues(alpha: 0.15) : null)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
          border: isSelected && isDark
              ? Border.all(
                  color: AppColors.lovableGreen.withValues(alpha: 0.3),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 20,
              color: isSelected ? activeColor : const Color(0xFF64748B),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: activeColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
