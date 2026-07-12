import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../theme/color_tokens.dart';

/// Gradient metric card for compact energy KPIs.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.trendLabel,
    this.isTrendPositive = true,
    this.onTap,
    this.footer,
  });

  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final String? trendLabel;
  final bool isTrendPositive;
  final VoidCallback? onTap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final trendColor = isTrendPositive
        ? ColorTokens.success
        : ColorTokens.danger;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ColorTokens.surface, ColorTokens.surfaceElevated],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.22)),
            boxShadow: const [
              BoxShadow(
                color: ColorTokens.shadow,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      style: AppTextStyles.mono.copyWith(fontSize: 24),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(unit, style: AppTextStyles.caption),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(title, style: AppTextStyles.caption, maxLines: 1),
              if (footer != null) ...[const SizedBox(height: 8), footer!],
              if (trendLabel != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      isTrendPositive
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      color: trendColor,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        trendLabel!,
                        style: AppTextStyles.caption.copyWith(
                          color: trendColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
