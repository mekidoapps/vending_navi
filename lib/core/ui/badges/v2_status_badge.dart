import 'package:flutter/material.dart';

import '../../../app/theme/v2_color_tokens.dart';
import '../../../app/theme/v2_radius.dart';

enum V2StatusBadgeType { confirmed, inferred, stale }

class V2StatusBadge extends StatelessWidget {
  const V2StatusBadge({super.key, required this.type});

  final V2StatusBadgeType type;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);
    final presentation = switch (type) {
      V2StatusBadgeType.confirmed => (
        label: '確認済み',
        icon: Icons.check_circle_rounded,
        foreground: colors.confirmed,
        background: colors.primarySoft,
      ),
      V2StatusBadgeType.inferred => (
        label: 'あるかも',
        icon: Icons.help_rounded,
        foreground: colors.primaryStrong,
        background: colors.inferred.withValues(alpha: 0.20),
      ),
      V2StatusBadgeType.stale => (
        label: '以前の情報',
        icon: Icons.schedule_rounded,
        foreground: colors.stale,
        background: colors.stale.withValues(alpha: 0.14),
      ),
    };

    return Semantics(
      label: presentation.label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: presentation.background,
          borderRadius: V2Radius.chip,
          border: Border.all(
            color: presentation.foreground.withValues(alpha: 0.35),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(presentation.icon, size: 16, color: presentation.foreground),
              const SizedBox(width: 6),
              Text(
                presentation.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: presentation.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
