import 'package:flutter/material.dart';

import '../../core/enums/app_enums.dart';

class ReliabilityBadge extends StatelessWidget {
  final ConfidenceLevel confidence;
  final bool compact;

  const ReliabilityBadge({
    super.key,
    required this.confidence,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final _BadgeStyle style = _styleOf(confidence);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: style.backgroundColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: style.backgroundColor.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            style.icon,
            size: compact ? 14 : 16,
            color: style.foregroundColor ?? colorScheme.onSurface,
          ),
          const SizedBox(width: 4),
          Text(
            style.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: style.foregroundColor ?? colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeStyle _styleOf(ConfidenceLevel value) {
    switch (value) {
      case ConfidenceLevel.high:
        return const _BadgeStyle(
          label: '信頼度高',
          icon: Icons.verified_outlined,
          backgroundColor: Color(0xFF2E7D32),
          foregroundColor: Color(0xFF1B5E20),
        );
      case ConfidenceLevel.medium:
        return const _BadgeStyle(
          label: '信頼度中',
          icon: Icons.info_outline,
          backgroundColor: Color(0xFFF9A825),
          foregroundColor: Color(0xFF8D6E00),
        );
      case ConfidenceLevel.low:
        return const _BadgeStyle(
          label: '信頼度低',
          icon: Icons.help_outline,
          backgroundColor: Color(0xFFD84315),
          foregroundColor: Color(0xFF8C2F0C),
        );
    }
  }
}

class _BadgeStyle {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color? foregroundColor;

  const _BadgeStyle({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    this.foregroundColor,
  });
}