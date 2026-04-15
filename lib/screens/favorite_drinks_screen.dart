import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
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
        _limit = FavoriteDrinkService.freeLimit;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final service = FavoriteDrinkService.instance;
      final favorites = await service.getFavoriteDrinkNames();
      final limit = await service.getLimit();

      if (!mounted) return;
      setState(() {
        _favorites = favorites;
        _limit = limit;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _favorites = <String>[];
        _limit = FavoriteDrinkService.freeLimit;
        _isLoading = false;
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
      final result =
      await FavoriteDrinkService.instance.addFavorite(selected.name);

      if (!mounted) return;

      switch (result.reason) {
        case FavoriteDrinkMutationReason.added:
          setState(() {
            _favorites = result.favorites;
            _limit = result.limit ?? _limit;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('「${selected.name}」をお気に入りに追加しました。'),
            ),
          );
          break;

        case FavoriteDrinkMutationReason.alreadyExists:
          setState(() {
            _favorites = result.favorites;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('「${selected.name}」はすでに登録されています。'),
            ),
          );
          break;

        case FavoriteDrinkMutationReason.limitReached:
          setState(() {
            _favorites = result.favorites;
            _limit = result.limit ?? _limit;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('お気に入りは最大${result.limit ?? _limit}件までです。'),
            ),
          );
          break;

        case FavoriteDrinkMutationReason.notLoggedIn:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('お気に入り保存にはログインが必要です。'),
            ),
          );
          break;

        case FavoriteDrinkMutationReason.invalidName:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ドリンクを選んでください。'),
            ),
          );
          break;

        case FavoriteDrinkMutationReason.removed:
        case FavoriteDrinkMutationReason.notFound:
          break;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('追加に失敗しました: $e'),
        ),
      );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _removeFavorite(String drinkName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('お気に入りから削除'),
          content: Text('「$drinkName」をお気に入りから外しますか？'),
          actions: [
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

    try {
      final result =
      await FavoriteDrinkService.instance.removeFavorite(drinkName);

      if (!mounted) return;

      setState(() {
        _favorites = result.favorites;
      });

      if (result.reason == FavoriteDrinkMutationReason.removed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('お気に入りから削除しました。'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('削除に失敗しました: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!_isLoggedIn) {
      return const _FavoriteGuestView();
    }

    final remaining = (_limit - _favorites.length).clamp(0, _limit);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  'お気に入りに入れたドリンクをもとに、近くの自販機を見つけやすくします。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF60707A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
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
                    onPressed:
                    (_isSubmitting || _favorites.length >= _limit)
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
                    label: Text(
                      _isSubmitting ? '追加中…' : 'ドリンクを選んで追加',
                    ),
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
                children: [
                  const Text(
                    '登録済み',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF334148),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._favorites.map((drinkName) {
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
              children: const [
                Text(
                  '今後の拡張',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334148),
                  ),
                ),
                SizedBox(height: 10),
                _BulletRow(text: '近くにあるお気に入りドリンク通知'),
                _BulletRow(text: 'Product IDベース保存への移行'),
                _BulletRow(text: '検索精度の向上'),
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
      children: const [
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
        children: [
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
            'よく飲むドリンクを登録すると、近くにある自販機を見つけやすくなります。',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF60707A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFD18B),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.favorite_rounded,
            size: 18,
            color: Color(0xFFB56B00),
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
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: '削除',
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE3E7EB),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF60707A),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF334148),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(
              Icons.circle,
              size: 8,
              color: Color(0xFF60707A),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF60707A),
                fontWeight: FontWeight.w600,
              ),
            ),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE3E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              color: Color(0xFF60707A),
              fontWeight: FontWeight.w600,
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
        border: Border.all(
          color: const Color(0xFFE3E7EB),
        ),
        boxShadow: const [
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