import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

class RiskBadge extends StatelessWidget {
  final double score;
  final bool large;

  const RiskBadge({super.key, required this.score, this.large = false});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.riskColor(score);
    final label = AppColors.riskLabel(score);

    if (large) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            score.toStringAsFixed(0),
            style: AppTypography.riskScore.copyWith(color: color),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Text(
              label.toUpperCase(),
              style: AppTypography.labelSmall.copyWith(
                color: color,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label ${score.toStringAsFixed(0)}%',
            style: AppTypography.labelSmall.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
