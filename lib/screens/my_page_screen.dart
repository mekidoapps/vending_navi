import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/user_progress_service.dart';
import 'auth_gate.dart';
import 'notification_settings_screen.dart';
import 'onboarding_screen.dart';

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
  bool _isLoading = true;
  bool _isSavingDistance = false;
  bool _isSavingDisplayName = false;

  UserProgressSnapshot? _progress;
  String _displayName = 'ユーザー';
  String _email = '';
  int _defaultDistanceMeters = 100;
  bool _isPremium = false;

  static const List<int> _distanceOptions = <int>[50, 100, 300, 500];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MyPageScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoggedIn != widget.isLoggedIn) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!widget.isLoggedIn || FirebaseAuth.instance.currentUser == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _progress = null;
        _displayName = 'ユーザー';
        _email = '';
        _defaultDistanceMeters = 100;
        _isPremium = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() ?? <String, dynamic>{};

      final progress = await UserProgressService.instance.getProgress(
        uid: user.uid,
      );

      if (!mounted) return;
      setState(() {
        _progress = progress;
        _displayName = _readDisplayName(userData, user);
        _email = (user.email ?? '').trim();
        _defaultDistanceMeters = _sanitizeDistance(
          _readNullableInt(userData['defaultDistanceMeters']) ?? 100,
        );
        _isPremium = userData['isPremium'] == true;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      setState(() {
        _progress = const UserProgressSnapshot(
          exp: 0,
          level: 1,
          currentTitle: 'はじめの一歩',
          titles: <String>[],
          registeredMachineCount: 0,
          registeredDrinkCount: 0,
          checkinCount: 0,
        );
        _displayName = user == null ? 'ユーザー' : _fallbackDisplayName(user);
        _email = user?.email?.trim() ?? '';
        _defaultDistanceMeters = 100;
        _isPremium = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveDefaultDistance(int meters) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final sanitized = _sanitizeDistance(meters);

    setState(() {
      _isSavingDistance = true;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        <String, dynamic>{
          'defaultDistanceMeters': sanitized,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      setState(() {
        _defaultDistanceMeters = sanitized;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('距離デフォルト設定を保存しました。'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存に失敗しました: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingDistance = false;
        });
      }
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const NotificationSettingsScreen(),
      ),
    );
  }

  Future<void> _openLoginRequired() async {
    await LoginRequiredSheet.show(context);
  }

  Future<void> _openOnboardingAgain() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const OnboardingScreen(),
      ),
    );
  }

  Future<void> _editDisplayName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isSavingDisplayName) return;

    final controller = TextEditingController(text: _displayName);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('表示名を変更'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 24,
            decoration: const InputDecoration(
              hintText: '表示名を入力',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (result == null) return;

    final trimmed = result.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('表示名を入力してください。'),
        ),
      );
      return;
    }

    setState(() {
      _isSavingDisplayName = true;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        <String, dynamic>{
          'displayName': trimmed,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await user.updateDisplayName(trimmed);

      if (!mounted) return;
      setState(() {
        _displayName = trimmed;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('表示名を更新しました。'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('表示名の更新に失敗しました: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingDisplayName = false;
        });
      }
    }
  }

  void _showFeedbackInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('フィードバック導線は次の段階で接続します。'),
      ),
    );
  }

  void _showContactInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('お問い合わせ導線は次の段階で接続します。'),
      ),
    );
  }

  void _showPremiumInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('プレミアム導線は今後追加予定です。'),
      ),
    );
  }

  Future<void> _openSafetyGuide() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const _SafetyGuideScreen(),
      ),
    );
  }

  int _sanitizeDistance(int value) {
    if (_distanceOptions.contains(value)) return value;
    return 100;
  }

  int? _readNullableInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  String _readDisplayName(Map<String, dynamic> userData, User user) {
    final stored = (userData['displayName'] ?? '').toString().trim();
    if (stored.isNotEmpty) return stored;

    final authName = (user.displayName ?? '').trim();
    if (authName.isNotEmpty) return authName;

    return _fallbackDisplayName(user);
  }

  String _fallbackDisplayName(User user) {
    final email = (user.email ?? '').trim();
    if (email.isNotEmpty && email.contains('@')) {
      return email.split('@').first;
    }
    if (email.isNotEmpty) return email;
    return 'ユーザー';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!widget.isLoggedIn || FirebaseAuth.instance.currentUser == null) {
      return _GuestMyPage(
        onLogin: _openLoginRequired,
      );
    }

    final progress = _progress ??
        const UserProgressSnapshot(
          exp: 0,
          level: 1,
          currentTitle: 'はじめの一歩',
          titles: <String>[],
          registeredMachineCount: 0,
          registeredDrinkCount: 0,
          checkinCount: 0,
        );

    final progressRate =
    UserProgressService.instance.levelProgressRate(progress.exp);
    final expToNext =
    UserProgressService.instance.expToNextLevel(progress.exp);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _SectionCard(
            title: 'プロフィール',
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF6FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 28,
                        color: Color(0xFF3E7BFA),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF334148),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _email.isEmpty ? 'メール未設定' : _email,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF60707A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            progress.currentTitle,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF60707A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isPremium) const _PremiumBadge(),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSavingDisplayName ? null : _editDisplayName,
                    icon: _isSavingDisplayName
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.edit_rounded),
                    label: Text(_isSavingDisplayName ? '保存中…' : '表示名を変更'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'ステータス',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _CountBadge(
                      label: 'レベル',
                      value: 'Lv ${progress.level}',
                    ),
                    const SizedBox(width: 8),
                    _CountBadge(
                      label: '経験値',
                      value: '${progress.exp}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progressRate,
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '次のレベルまであと $expToNext EXP',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF60707A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _StatusTile(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'チェックイン',
                        value: '${progress.checkinCount}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatusTile(
                        icon: Icons.add_business_rounded,
                        label: '登録自販機',
                        value: '${progress.registeredMachineCount}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatusTile(
                        icon: Icons.local_drink_rounded,
                        label: '登録ドリンク',
                        value: '${progress.registeredDrinkCount}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  '称号',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334148),
                  ),
                ),
                const SizedBox(height: 8),
                if (progress.titles.isEmpty)
                  const Text(
                    'まだ称号はありません。登録やチェックインで増えていきます。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF60707A),
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: progress.titles.map((title) {
                      final isCurrent = title == progress.currentTitle;
                      return _TitleChip(
                        label: title,
                        isCurrent: isCurrent,
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: '設定',
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '距離デフォルト',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334148),
                        ),
                      ),
                    ),
                    if (_isSavingDistance)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    const SizedBox(width: 8),
                    PopupMenuButton<int>(
                      onSelected: _saveDefaultDistance,
                      itemBuilder: (context) {
                        return _distanceOptions.map((meters) {
                          return PopupMenuItem<int>(
                            value: meters,
                            child: Text('${meters}m'),
                          );
                        }).toList();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FBFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE3E7EB),
                          ),
                        ),
                        child: Text(
                          '${_defaultDistanceMeters}m',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF334148),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _MenuRow(
                  icon: Icons.notifications_none_rounded,
                  title: '通知設定',
                  subtitle: 'お気に入り通知や更新通知',
                  onTap: _openNotifications,
                ),
                const SizedBox(height: 8),
                _MenuRow(
                  icon: Icons.workspace_premium_outlined,
                  title: 'プレミアム（予定）',
                  subtitle: '上限拡張・広告非表示・編集期限延長',
                  onTap: _showPremiumInfo,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'サポート / 運営',
            child: Column(
              children: [
                _MenuRow(
                  icon: Icons.feedback_outlined,
                  title: 'フィードバック',
                  subtitle: '改善要望や感想を送る',
                  onTap: _showFeedbackInfo,
                ),
                const SizedBox(height: 8),
                _MenuRow(
                  icon: Icons.mail_outline_rounded,
                  title: 'お問い合わせ',
                  subtitle: '不具合や相談の連絡先（今後接続）',
                  onTap: _showContactInfo,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'ガイド / 注意事項',
            child: Column(
              children: [
                _MenuRow(
                  icon: Icons.menu_book_rounded,
                  title: '使い方を見る',
                  subtitle: '初回チュートリアルをもう一度確認',
                  onTap: _openOnboardingAgain,
                ),
                const SizedBox(height: 8),
                _MenuRow(
                  icon: Icons.shield_outlined,
                  title: '注意事項を見る',
                  subtitle: '私有地・危険場所・周囲配慮の確認',
                  onTap: _openSafetyGuide,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestMyPage extends StatelessWidget {
  const _GuestMyPage({
    required this.onLogin,
  });

  final Future<void> Function() onLogin;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _SectionCard(
          title: 'マイページ',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ログインすると、経験値・称号・通知設定・お気に入り保存が使えるようになります。',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF60707A),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onLogin,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('ログイン / 新規登録'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SafetyGuideScreen extends StatelessWidget {
  const _SafetyGuideScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('注意事項'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: const [
          _SectionCard(
            title: '安全に使うために',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GuideBullet(text: '私有地には立ち入らない'),
                SizedBox(height: 10),
                _GuideBullet(text: '危険な場所や通行の妨げになる場所で操作しない'),
                SizedBox(height: 10),
                _GuideBullet(text: '周囲の迷惑にならないように利用する'),
                SizedBox(height: 10),
                _GuideBullet(text: '登録内容は見かけた範囲で無理なく入力する'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideBullet extends StatelessWidget {
  const _GuideBullet({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
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
              color: Color(0xFF334148),
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.title,
  });

  final Widget child;
  final String? title;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((title ?? '').trim().isNotEmpty) ...[
            Text(
              title!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334148),
              ),
            ),
            const SizedBox(height: 12),
          ],
          child,
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
        border: Border.all(color: const Color(0xFFE3E7EB)),
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

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E7EB)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF60707A),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334148),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF60707A),
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleChip extends StatelessWidget {
  const _TitleChip({
    required this.label,
    required this.isCurrent,
  });

  final String label;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFFFFF2D9) : const Color(0xFFF7FBFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFFFFD18B)
              : const Color(0xFFE3E7EB),
        ),
      ),
      child: Text(
        isCurrent ? '現在: $label' : label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: isCurrent
              ? const Color(0xFF8A5A00)
              : const Color(0xFF334148),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FBFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE3E7EB)),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: const Color(0xFF60707A),
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
                      color: Color(0xFF334148),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF60707A),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2D9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFFD18B)),
      ),
      child: const Text(
        'PREMIUM',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(0xFF8A5A00),
        ),
      ),
    );
  }
}