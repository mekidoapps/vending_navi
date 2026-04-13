import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FavoriteDrinksScreen extends StatefulWidget {
  const FavoriteDrinksScreen({super.key});

  @override
  State<FavoriteDrinksScreen> createState() => _FavoriteDrinksScreenState();
}

class _FavoriteDrinksScreenState extends State<FavoriteDrinksScreen> {
  final TextEditingController _addController = TextEditingController();
  bool _isSaving = false;

  static const int _freeFavoriteLimit = 10;
  static const int _premiumDefaultFavoriteLimit = 100;

  static const List<String> _suggestions = <String>[
    '綾鷹',
    'お〜いお茶 緑茶',
    'お〜いお茶 濃い茶',
    '生茶',
    '伊右衛門',
    '爽健美茶',
    '午後の紅茶 ミルクティー',
    '午後の紅茶 ストレート',
    'クラフトボス ブラック',
    'クラフトボス ラテ',
    'ジョージア ブラック',
    'ジョージア カフェオレ',
    'ワンダ モーニングショット',
    'ワンダ 金の微糖',
    'FIRE ブラック',
    'FIRE 微糖',
    'コカ・コーラ',
    'ゼロシュガー',
    '三ツ矢サイダー',
    'ウィルキンソン タンサン',
    'アクエリアス',
    'ポカリスエット',
    'いろはす',
    '天然水',
    'リアルゴールド',
    'ドデカミン',
    'カルピスウォーター',
    'カルピスソーダ',
  ];

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _saveFavoriteDrinks({
    required String uid,
    required List<String> values,
  }) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        <String, dynamic>{
          'favoriteDrinkNames': values,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存に失敗しました: $e'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _addDrink({
    required String uid,
    required List<String> current,
    required int limit,
    required String rawValue,
  }) async {
    final value = rawValue.trim();
    if (value.isEmpty) return;

    final normalizedCurrent = current.map(_normalize).toSet();
    if (normalizedCurrent.contains(_normalize(value))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('すでにお気に入りに入っています。'),
        ),
      );
      return;
    }

    if (current.length >= limit) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('お気に入りは最大$limit件までです。'),
        ),
      );
      return;
    }

    final next = <String>[...current, value]..sort(_sortJaLike);
    await _saveFavoriteDrinks(uid: uid, values: next);

    if (!mounted) return;
    _addController.clear();
  }

  Future<void> _removeDrink({
    required String uid,
    required List<String> current,
    required String value,
  }) async {
    final next = current
        .where((e) => _normalize(e) != _normalize(value))
        .toList()
      ..sort(_sortJaLike);

    await _saveFavoriteDrinks(uid: uid, values: next);
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('　', '')
        .replaceAll(' ', '')
        .replaceAll('〜', 'ー')
        .replaceAll('～', 'ー')
        .replaceAll('-', 'ー');
  }

  static int _sortJaLike(String a, String b) {
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  int _resolveFavoriteLimit(Map<String, dynamic> data) {
    final explicit = _readNullableInt(data['favoriteDrinkLimit']);
    if (explicit != null && explicit > 0) return explicit;

    final isPremium = data['isPremium'] == true;
    if (isPremium) return _premiumDefaultFavoriteLimit;

    return _freeFavoriteLimit;
  }

  bool _isPremium(Map<String, dynamic> data) {
    return data['isPremium'] == true;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const _LoggedOutFavoriteView();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final favorites = _readStringList(data['favoriteDrinkNames'])
          ..sort(_sortJaLike);

        final limit = _resolveFavoriteLimit(data);
        final isPremium = _isPremium(data);
        final remaining = (limit - favorites.length).clamp(0, limit);
        final isAtLimit = favorites.length >= limit;

        final normalizedFavorites = favorites.map(_normalize).toSet();
        final visibleSuggestions = _suggestions
            .where((e) => !normalizedFavorites.contains(_normalize(e)))
            .toList();

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionCard(
                title: 'お気に入りドリンク',
                subtitle: '近くで見つけたい飲み物を登録しておきます',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LimitInfoCard(
                      currentCount: favorites.length,
                      limit: limit,
                      remaining: remaining,
                      isPremium: isPremium,
                    ),
                    if (isAtLimit) ...[
                      const SizedBox(height: 10),
                      _PremiumUpsellCard(
                        limit: limit,
                        isPremium: isPremium,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _addController,
                            enabled: !_isSaving && !isAtLimit,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (value) async {
                              await _addDrink(
                                uid: user.uid,
                                current: favorites,
                                limit: limit,
                                rawValue: value,
                              );
                            },
                            decoration: InputDecoration(
                              hintText: isAtLimit
                                  ? 'お気に入り上限に達しています'
                                  : '例: 綾鷹 / ワンダ モーニングショット',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _isSaving || isAtLimit
                              ? null
                              : () async {
                            await _addDrink(
                              uid: user.uid,
                              current: favorites,
                              limit: limit,
                              rawValue: _addController.text,
                            );
                          },
                          child: _isSaving
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Text('追加'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isPremium
                          ? 'プレミアム枠が有効です。'
                          : isAtLimit
                          ? '無料枠の上限に達しています。プレミアムでは上限拡張を予定しています。'
                          : '今は無料枠で登録できます。あとでプレミアムで上限拡張予定です。',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF60707A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: '登録中',
                subtitle: favorites.isEmpty ? 'まだ登録がありません' : '${favorites.length}件',
                child: favorites.isEmpty
                    ? const _EmptyPanel(
                  icon: Icons.favorite_border_rounded,
                  title: 'お気に入りはまだありません',
                  message: 'よく探したいドリンクを追加しておくと、あとで通知や検索強化につなげやすくなります。',
                )
                    : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: favorites.map((drink) {
                    return _FavoriteChip(
                      label: drink,
                      onDeleted: _isSaving
                          ? null
                          : () async {
                        await _removeDrink(
                          uid: user.uid,
                          current: favorites,
                          value: drink,
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: '候補から追加',
                subtitle: isAtLimit ? '上限に達しています' : 'よくありそうな飲み物',
                child: visibleSuggestions.isEmpty
                    ? const Text(
                  '追加候補はありません。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF60707A),
                  ),
                )
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isAtLimit) ...[
                      const Text(
                        'いまは追加できません。不要な項目を外すか、将来のプレミアム拡張を想定した状態です。',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF60707A),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: visibleSuggestions.map((drink) {
                        return ActionChip(
                          label: Text(drink),
                          onPressed: _isSaving || isAtLimit
                              ? null
                              : () async {
                            await _addDrink(
                              uid: user.uid,
                              current: favorites,
                              limit: limit,
                              rawValue: drink,
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E8),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFF0D8A8)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: Color(0xFF7A5A17),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'この一覧は今後、「近くにあるか通知」「お気に入りから検索」につなげる前提の土台です。プレミアムでは上限拡張を想定しています。',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Color(0xFF6B5420),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<String> _readStringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return <String>[];
  }

  int? _readNullableInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class _LoggedOutFavoriteView extends StatelessWidget {
  const _LoggedOutFavoriteView();

  @override
  Widget build(BuildContext context) {
    return const _EmptyPanel(
      icon: Icons.lock_outline_rounded,
      title: 'お気に入り',
      message: 'ログインすると、お気に入りドリンクを保存できます。',
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final Widget child;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF60707A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LimitInfoCard extends StatelessWidget {
  const _LimitInfoCard({
    required this.currentCount,
    required this.limit,
    required this.remaining,
    required this.isPremium,
  });

  final int currentCount;
  final int limit;
  final int remaining;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPremium ? const Color(0xFFF3F8FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPremium
              ? const Color(0xFFD7E6FF)
              : const Color(0xFFE3E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isPremium ? 'プレミアム枠' : '無料枠',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isPremium
                  ? const Color(0xFF355C9A)
                  : const Color(0xFF60707A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$currentCount / $limit 件',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '残り $remaining 件',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF60707A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumUpsellCard extends StatelessWidget {
  const _PremiumUpsellCard({
    required this.limit,
    required this.isPremium,
  });

  final int limit;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPremium ? const Color(0xFFF3F8FF) : const Color(0xFFFFF2D9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPremium
              ? const Color(0xFFD7E6FF)
              : const Color(0xFFFFD18B),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPremium
                ? Icons.workspace_premium_rounded
                : Icons.lock_outline_rounded,
            size: 20,
            color: isPremium
                ? const Color(0xFF355C9A)
                : const Color(0xFF8A5A00),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPremium ? 'プレミアム枠を利用中' : '無料枠の上限に達しました',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isPremium
                        ? const Color(0xFF355C9A)
                        : const Color(0xFF8A5A00),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPremium
                      ? 'お気に入り登録をさらに使いやすくする前提で動いています。'
                      : '現在の無料枠は最大$limit件です。将来のプレミアムではお気に入り上限増加を予定しています。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: isPremium
                        ? const Color(0xFF4C658A)
                        : const Color(0xFF6B5420),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteChip extends StatelessWidget {
  const _FavoriteChip({
    required this.label,
    required this.onDeleted,
  });

  final String label;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      deleteIcon: const Icon(Icons.close_rounded, size: 18),
      onDeleted: onDeleted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: Color(0xFFE3E7EB)),
      ),
      backgroundColor: Colors.white,
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE3E7EB)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF60707A),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}