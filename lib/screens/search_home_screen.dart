import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/enums/app_enums.dart';
import '../providers/search_provider.dart';
import '../widgets/common/empty_state_view.dart';
import '../widgets/common/loading_view.dart';
import '../widgets/search/reliability_badge.dart';
import 'machine_detail_screen.dart';

class SearchHomeScreen extends StatefulWidget {
  final String? initialKeyword;

  const SearchHomeScreen({
    super.key,
    this.initialKeyword,
  });

  @override
  State<SearchHomeScreen> createState() => _SearchHomeScreenState();
}

class _SearchHomeScreenState extends State<SearchHomeScreen> {
  late final TextEditingController _searchController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialKeyword ?? '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) return;
    _initialized = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final SearchProvider provider = context.read<SearchProvider>();
      if ((widget.initialKeyword ?? '').trim().isNotEmpty) {
        provider.setKeyword(widget.initialKeyword!.trim());
        await provider.search();
      } else {
        await provider.fetchCurrentLocation();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final SearchProvider provider = context.read<SearchProvider>();
    provider.setKeyword(_searchController.text.trim());
    await provider.search();
  }

  void _openFilterSheet(SearchProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        ProductCategory? tempCategory = provider.category;
        ItemTemperature? tempTemperature = provider.temperatureFilter;
        bool tempOnlyFresh = provider.onlyFreshInfo;
        SearchSortType tempSort = provider.sortType;

        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '絞り込み',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<ProductCategory?>(
                      initialValue: tempCategory,
                      decoration: const InputDecoration(
                        labelText: 'カテゴリ',
                      ),
                      items: <DropdownMenuItem<ProductCategory?>>[
                        const DropdownMenuItem<ProductCategory?>(
                          value: null,
                          child: Text('指定なし'),
                        ),
                        ...ProductCategory.values.map(
                              (ProductCategory category) => DropdownMenuItem<ProductCategory?>(
                            value: category,
                            child: Text(_categoryLabel(category)),
                          ),
                        ),
                      ],
                      onChanged: (ProductCategory? value) {
                        setModalState(() {
                          tempCategory = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<ItemTemperature?>(
                      initialValue: tempTemperature,
                      decoration: const InputDecoration(
                        labelText: '温度',
                      ),
                      items: const [
                        DropdownMenuItem<ItemTemperature?>(
                          value: null,
                          child: Text('指定なし'),
                        ),
                        DropdownMenuItem<ItemTemperature?>(
                          value: ItemTemperature.cold,
                          child: Text('つめたい'),
                        ),
                        DropdownMenuItem<ItemTemperature?>(
                          value: ItemTemperature.hot,
                          child: Text('あたたかい'),
                        ),
                      ],
                      onChanged: (ItemTemperature? value) {
                        setModalState(() {
                          tempTemperature = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<SearchSortType>(
                      initialValue: tempSort,
                      decoration: const InputDecoration(
                        labelText: '並び順',
                      ),
                      items: SearchSortType.values.map(
                            (SearchSortType sortType) {
                          return DropdownMenuItem<SearchSortType>(
                            value: sortType,
                            child: Text(_sortLabel(sortType)),
                          );
                        },
                      ).toList(),
                      onChanged: (SearchSortType? value) {
                        if (value == null) return;
                        setModalState(() {
                          tempSort = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: tempOnlyFresh,
                      title: const Text('新しい情報を優先'),
                      onChanged: (bool value) {
                        setModalState(() {
                          tempOnlyFresh = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          provider.setCategory(tempCategory);
                          provider.setTemperatureFilter(tempTemperature);
                          provider.setSortType(tempSort);
                          provider.setOnlyFreshInfo(tempOnlyFresh);
                          Navigator.of(context).pop();
                          await provider.search();
                        },
                        child: const Text('適用する'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _categoryLabel(ProductCategory category) {
    switch (category) {
      case ProductCategory.tea:
        return 'お茶';
      case ProductCategory.water:
        return '水';
      case ProductCategory.coffee:
        return 'コーヒー';
      case ProductCategory.blackTea:
        return '紅茶';
      case ProductCategory.soda:
        return '炭酸';
      case ProductCategory.juice:
        return 'ジュース';
      case ProductCategory.sportsDrink:
        return 'スポーツドリンク';
      case ProductCategory.energyDrink:
        return 'エナジードリンク';
      case ProductCategory.milkBeverage:
        return '乳性飲料';
      case ProductCategory.soup:
        return 'スープ';
      case ProductCategory.other:
        return 'その他';
    }
  }

  String _sortLabel(SearchSortType value) {
    switch (value) {
      case SearchSortType.nearest:
        return '近い順';
      case SearchSortType.latest:
        return '新しい順';
      case SearchSortType.cheapest:
        return '安い順';
      case SearchSortType.bestMatch:
        return '一致度順';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SearchProvider>(
      builder: (BuildContext context, SearchProvider provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('さがす'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: '綾鷹・BOSS・お茶 など',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              provider.setKeyword('');
                              provider.clearResults();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _runSearch(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: '絞り込み',
                      onPressed: () => _openFilterSheet(provider),
                      icon: const Icon(Icons.tune),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _QuickChip(
                            label: 'お茶',
                            onTap: () {
                              _searchController.text = 'お茶';
                              _runSearch();
                            },
                          ),
                          _QuickChip(
                            label: 'コーヒー',
                            onTap: () {
                              _searchController.text = 'コーヒー';
                              _runSearch();
                            },
                          ),
                          _QuickChip(
                            label: '炭酸',
                            onTap: () {
                              _searchController.text = '炭酸';
                              _runSearch();
                            },
                          ),
                          _QuickChip(
                            label: 'つめたい',
                            onTap: () async {
                              provider.setTemperatureFilter(ItemTemperature.cold);
                              await _runSearch();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: provider.isLoading
                    ? const LoadingView(message: '検索中…')
                    : provider.results.isEmpty
                    ? const EmptyStateView(
                  title: 'まだ結果がありません',
                  description: '飲みたい商品名やカテゴリで検索してみましょう。',
                  icon: Icons.search,
                )
                    : RefreshIndicator(
                  onRefresh: _runSearch,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: provider.results.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final item = provider.results[index];

                      return Card(
                        child: ListTile(
                          contentPadding:
                          const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          title: Text(item.productName),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item.brandName} ・ ${item.priceLabel}'),
                                const SizedBox(height: 4),
                                Text(item.machineName),
                                if ((item.placeNote ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(item.placeNote!),
                                ],
                                if (item.distanceLabel.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(item.distanceLabel),
                                ],
                                const SizedBox(height: 8),
                                ReliabilityBadge(
                                  confidence: item.confidence,
                                  compact: true,
                                ),
                              ],
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => MachineDetailScreen(
                                  machineId: item.machineId,
                                  highlightProductId: item.productId,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
    );
  }
}