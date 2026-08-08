import 'package:flutter/material.dart';

import '../../../app/theme/v2_color_tokens.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../product_master/domain/entities/product.dart';

class V2FrequentProductsSection extends StatelessWidget {
  const V2FrequentProductsSection({
    super.key,
    required this.products,
    required this.onSelected,
  });

  final List<Product> products;
  final ValueChanged<Product> onSelected;

  @override
  Widget build(BuildContext context) {
    final visibleProducts = products
        .where((product) => product.isSelectable)
        .toList(growable: false);

    if (visibleProducts.isEmpty) {
      return const _EmptyFrequentProducts();
    }

    final colors = V2ColorTokens.of(context);

    return ListView.separated(
      key: const Key('frequentProductsList'),
      padding: EdgeInsets.zero,
      itemCount: visibleProducts.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final product = visibleProducts[index];

        return ListTile(
          key: Key('frequentProduct_${product.id.value}'),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: V2Spacing.xs,
            vertical: V2Spacing.xxs,
          ),
          leading: Icon(
            Icons.favorite_outline_rounded,
            size: 20,
            color: colors.primaryStrong,
          ),
          title: Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: product.genres.isEmpty
              ? null
              : Text(
                  product.genres.take(2).map((genre) => genre.label).join('・'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: colors.textSecondary,
          ),
          onTap: () => onSelected(product),
        );
      },
    );
  }
}

class _EmptyFrequentProducts extends StatelessWidget {
  const _EmptyFrequentProducts();

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 72;

        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(compact ? V2Spacing.xxs : V2Spacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (!compact) ...<Widget>[
                  Icon(
                    Icons.favorite_border_rounded,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(height: V2Spacing.xs),
                ],
                Text(
                  'よく飲む商品はまだありません',
                  key: const Key('frequentProductsEmpty'),
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
