import 'package:flutter/material.dart';

import '../../../app/theme/v2_color_tokens.dart';
import '../../../app/theme/v2_spacing.dart';

class V2EmptyState extends StatelessWidget {
  const V2EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.local_drink_outlined,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return Padding(
      padding: const EdgeInsets.all(V2Spacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 36, color: colors.primaryStrong),
          const SizedBox(height: V2Spacing.xs),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: V2Spacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
