import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({
    super.key,
    required this.isLoggedIn,
  });

  final bool isLoggedIn;

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  bool _isSavingDistance = false;
  bool _isSavingFavoriteNotice = false;
  bool _isSavingMachineNotice = false;

  static const List<int> _distanceOptions = <int>[
    50,
    100,
    300,
    500,
  ];

  static const int _freeFavoriteLimit = 10;
  static const int _premiumDefaultFavoriteLimit = 100;

  Future<void> _saveDefaultDistance({
    required String uid,
    required int distanceMeters,
  }) async {
    final sanitized = _sanitizeDistance(distanceMeters);

    setState(() {
      _isSavingDistance = true;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        <String, dynamic>{
          'defaultDistanceMeters': sanitized,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('距離設定の保存に失敗しました: $e'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSavingDistance = false;
      });
    }
  }

  Future<void> _saveNotificationSetting({
    required String uid,
    required String key,
    required bool value,
    required void Function(bool saving) setSaving,
    required String errorLabel,
  }) async {
    setSaving(true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        <String, dynamic>{
          key: value,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$errorLabel の保存に失敗しました: $e'),
        ),
      );
    } finally {
      if (!mounted) return;
      setSaving(false);
    }
  }

  int _sanitizeDistance(int value) {
    if (_distanceOptions.contains(value)) return value;
    return 100;
  }

  int _resolveFavoriteLimit(Map<String, dynamic> data) {
    final explicit = _readNullableInt(data, 'favoriteDrinkLimit');
    if (explicit != null && explicit > 0) return explicit;

    final isPremium = data['isPremium'] == true;
    if (isPremium) return _premiumDefaultFavoriteLimit;

    return _freeFavoriteLimit;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoggedIn) {
      return const _LoggedOutMyPage();
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const _LoggedOutMyPage();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        return FutureBuilder<int>(
          future: _fetchRegisteredMachineCount(user.uid),
          builder: (context, machineSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting &&
                !userSnapshot.hasData &&
                machineSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final userData = userSnapshot.data?.data() ?? <String, dynamic>{};

            final displayName = _readString(
              userData,
              'displayName',
              fallback: user.displayName ?? 'ユーザー',
            );
            final checkinCount = _readInt(userData, 'checkinCount');
            final drinkRegisterCount = _readInt(userData, 'drinkRegisterCount');
            final machineRegisterCount =
                machineSnapshot.data ?? _readInt(userData, 'machineRegisterCount');

            final favoriteDrinkNoticeEnabled = _readBool(
              userData,
              'favoriteDrinkNoticeEnabled',
              fallback: true,
            );
            final machineUpdateNoticeEnabled = _readBool(
              userData,
              'machineUpdateNoticeEnabled',
              fallback: false,
            );

            final favoriteDrinkNames = _readStringList(
              userData['favoriteDrinkNames'],
            );
            final favoriteLimit = _resolveFavoriteLimit(userData);
            final isPremium = userData['isPremium'] == true;

            final defaultDistanceMeters = _sanitizeDistance(
              _readIntWithFallback(
                userData,
                'defaultDistanceMeters',
                fallback: 100,
              ),
            );

            final xpFromFirestore = _readNullableInt(userData, 'xp');
            final totalXp = xpFromFirestore ??
                (checkinCount * 10) +
                    (machineRegisterCount * 50) +
                    (drinkRegisterCount * 5);

            final level = _calcLevel(totalXp);
            final currentLevelBaseXp = (level - 1) * 100;
            final nextLevelXp = level * 100;
            final progress = ((totalXp - currentLevelBaseXp) /
                (nextLevelXp - currentLevelBaseXp))
                .clamp(0.0, 1.0);

            final currentTitle = _readString(
              userData,
              'currentTitle',
              fallback: _inferCurrentTitle(
                checkinCount: checkinCount,
                machineRegisterCount: machineRegisterCount,
                drinkRegisterCount: drinkRegisterCount,
                level: level,
              ),
            );

            final titleList = _buildTitleList(
              checkinCount: checkinCount,
              machineRegisterCount: machineRegisterCount,
              drinkRegisterCount: drinkRegisterCount,
              level: level,
            );

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileCard(
                    displayName: displayName,
                    currentTitle: currentTitle,
                    level: level,
                    totalXp: totalXp,
                    nextLevelXp: nextLevelXp,
                    progress: progress,
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'ステータス',
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            label: 'チェックイン',
                            value: '$checkinCount',
                            icon: Icons.check_circle_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatTile(
                            label: '自販機登録',
                            value: '$machineRegisterCount',
                            icon: Icons.add_business_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatTile(
                            label: 'ドリンク登録',
                            value: '$drinkRegisterCount',
                            icon: Icons.local_cafe_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '経験値内訳',
                    child: Column(
                      children: [
                        _XpRow(
                          label: 'チェックイン',
                          detail: '$checkinCount回 × 10XP',
                          xp: '+${checkinCount * 10}',
                        ),
                        const SizedBox(height: 8),
                        _XpRow(
                          label: '自販機登録',
                          detail: '$machineRegisterCount件 × 50XP',
                          xp: '+${machineRegisterCount * 50}',
                        ),
                        const SizedBox(height: 8),
                        _XpRow(
                          label: 'ドリンク登録',
                          detail: '$drinkRegisterCount件 × 5XP',
                          xp: '+${drinkRegisterCount * 5}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '現在の称号',
                    actionLabel: '一覧',
                    child: _CurrentTitleCard(
                      title: currentTitle,
                      description: '行動に応じて称号が増えていきます。',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '称号一覧',
                    child: Column(
                      children: [
                        for (var i = 0; i < titleList.length; i++) ...[
                          _TitleListTile(data: titleList[i]),
                          if (i != titleList.length - 1)
                            const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '検索設定',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'デフォルト距離',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'マップ画面で最初に使う距離フィルターです。',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF60707A),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              height: 44,
                              padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFE3E7EB),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: defaultDistanceMeters,
                                  items: _distanceOptions.map((meters) {
                                    return DropdownMenuItem<int>(
                                      value: meters,
                                      child: Text('${meters}m'),
                                    );
                                  }).toList(),
                                  onChanged: _isSavingDistance
                                      ? null
                                      : (value) async {
                                    if (value == null) return;
                                    await _saveDefaultDistance(
                                      uid: user.uid,
                                      distanceMeters: value,
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (_isSavingDistance)
                              const Text(
                                '保存中...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF60707A),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'お気に入り枠',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FavoriteLimitCard(
                          currentCount: favoriteDrinkNames.length,
                          limit: favoriteLimit,
                          isPremium: isPremium,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isPremium
                              ? 'プレミアム枠が有効です。'
                              : '無料枠は最大$favoriteLimit件です。将来プレミアムで上限拡張予定です。',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF60707A),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: '通知設定',
                    child: Column(
                      children: [
                        _EditableSettingRow(
                          icon: Icons.notifications_active_rounded,
                          title: 'お気に入りドリンク近く通知',
                          subtitle: favoriteDrinkNoticeEnabled
                              ? '近くで見つかった時に通知します'
                              : '現在はOFFです',
                          enabled: favoriteDrinkNoticeEnabled,
                          isSaving: _isSavingFavoriteNotice,
                          onChanged: (value) async {
                            await _saveNotificationSetting(
                              uid: user.uid,
                              key: 'favoriteDrinkNoticeEnabled',
                              value: value,
                              errorLabel: 'お気に入りドリンク通知設定',
                              setSaving: (saving) {
                                if (!mounted) return;
                                setState(() {
                                  _isSavingFavoriteNotice = saving;
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        _EditableSettingRow(
                          icon: Icons.update_rounded,
                          title: 'チェックイン自販機更新通知',
                          subtitle: machineUpdateNoticeEnabled
                              ? '登録した自販機の更新時に通知します'
                              : '現在はOFFです',
                          enabled: machineUpdateNoticeEnabled,
                          isSaving: _isSavingMachineNotice,
                          onChanged: (value) async {
                            await _saveNotificationSetting(
                              uid: user.uid,
                              key: 'machineUpdateNoticeEnabled',
                              value: value,
                              errorLabel: '自販機更新通知設定',
                              setSaving: (saving) {
                                if (!mounted) return;
                                setState(() {
                                  _isSavingMachineNotice = saving;
                                });
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _SectionCard(
                    title: 'その他',
                    child: Column(
                      children: [
                        _MenuRow(
                          icon: Icons.feedback_rounded,
                          title: 'フィードバック',
                          subtitle: '改善要望や気づいた点を送れるようにする予定',
                        ),
                        SizedBox(height: 8),
                        _MenuRow(
                          icon: Icons.workspace_premium_rounded,
                          title: 'プレミアム',
                          subtitle: 'お気に入り上限増加 / 広告非表示 / 編集期限延長',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Future<int> _fetchRegisteredMachineCount(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('vending_machines')
          .where('createdBy', isEqualTo: uid)
          .get();

      return snapshot.docs.length;
    } catch (_) {
      return 0;
    }
  }

  static int _calcLevel(int totalXp) {
    if (totalXp <= 0) return 1;
    return (totalXp ~/ 100) + 1;
  }

  static String _inferCurrentTitle({
    required int checkinCount,
    required int machineRegisterCount,
    required int drinkRegisterCount,
    required int level,
  }) {
    if (machineRegisterCount >= 10) return 'エリア探索者';
    if (drinkRegisterCount >= 30) return 'ドリンクメモ職人';
    if (checkinCount >= 10) return '街角ハンター';
    if (level >= 3) return 'ルーキーナビゲーター';
    if (machineRegisterCount >= 1) return 'はじめての一台';
    return 'これからの探索者';
  }

  static List<_TitleData> _buildTitleList({
    required int checkinCount,
    required int machineRegisterCount,
    required int drinkRegisterCount,
    required int level,
  }) {
    return <_TitleData>[
      _TitleData(
        name: 'はじめての一台',
        description: '最初の自販機を登録',
        unlocked: machineRegisterCount >= 1,
        icon: Icons.local_drink_rounded,
      ),
      _TitleData(
        name: '街角ハンター',
        description: 'チェックイン10回達成',
        unlocked: checkinCount >= 10,
        icon: Icons.place_rounded,
      ),
      _TitleData(
        name: 'ドリンクメモ職人',
        description: 'ドリンク登録30件達成',
        unlocked: drinkRegisterCount >= 30,
        icon: Icons.edit_note_rounded,
      ),
      _TitleData(
        name: 'ルーキーナビゲーター',
        description: 'レベル3到達',
        unlocked: level >= 3,
        icon: Icons.emoji_events_rounded,
      ),
      _TitleData(
        name: 'エリア探索者',
        description: '自販機登録10件達成',
        unlocked: machineRegisterCount >= 10,
        icon: Icons.map_rounded,
      ),
      const _TitleData(
        name: '県境ウォーカー',
        description: '別エリア登録対応時に解放予定',
        unlocked: false,
        icon: Icons.directions_walk_rounded,
      ),
    ];
  }

  static List<String> _readStringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return <String>[];
  }

  static String _readString(
      Map<String, dynamic> data,
      String key, {
        required String fallback,
      }) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  static int _readInt(Map<String, dynamic> data, String key) {
    final value = _readNullableInt(data, key);
    return value ?? 0;
  }

  static int _readIntWithFallback(
      Map<String, dynamic> data,
      String key, {
        required int fallback,
      }) {
    final value = _readNullableInt(data, key);
    return value ?? fallback;
  }

  static int? _readNullableInt(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool _readBool(
      Map<String, dynamic> data,
      String key, {
        required bool fallback,
      }) {
    final value = data[key];
    if (value is bool) return value;
    return fallback;
  }
}

class _LoggedOutMyPage extends StatelessWidget {
  const _LoggedOutMyPage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FBFC),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE3E7EB)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline_rounded, size: 42),
            SizedBox(height: 10),
            Text(
              'マイページ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'ログインすると、登録実績や称号の保存に対応しやすくなります。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF60707A),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.displayName,
    required this.currentTitle,
    required this.level,
    required this.totalXp,
    required this.nextLevelXp,
    required this.progress,
  });

  final String displayName;
  final String currentTitle;
  final int level;
  final int totalXp;
  final int nextLevelXp;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFEAF7FF),
            Color(0xFFF7FCFF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD7E9F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Icon(Icons.person_rounded, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentTitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF60707A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD7E9F4)),
                ),
                child: Text(
                  'Lv.$level',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 12,
              value: progress,
              backgroundColor: const Color(0xFFDDEAF2),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$totalXp XP / 次のレベル目安 $nextLevelXp XP',
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.actionLabel,
  });

  final String title;
  final Widget child;
  final String? actionLabel;

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
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (actionLabel != null)
                Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF60707A),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E7EB)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              height: 1.3,
              color: Color(0xFF60707A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _XpRow extends StatelessWidget {
  const _XpRow({
    required this.label,
    required this.detail,
    required this.xp,
  });

  final String label;
  final String detail;
  final String xp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF60707A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            xp,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentTitleCard extends StatelessWidget {
  const _CurrentTitleCard({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.emoji_events_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF60707A),
                    height: 1.4,
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

class _TitleListTile extends StatelessWidget {
  const _TitleListTile({
    required this.data,
  });

  final _TitleData data;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: data.unlocked ? 1 : 0.65,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: data.unlocked ? Colors.white : const Color(0xFFF4F6F8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE3E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: data.unlocked
                    ? const Color(0xFFEAF3FF)
                    : const Color(0xFFE7EAED),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(data.icon, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF60707A),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: data.unlocked
                    ? const Color(0xFFE8F7EA)
                    : const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                data.unlocked ? '獲得済み' : '未解放',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: data.unlocked
                      ? const Color(0xFF2F7A37)
                      : const Color(0xFF60707A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteLimitCard extends StatelessWidget {
  const _FavoriteLimitCard({
    required this.currentCount,
    required this.limit,
    required this.isPremium,
  });

  final int currentCount;
  final int limit;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final remaining = (limit - currentCount).clamp(0, limit);

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

class _EditableSettingRow extends StatelessWidget {
  const _EditableSettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.isSaving,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final bool isSaving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF60707A),
                    height: 1.4,
                  ),
                ),
                if (isSaving) ...[
                  const SizedBox(height: 6),
                  const Text(
                    '保存中...',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF60707A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: isSaving ? null : onChanged,
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF60707A),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _TitleData {
  const _TitleData({
    required this.name,
    required this.description,
    required this.unlocked,
    required this.icon,
  });

  final String name;
  final String description;
  final bool unlocked;
  final IconData icon;
}