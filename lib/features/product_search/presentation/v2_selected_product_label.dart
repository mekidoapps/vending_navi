import 'package:flutter/material.dart';

import '../../../app/theme/v2_color_tokens.dart';
import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_shadows.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../product_master/domain/entities/product.dart';

class V2SelectedProductLabel extends StatelessWidget {
  const V2SelectedProductLabel({
    super.key,
    required this.product,
    required this.onClear,
  });

  final Product product;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return Material(
      key: const Key('selectedProductLabel'),
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
                  Icons.search_rounded,
                  size: 18,
                  color: colors.primaryStrong,
                ),
                const SizedBox(width: V2Spacing.xs),
                Flexible(
                  child: Text(
                    product.name,
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
                  key: const Key('clearSelectedProduct'),
                  tooltip: '商品検索を解除',
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
