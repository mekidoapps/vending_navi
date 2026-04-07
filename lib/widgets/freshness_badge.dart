import 'package:flutter/material.dart';

import '../utils/freshness_util.dart';

class FreshnessBadge extends StatelessWidget {
  const FreshnessBadge({
    super.key,
    required this.level,
  });

  final FreshnessLevel level;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(level);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        FreshnessUtil.getLabel(level),
        style: TextStyle(
          fontFamily: 'Noto Sans JP',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Color _colorFor(FreshnessLevel level) {
    if (level == FreshnessLevel.veryFresh) {
      return const Color(0xFF2ECC71);
    }
    if (level == FreshnessLevel.fresh) {
      return const Color(0xFF3498DB);
    }
    if (level == FreshnessLevel.normal) {
      return const Color(0xFFF39C12);
    }
    if (level == FreshnessLevel.old) {
      return const Color(0xFF95A5A6);
    }
    return const Color(0xFFBDC3C7);
  }
}