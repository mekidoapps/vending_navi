import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/enums/app_enums.dart';
import '../providers/favorites_provider.dart';
import '../providers/machine_provider.dart';
import '../widgets/common/empty_state_view.dart';
import '../widgets/common/loading_view.dart';
import '../widgets/common/tag_chip_list.dart';
import '../widgets/search/reliability_badge.dart';
import 'add_drink_screen.dart';
import 'checkin_screen.dart';

class MachineDetailScreen extends StatefulWidget {
  final String machineId;
  final String? highlightProductId;

  const MachineDetailScreen({
    super.key,
    required this.machineId,
    this.highlightProductId,
  });

  @override
  State<MachineDetailScreen> createState() => _MachineDetailScreenState();
}

class _MachineDetailScreenState extends State<MachineDetailScreen> {
  bool _initialized = false;
  bool _isFavorite = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) return;
    _initialized = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<MachineProvider>().loadMachineDetail(
        machineId: widget.machineId,
        highlightProductId: widget.highlightProductId,
      );
      await _loadFavoriteState();
    });
  }

  Future<void> _loadFavoriteState() async {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final bool value = await context.read<FavoritesProvider>().isFavorite(
        userId: userId,
        targetType: 'machine',
        targetId: widget.machineId,
      );

      if (!mounted) return;
      setState(() {
        _isFavorite = value;
      });
    } catch (_) {
      // お気に入り状態の取得失敗は無視（デフォルトfalseのまま）
    }
  }

  Future<void> _toggleFavorite(MachineProvider machineProvider) async {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || machineProvider.machine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    final FavoritesProvider favProvider = context.read<FavoritesProvider>();
    final String errorBefore = favProvider.errorMessage ?? '';

    final bool result = await favProvider.toggleFavorite(
      userId: userId,
      targetType: 'machine',
      targetId: widget.machineId,
      targetNameSnapshot: machineProvider.machine!.name,
    );

    if (!mounted) return;

    // エラーが発生した場合
    if (favProvider.errorMessage != null &&
        favProvider.errorMessage != errorBefore) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('操作に失敗しました。もう一度お試しください')),
      );
      return;
    }

    setState(() {
      _isFavorite = result;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result ? 'お気に入りに追加しました' : 'お気に入りを解除しました'),
      ),
    );
  }

  String _temperatureLabel(ItemTemperature value) {
    switch (value) {
      case ItemTemperature.cold:
        return 'つめたい';
      case ItemTemperature.hot:
        return 'あたたかい';
      case ItemTemperature.both:
        return '冷/温';
      case ItemTemperature.unknown:
        return '温度不明';
    }
  }

  String _stockLabel(StockStatus value) {
    switch (value) {
      case StockStatus.seenRecently:
        return '最近確認';
      case StockStatus.maybeAvailable:
        return 'ありそう';
      case StockStatus.soldOutReported:
        return '売り切れ報告';
      case StockStatus.unknown:
        return '情報不明';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MachineProvider>(
      builder: (BuildContext context, MachineProvider machineProvider, _) {
        final machine = machineProvider.machine;

        return Scaffold(
          appBar: AppBar(
            title: const Text('自販機詳細'),
            actions: [
              IconButton(
                onPressed: machine == null ? null : () => _toggleFavorite(machineProvider),
                icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
              ),
            ],
          ),
          floatingActionButton: machine == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<bool>(
                        builder: (_) => AddDrinkScreen(
                          machineId: machine.id,
                          machineName: machine.name,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('ドリンクを追加'),
                ),
          body: machineProvider.isLoading && machine == null
              ? const LoadingView(message: '自販機情報を読み込み中…')
              : machine == null
              ? const EmptyStateView(
            title: '自販機情報が見つかりません',
            description: '削除されたか、まだ読み込めていない可能性があります。',
            icon: Icons.local_drink_outlined,
          )
              : RefreshIndicator(
            onRefresh: machineProvider.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          machine.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if ((machine.placeNote ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(machine.placeNote!),
                        ],
                        const SizedBox(height: 12),
                        TagChipList(
                          tags: [
                            ...machine.paymentMethods,
                            ...machine.machineTags,
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CheckinScreen(
                                machineId: machine.id,
                                machineName: machine.name,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_location_alt_outlined),
                        label: const Text('チェックイン'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  '売っている商品',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (machineProvider.items.isEmpty)
                  const EmptyStateView(
                    title: '商品情報がまだありません',
                    description: 'チェックインや登録が増えるとここに表示されます。',
                    icon: Icons.local_drink_outlined,
                  )
                else
                  ...machineProvider.items.map((item) {
                    final bool isHighlighted =
                        widget.highlightProductId != null &&
                            widget.highlightProductId == item.productId;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        color: isHighlighted
                            ? Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.35)
                            : null,
                        child: ListTile(
                          contentPadding:
                          const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          title: Text(item.productNameSnapshot),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item.priceLabel} ・ ${_temperatureLabel(item.temperature)}'),
                                const SizedBox(height: 4),
                                Text(_stockLabel(item.stockStatus)),
                                const SizedBox(height: 8),
                                ReliabilityBadge(
                                  confidence: item.confidence,
                                  compact: true,
                                ),
                              ],
                            ),
                          ),
                          trailing: isHighlighted
                              ? const Icon(Icons.star)
                              : const Icon(Icons.chevron_right),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}