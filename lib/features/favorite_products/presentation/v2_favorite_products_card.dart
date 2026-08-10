import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../product_master/domain/entities/product.dart';
import '../application/favorite_products_controller.dart';
import 'v2_favorite_product_picker.dart';

class V2FavoriteProductsCard extends ConsumerWidget {
  const V2FavoriteProductsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(favoriteProductsControllerProvider);

    return Card(
      key: const Key('favoriteProductsCard'),
      shape: const RoundedRectangleBorder(borderRadius: V2Radius.card),
      child: Padding(
        padding: const EdgeInsets.all(V2Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.local_drink_outlined),
                const SizedBox(width: V2Spacing.sm),
                Expanded(
                  child: Text(
                    'よく飲む商品',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const Key('favoriteProductsAddButton'),
                  onPressed: state.isLoading || state.isMutating
                      ? null
                      : () => _addProduct(context, ref),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('追加'),
                ),
              ],
            ),
            if (state.isLegacyFallback) ...<Widget>[
              const SizedBox(height: V2Spacing.xs),
              const Text(
                '以前のお気に入りを引き継いで表示しています。',
                key: Key('favoriteProductsLegacyNotice'),
              ),
            ],
            const SizedBox(height: V2Spacing.sm),
            if (state.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(V2Spacing.md),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (state.failure != null)
              _FavoriteFailure(
                onRetry: () {
                  ref
                      .read(favoriteProductsControllerProvider.notifier)
                      .refresh();
                },
              )
            else if (state.products.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: V2Spacing.sm),
                child: Text(
                  'よく飲む商品はまだありません。\n追加すると、地図の「探す」からすぐ検索できます。',
                  key: Key('favoriteProductsMyPageEmpty'),
                ),
              )
            else ...<Widget>[
              for (final product in state.products)
                _FavoriteProductTile(
                  product: product,
                  isMutating: state.isMutating,
                  onRemove: () => _removeProduct(context, ref, product),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _addProduct(BuildContext context, WidgetRef ref) async {
    final state = ref.read(favoriteProductsControllerProvider);

    final product = await V2FavoriteProductPicker.show(
      context,
      existingProductIds: <String>{
        for (final item in state.products) item.id.value,
      },
    );

    if (product == null || !context.mounted) {
      return;
    }

    final success = await ref
        .read(favoriteProductsControllerProvider.notifier)
        .add(product);

    if (!context.mounted || !success) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('「${product.name}」を追加しました')));
  }

  Future<void> _removeProduct(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('よく飲む商品から外しますか？'),
          content: Text('「${product.name}」を削除します。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              key: Key('favoriteProductRemoveConfirm_${product.id.value}'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('削除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final success = await ref
        .read(favoriteProductsControllerProvider.notifier)
        .remove(product);

    if (!context.mounted || !success) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('「${product.name}」を削除しました')));
  }
}

class _FavoriteProductTile extends StatelessWidget {
  const _FavoriteProductTile({
    required this.product,
    required this.isMutating,
    required this.onRemove,
  });

  final Product product;
  final bool isMutating;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('favoriteProductMyPage_${product.id.value}'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.favorite_rounded),
      title: Text(product.name),
      subtitle: product.genres.isEmpty
          ? null
          : Text(product.genres.take(2).map((genre) => genre.label).join('・')),
      trailing: IconButton(
        key: Key('favoriteProductRemove_${product.id.value}'),
        tooltip: '削除',
        onPressed: isMutating ? null : onRemove,
        icon: const Icon(Icons.delete_outline_rounded),
      ),
    );
  }
}

class _FavoriteFailure extends StatelessWidget {
  const _FavoriteFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: V2Spacing.sm),
      child: Column(
        children: <Widget>[
          const Text('よく飲む商品を読み込めませんでした'),
          const SizedBox(height: V2Spacing.xs),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('再試行'),
          ),
        ],
      ),
    );
  }
}
