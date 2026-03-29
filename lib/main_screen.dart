import 'package:flutter/material.dart';

import 'favorites_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'search_home_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // IndexedStack で各タブの状態を保持する
  final List<Widget> _screens = const [
    MapScreen(),
    SearchHomeScreen(),
    FavoritesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'マップ',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: '検索',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'お気に入り',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'マイページ',
          ),
        ],
      ),
      // MapScreenのScaffold内に追加（開発用）
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'dev_seed',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DevSeedScreen()),
          );
        },
        child: const Icon(Icons.developer_mode),
      ),
    );
  }
}
