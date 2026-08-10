import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/v2_spacing.dart';
import '../../product_master/domain/entities/product.dart';
import '../../product_search/application/providers/product_search_providers.dart';
import '../../product_search/domain/models/product_search_candidate.dart';
import '../../product_search/domain/value_objects/product_search_query.dart';

class V2FavoriteProductPicker extends ConsumerStatefulWidget {
  const V2FavoriteProductPicker({
    super.key,
    this.existingProductIds = const <String>{},
  });

  final Set<String> existingProductIds;

  static Future<Product?> show(
    BuildContext context, {
    Set<String> existingProductIds = const <String>{},
  }) {
    return showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) {
        return V2FavoriteProductPicker(existingProductIds: existingProductIds);
      },
    );
  }

  @override
  ConsumerState<V2FavoriteProductPicker> createState() =>
      _V2FavoriteProductPickerState();
}

class _V2FavoriteProductPickerState
    extends ConsumerState<V2FavoriteProductPicker> {
  static const _debounceDuration = Duration(milliseconds: 250);

  final _controller = TextEditingController();
  Timer? _debounce;
  List<ProductSearchCandidate> _candidates = const <ProductSearchCandidate>[];
  bool _isLoading = false;
  bool _hasSearched = false;
  bool _hasFailure = false;
  var _requestSerial = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          V2Spacing.md,
          V2Spacing.md,
          V2Spacing.md,
          MediaQuery.viewInsetsOf(context).bottom + V2Spacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'よく飲む商品を追加',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '閉じる',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: V2Spacing.sm),
            TextField(
              key: const Key('favoriteProductPickerSearchField'),
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: '商品名で検索',
              ),
              onChanged: _onChanged,
              onSubmitted: _search,
            ),
            const SizedBox(height: V2Spacing.sm),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasFailure) {
      return Center(
        child: TextButton.icon(
          onPressed: () => _search(_controller.text),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('商品候補を再読み込み'),
        ),
      );
    }

    if (!_hasSearched) {
      return const Center(
        child: Text('商品名を入力すると候補を表示します。', textAlign: TextAlign.center),
      );
    }

    if (_candidates.isEmpty) {
      return const Center(child: Text('該当する商品がありません'));
    }

    return ListView.separated(
      key: const Key('favoriteProductPickerResults'),
      itemCount: _candidates.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final product = _candidates[index].product;
        final alreadyAdded = widget.existingProductIds.contains(
          product.id.value,
        );

        return ListTile(
          key: Key('favoriteProductPicker_${product.id.value}'),
          leading: const Icon(Icons.local_drink_outlined),
          title: Text(product.name),
          subtitle: product.genres.isEmpty
              ? null
              : Text(
                  product.genres.take(2).map((genre) => genre.label).join('・'),
                ),
          trailing: alreadyAdded
              ? const Text('登録済み')
              : const Icon(Icons.add_rounded),
          enabled: !alreadyAdded,
          onTap: alreadyAdded ? null : () => Navigator.of(context).pop(product),
        );
      },
    );
  }

  void _onChanged(String value) {
    _debounce?.cancel();

    if (value.trim().isEmpty) {
      _requestSerial += 1;
      setState(() {
        _candidates = const <ProductSearchCandidate>[];
        _isLoading = false;
        _hasSearched = false;
        _hasFailure = false;
      });
      return;
    }

    _debounce = Timer(_debounceDuration, () {
      _search(value);
    });
  }

  Future<void> _search(String rawText) async {
    _debounce?.cancel();
    final query = ProductSearchQuery(rawText);
    final requestId = ++_requestSerial;

    if (query.isEmpty) {
      setState(() {
        _candidates = const <ProductSearchCandidate>[];
        _isLoading = false;
        _hasSearched = false;
        _hasFailure = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasFailure = false;
    });

    final result = await ref
        .read(productCandidateSearchServiceProvider)
        .search(query);

    if (!mounted || requestId != _requestSerial) {
      return;
    }

    final failure = result.failureOrNull;
    setState(() {
      _isLoading = false;
      _hasSearched = true;
      _hasFailure = failure != null;
      _candidates = failure == null
          ? (result.valueOrNull ?? const <ProductSearchCandidate>[])
                .take(12)
                .toList(growable: false)
          : const <ProductSearchCandidate>[];
    });
  }
}
