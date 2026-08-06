import 'package:flutter/material.dart';

import '../../../app/theme/v2_color_tokens.dart';
import '../../../app/theme/v2_spacing.dart';

class V2LoadingState extends StatelessWidget {
  const V2LoadingState({super.key, this.message = '読み込み中です'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return Semantics(
      liveRegion: true,
      label: message,
      child: Padding(
        padding: const EdgeInsets.all(V2Spacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(color: colors.primaryStrong),
            const SizedBox(height: V2Spacing.sm),
            Text(message, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
