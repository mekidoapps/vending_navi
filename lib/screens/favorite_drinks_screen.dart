import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/drink_catalog_service.dart';
import '../services/favorite_drink_service.dart';
import '../widgets/drink_picker_sheet.dart';

class FavoriteDrinksScreen extends StatefulWidget {
  const FavoriteDrinksScreen({super.key});

  @override
  State<FavoriteDrinksScreen> createState() => _FavoriteDrinksScreenState();
}

class _FavoriteDrinksScreenState extends State<FavoriteDrinksScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;

  int _limit = FavoriteDrinkService.freeLimit;
  List<String> _favorites = <String>[];
  List<DrinkCatalogItem> _catalogItems = <DrinkCatalogItem>[];

  String _query = '';
  String? _selectedManufacturer;

  bool get _isLoggedIn => FirebaseAuth.instance.currentUser != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_isLoggedIn) {
      if (!mounted) return;
      setState(() {
        _favorites = <String>[];
        _catalogItems = <DrinkCatalogItem>[];
        _limit = FavoriteDrinkService.freeLimit;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final FavoriteDrinkService favoriteService = FavoriteDrinkService.instance;
      final DrinkCatalogService catalogService = DrinkCatalogService.instance;

      final List<String> favorites =
      await favoriteService.getFavoriteDrinkNames();
      final int limit = await favoriteService.getLimit();
      final List<DrinkCatalogItem> catalogItems =
      await catalogService.getDrinkCatalogItems();

      if (!mounted) return;
      setState(() {
        _favorites = favorites;
        _limit = limit;
        _catalogItems = catalogItems;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _favorites = <String>[];
        _catalogItems = DrinkCatalogService.fallbackItems;
        _limit = FavoriteDrinkService.freeLimit;
        _isLoading = false;
      });
    }
  }

  String _normalize(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll('　', '')
        .replaceAll(' ', '')
        .replaceAll('〜', 'ー')
        .replaceAll('～', 'ー')
        .replaceAll('-', 'ー');
  }

  bool _isFavorite(String drinkName) {
    final String target = _normalize(drinkName);
    return _favorites.any((String e) => _normalize(e) == target);
  }

  List<String> get _manufacturerOptions {
    final Set<String> result = <String>{};

    for (final DrinkCatalogItem item in _catalogItems) {
      final String manufacturer = item.manufacturer.trim();
      if (manufacturer.isNotEmpty) {
        result.add(manufacturer);
      }
    }

    final List<String> sorted = result.toList()..sort();
    return sorted;
  }

  List<DrinkCatalogItem> get _filteredCatalogItems {
    final String key = _normalize(_query);
    final String? manufacturer = _selectedManufacturer;

    final List<DrinkCatalogItem> filtered = _catalogItems.where((item) {
      if (manufacturer != null && item.manufacturer != manufacturer) {
        return false;
      }

      if (key.isEmpty) {
        return true;
      }

      if (_normalize(item.name).contains(key)) {
        return true;
      }

      if (_normalize(item.manufacturer).contains(key)) {
        return true;
      }

      for (final String tag in item.tags) {
        if (_normalize(tag).contains(key)) {
          return true;
        }
      }

      return false;
    }).toList();

    filtered.sort((a, b) {
      final int favoriteCompare =
      (_isFavorite(b.name) ? 1 : 0).compareTo(_isFavorite(a.name) ? 1 : 0);
      if (favoriteCompare != 0) return favoriteCompare;

      final int manufacturerCompare = a.manufacturer.compareTo(b.manufacturer);
      if (manufacturerCompare != 0) return manufacturerCompare;

      return a.name.compareTo(b.name);
    });

    return filtered;
  }

  Future<void> _toggleFavorite(DrinkCatalogItem item) async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final bool alreadyFavorite = _isFavorite(item.name);
      final FavoriteDrinkMutationResult result = alreadyFavorite
          ? await FavoriteDrinkService.instance.removeFavorite(item.name)
          : await FavoriteDrinkService.instance.addFavorite(item.name);

      if (!mounted) return;

      setState(() {
        _favorites = result.favorites;
        _limit = result.limit ?? _limit;
      });

      switch (result.reason) {
        case FavoriteDrinkMutationReason.added:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('「${item.name}」をお気に入りに追加しました。')),
          );
          break;
        case FavoriteDrinkMutationReason.removed:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('「${item.name}」をお気に入りから削除しました。')),
          );
          break;
        case FavoriteDrinkMutationReason.alreadyExists:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('すでに登録されています。')),
          );
          break;
        case FavoriteDrinkMutationReason.limitReached:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('お気に入りは最大${result.limit ?? _limit}件までです。')),
          );
          break;
        case FavoriteDrinkMutationReason.notLoggedIn:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('お気に入り保存にはログインが必要です。')),
          );
          break;
        case FavoriteDrinkMutationReason.invalidName:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ドリンク名を選択してください。')),
          );
          break;
        case FavoriteDrinkMutationReason.notFound:
          break;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _pickAndAddFavorite() async {
    if (_isSubmitting) return;
    if (!_isLoggedIn) return;

    final Product? selected = await DrinkPickerSheet.show(
      context,
      title: 'お気に入りに追加',
    );

    if (selected == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final FavoriteDrinkMutationResult result =
      await FavoriteDrinkService.instance.addFavorite(selected.name);

      if (!mounted) return;

      setState(() {
        _favorites = result.favorites;
        _limit = result.limit ?? _limit;
      });

      switch (result.reason) {
        case FavoriteDrinkMutationReason.added:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('「${selected.name}」をお気に入りに追加しました。')),
          );
          break;
        case FavoriteDrinkMutationReason.alreadyExists:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('「${selected.name}」はすでに登録されています。')),
          );
          break;
        case FavoriteDrinkMutationReason.limitReached:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('お気に入りは最大${result.limit ?? _limit}件までです。')),
          );
          break;
        case FavoriteDrinkMutationReason.notLoggedIn:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('お気に入り保存にはログインが必要です。')),
          );
          break;
        case FavoriteDrinkMutationReason.invalidName:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ドリンクを選んでください。')),
          );
          break;
        case FavoriteDrinkMutationReason.removed:
        case FavoriteDrinkMutationReason.notFound:
          break;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _removeFavorite(String drinkName) async {
    if (_isSubmitting) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('お気に入りから削除'),
          content: Text('「$drinkName」をお気に入りから外しますか？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('削除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final FavoriteDrinkMutationResult result =
      await FavoriteDrinkService.instance.removeFavorite(drinkName);

      if (!mounted) return;
      setState(() {
        _favorites = result.favorites;
        _limit = result.limit ?? _limit;
      });

      if (result.reason == FavoriteDrinkMutationReason.removed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('お気に入りから削除しました。')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除に失敗しました: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isLoggedIn) {
      return const _FavoriteGuestView();
    }

    final int remaining = (_limit - _favorites.length).clamp(0, _limit);
    final List<DrinkCatalogItem> items = _filteredCatalogItems;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'お気に入りドリンク',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334148),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'ドリンク一覧から選ぶと、近くの自販機を見つけやすくなります。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF60707A),
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    _CountBadge(
                      label: '登録数',
                      value: '${_favorites.length}/$_limit',
                    ),
                    const SizedBox(width: 8),
                    _CountBadge(
                      label: '残り',
                      value: '$remaining件',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (_isSubmitting || _favorites.length >= _limit)
                        ? null
                        : _pickAndAddFavorite,
                    icon: _isSubmitting
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.add_rounded),
                    label: Text(_isSubmitting ? '追加中…' : 'ドリンクを選んで追加'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _favorites.length >= _limit
                      ? '上限に達しています。プレミアムで上限を増やせる予定です。'
                      : 'メーカーやドリンク名から選んで追加できます。',
                  style: TextStyle(
                    fontSize: 12,
                    color: _favorites.length >= _limit
                        ? const Color(0xFF8A5A00)
                        : const Color(0xFF60707A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_favorites.isEmpty)
            const _EmptyFavoriteCard()
          else
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '登録済み',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF334148),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._favorites.map((String drinkName) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _FavoriteRow(
                        drinkName: drinkName,
                        onDelete: () => _removeFavorite(drinkName),
                      ),
                    );
                  }),
                ],
              ),
            ),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'ドリンク一覧から追加',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334148),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (String value) {
                    setState(() {
                      _query = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: '例：綾鷹 / BOSS / お〜いお茶',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: const Color(0xFFF7FBFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE3E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE3E7EB)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (_manufacturerOptions.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: const Text('すべて'),
                            selected: _selectedManufacturer == null,
                            onSelected: (_) {
                              setState(() {
                                _selectedManufacturer = null;
                              });
                            },
                          ),
                        ),
                        ..._manufacturerOptions.map((String manufacturer) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(manufacturer),
                              selected: _selectedManufacturer == manufacturer,
                              onSelected: (_) {
                                setState(() {
                                  _selectedManufacturer =
                                  _selectedManufacturer == manufacturer
                                      ? null
                                      : manufacturer;
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const _NoCatalogItemCard()
                else
                  ...items.map((DrinkCatalogItem item) {
                    final bool favorite = _isFavorite(item.name);
                    final bool limitReached =
                        !favorite && _favorites.length >= _limit;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CatalogDrinkRow(
                        item: item,
                        isFavorite: favorite,
                        isDisabled: _isSubmitting || limitReached,
                        onTap: () => _toggleFavorite(item),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteGuestView extends StatelessWidget {
  const _FavoriteGuestView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: const <Widget>[
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'お気に入りドリンク',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334148),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'お気に入りを登録すると、近くにある自販機を探しやすくなります。',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF60707A),
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 14),
              _GuestInfoCard(
                title: 'ログインすると使えます',
                subtitle: '登録・保存・通知はログイン後に使えるようになります。',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyFavoriteCard extends StatelessWidget {
  const _EmptyFavoriteCard();

  @override
  Widget build(BuildContext context) {
    return const _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'まだ登録されていません',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334148),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '下のドリンク一覧から、よく探すドリンクを選んでください。',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF60707A),
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoCatalogItemCard extends StatelessWidget {
  const _NoCatalogItemCard();

  @override
  Widget build(BuildContext context) {
    return const _GuestInfoCard(
      title: '該当するドリンクがありません',
      subtitle: '検索条件を変えるか、自販機のドリンク登録後にもう一度確認してください。',
    );
  }
}

class _CatalogDrinkRow extends StatelessWidget {
  const _CatalogDrinkRow({
    required this.item,
    required this.isFavorite,
    required this.isDisabled,
    required this.onTap,
  });

  final DrinkCatalogItem item;
  final bool isFavorite;
  final bool isDisabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accentColor = isFavorite
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFF60707A);

    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isFavorite ? const Color(0xFFEAF6FF) : const Color(0xFFF7FBFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFavorite ? const Color(0xFFB6DBF6) : const Color(0xFFE3E7EB),
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: accentColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF334148),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.manufacturer.isEmpty ? 'メーカー不明' : item.manufacturer,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF60707A),
                    ),
                  ),
                  if (item.tags.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: item.tags.take(3).map((String tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFE3E7EB)),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF60707A),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isFavorite ? '登録済み' : '追加',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDisabled && !isFavorite
                    ? const Color(0xFFB0B8BE)
                    : accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteRow extends StatelessWidget {
  const _FavoriteRow({
    required this.drinkName,
    required this.onDelete,
  });

  final String drinkName;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E7EB)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.favorite_rounded,
            size: 18,
            color: Color(0xFFE57373),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              drinkName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334148),
              ),
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.close_rounded),
            tooltip: '削除',
          ),
        ],
      ),
    );
  }
}

class _GuestInfoCard extends StatelessWidget {
  const _GuestInfoCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334148),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF60707A),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE3E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF60707A),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFF334148),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3E7EB)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}
