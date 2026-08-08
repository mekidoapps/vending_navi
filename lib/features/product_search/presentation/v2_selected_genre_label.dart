import 'package:flutter/material.dart';

import '../../../app/theme/v2_color_tokens.dart';
import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_shadows.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../product_master/domain/entities/product_genre.dart';

class V2SelectedGenreLabel extends StatelessWidget {
  const V2SelectedGenreLabel({
    super.key,
    required this.genre,
    required this.onClear,
  });

  final ProductGenre genre;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return Material(
      key: const Key('selectedGenreLabel'),
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceElevated.withValues(alpha: 0.98),
            borderRadius: V2Radius.control,
            border: Border.all(color: colors.primary.withValues(alpha: 0.55)),
            boxShadow: V2Shadows.mapFloating,
          ),
          child: Padding(
            padding: const EdgeInsets.only(
              left: V2Spacing.sm,
              top: V2Spacing.xxs,
              bottom: V2Spacing.xxs,
              right: V2Spacing.xxs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.category_outlined,
                  size: 18,
                  color: colors.primaryStrong,
                ),
                const SizedBox(width: V2Spacing.xs),
                Flexible(
                  child: Text(
                    genre.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: V2Spacing.xxs),
                IconButton(
                  key: const Key('clearSelectedGenre'),
                  tooltip: 'ジャンル検索を解除',
                  visualDensity: VisualDensity.compact,
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
