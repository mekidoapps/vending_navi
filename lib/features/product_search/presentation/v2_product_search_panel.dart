import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/v2_color_tokens.dart';
import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_shadows.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../product_master/domain/entities/product.dart';
import '../../product_master/domain/entities/product_genre.dart';
import '../application/product_search_controller.dart';
import '../application/product_search_state.dart';

class V2ProductSearchPanel extends ConsumerStatefulWidget {
  const V2ProductSearchPanel({
    super.key,
    required this.onProductSelected,
    required this.onGenreSelected,
    required this.onClose,
  });

  final ValueChanged<Product> onProductSelected;
  final ValueChanged<ProductGenre> onGenreSelected;
  final VoidCallback onClose;

  @override
  ConsumerState<V2ProductSearchPanel> createState() =>
      _V2ProductSearchPanelState();
}

class _V2ProductSearchPanelState extends ConsumerState<V2ProductSearchPanel> {
  static const Duration _debounceDuration = Duration(milliseconds: 250);
  static const int _maxVisibleCandidates = 8;

  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);
    final state = ref.watch(productSearchControllerProvider);

    return Material(
      key: const Key('productSearchPanel'),
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceElevated.withValues(alpha: 0.98),
          borderRadius: V2Radius.popup,
          border: Border.all(color: colors.border),
          boxShadow: V2Shadows.mapFloating,
        ),
        child: Padding(
          padding: const EdgeInsets.all(V2Spacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _PanelHeader(onClose: _close),
              const SizedBox(height: V2Spacing.sm),
              TextField(
                key: const Key('productSearchField'),
                controller: _textController,
                focusNode: _focusNode,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '商品名を入力',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _textController.text.isEmpty
                      ? null
                      : IconButton(
                          key: const Key('clearProductSearchField'),
                          tooltip: '入力を消す',
                          onPressed: _clearInput,
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
                onChanged: _onChanged,
                onSubmitted: _searchImmediately,
              ),
              const SizedBox(height: V2Spacing.sm),
              _GenreSelector(onSelected: _selectGenre),
              const SizedBox(height: V2Spacing.sm),
              Text(
                '候補',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: V2Spacing.xs),
              Expanded(
                child: _CandidateBody(
                  state: state,
                  maxVisibleCandidates: _maxVisibleCandidates,
                  onRetry: () => _searchImmediately(_textController.text),
                  onSelected: _selectProduct,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();

    if (value.trim().isEmpty) {
      ref.read(productSearchControllerProvider.notifier).clear();
      return;
    }

    _debounce = Timer(_debounceDuration, () {
      if (!mounted) {
        return;
      }
      ref.read(productSearchControllerProvider.notifier).search(value);
    });
  }

  void _searchImmediately(String value) {
    _debounce?.cancel();
    ref.read(productSearchControllerProvider.notifier).search(value);
  }

  void _clearInput() {
    _debounce?.cancel();
    _textController.clear();
    ref.read(productSearchControllerProvider.notifier).clear();
    setState(() {});
    _focusNode.requestFocus();
  }

  void _selectProduct(Product product) {
    _debounce?.cancel();
    FocusScope.of(context).unfocus();
    widget.onProductSelected(product);
  }

  void _selectGenre(ProductGenre genre) {
    _debounce?.cancel();
    FocusScope.of(context).unfocus();
    ref.read(productSearchControllerProvider.notifier).clear();
    widget.onGenreSelected(genre);
  }

  void _close() {
    _debounce?.cancel();
    FocusScope.of(context).unfocus();
    ref.read(productSearchControllerProvider.notifier).clear();
    widget.onClose();
  }
}

class _GenreSelector extends StatelessWidget {
  const _GenreSelector({required this.onSelected});

  final ValueChanged<ProductGenre> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'ジャンルから探す',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: V2Spacing.xs),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ProductGenre.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: V2Spacing.xs),
            itemBuilder: (context, index) {
              final genre = ProductGenre.values[index];

              return ActionChip(
                key: Key('genreCandidate_${genre.id}'),
                avatar: const Icon(Icons.category_outlined, size: 16),
                label: Text(genre.label),
                onPressed: () => onSelected(genre),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return Row(
      children: <Widget>[
        Icon(Icons.local_drink_outlined, size: 20, color: colors.primaryStrong),
        const SizedBox(width: V2Spacing.xs),
        Expanded(
          child: Text(
            '商品を探す',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          key: const Key('closeProductSearchPanel'),
          tooltip: '検索を閉じる',
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

class _CandidateBody extends StatelessWidget {
  const _CandidateBody({
    required this.state,
    required this.maxVisibleCandidates,
    required this.onRetry,
    required this.onSelected,
  });

  final ProductSearchState state;
  final int maxVisibleCandidates;
  final VoidCallback onRetry;
  final ValueChanged<Product> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    if (state.query.isEmpty && !state.isLoading) {
      return _PanelMessage(
        icon: Icons.search_rounded,
        message: '飲みたい商品の名前を入力してください。',
      );
    }

    if (state.isLoading) {
      return const Center(
        child: SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }

    if (state.failure != null) {
      return SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: V2Spacing.xxs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.cloud_off_outlined, color: colors.textSecondary),
                const SizedBox(height: V2Spacing.xs),
                Text(
                  '商品候補を読み込めませんでした',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: V2Spacing.xs),
                TextButton(onPressed: onRetry, child: const Text('再試行')),
              ],
            ),
          ),
        ),
      );
    }

    if (state.isEmptyResult) {
      return const _PanelMessage(
        icon: Icons.search_off_rounded,
        message: '該当する商品が見つかりませんでした。',
      );
    }

    final candidates = state.candidates
        .take(maxVisibleCandidates)
        .toList(growable: false);

    if (candidates.isEmpty) {
      return const _PanelMessage(
        icon: Icons.search_rounded,
        message: '飲みたい商品の名前を入力してください。',
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: candidates.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final candidate = candidates[index];
        final product = candidate.product;

        return ListTile(
          key: Key('productCandidate_${product.id.value}'),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: V2Spacing.xs,
            vertical: V2Spacing.xxs,
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

class _PanelMessage extends StatelessWidget {
  const _PanelMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 64;

        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(compact ? V2Spacing.xxs : V2Spacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (!compact) ...<Widget>[
                  Icon(icon, color: colors.textSecondary),
                  const SizedBox(height: V2Spacing.xs),
                ],
                Text(
                  message,
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
