import 'package:flutter/material.dart';

import '../../../app/theme/v2_color_tokens.dart';
import '../../../app/theme/v2_spacing.dart';
import '../buttons/v2_secondary_button.dart';

class V2ErrorState extends StatelessWidget {
  const V2ErrorState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return Padding(
      padding: const EdgeInsets.all(V2Spacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.error_outline_rounded, size: 36, color: colors.error),
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
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: V2Spacing.md),
            V2SecondaryButton(
              label: '再試行',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}
