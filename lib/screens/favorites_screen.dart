import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/favorites_provider.dart';
import '../repositories/favorite_repository.dart';
import '../widgets/common/empty_state_view.dart';
import '../widgets/common/loading_view.dart';
import 'machine_detail_screen.dart';
import 'search_home_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        context.read<FavoritesProvider>().setSelectedTabIndex(_tabController.index);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) return;
    _initialized = true;

    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<FavoritesProvider>().loadFavorites(user.uid);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await context.read<FavoritesProvider>().loadFavorites(user.uid);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesProvider>(
      builder: (BuildContext context, FavoritesProvider favoritesProvider, _) {
        final User? user = FirebaseAuth.instance.currentUser;

        return Scaffold(
          appBar: AppBar(
            title: const Text('お気に入り'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: '商品'),
                Tab(text: '自販機'),
              ],
            ),
          ),
          body: user == null
              ? const EmptyStateView(
            title: 'ログインが必要です',
            description: 'お気に入り機能を使うにはログインしてください。',
            icon: Icons.favorite_border,
          )
              : favoritesProvider.isLoading &&
              favoritesProvider.productFavorites.isEmpty &&
              favoritesProvider.machineFavorites.isEmpty
              ? const LoadingView(message: 'お気に入りを読み込み中…')
              : RefreshIndicator(
            onRefresh: _refresh,
            child: TabBarView(
              controller: _tabController,
              children: [
                _FavoriteProductTab(
                  items: favoritesProvider.productFavorites,
                ),
                _FavoriteMachineTab(
                  items: favoritesProvider.machineFavorites,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FavoriteProductTab extends StatelessWidget {
  final List<FavoriteItem> items;

  const _FavoriteProductTab({
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyStateView(
        title: '商品のお気に入りはまだありません',
        description: '気になる商品をお気に入りすると、ここからすぐ探せます。',
        icon: Icons.local_drink_outlined,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final FavoriteItem item = items[index];

        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            leading: const CircleAvatar(
              child: Icon(Icons.local_drink_outlined),
            ),
            title: Text(item.targetNameSnapshot),
            subtitle: Text(item.notifyEnabled ? '通知オン' : '通知オフ'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SearchHomeScreen(
                    initialKeyword: item.targetNameSnapshot,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _FavoriteMachineTab extends StatelessWidget {
  final List<FavoriteItem> items;

  const _FavoriteMachineTab({
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyStateView(
        title: '自販機のお気に入りはまだありません',
        description: 'よく使う自販機をお気に入りすると、ここからすぐ開けます。',
        icon: Icons.pin_drop_outlined,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final FavoriteItem item = items[index];

        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            leading: const CircleAvatar(
              child: Icon(Icons.pin_drop_outlined),
            ),
            title: Text(item.targetNameSnapshot),
            subtitle: Text(item.notifyEnabled ? '通知オン' : '通知オフ'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MachineDetailScreen(machineId: item.targetId),
                ),
              );
            },
          ),
        );
      },
    );
  }
}