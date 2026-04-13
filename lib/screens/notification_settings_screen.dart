import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _isSavingFavorite = false;
  bool _isSavingMachine = false;

  Future<void> _updateSetting({
    required String uid,
    required String key,
    required bool value,
    required void Function(bool saving) setSaving,
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
          content: Text('保存に失敗しました: $e'),
        ),
      );
    } finally {
      if (!mounted) return;
      setSaving(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFD6ECFF),
      appBar: AppBar(
        title: const Text('通知設定'),
      ),
      body: SafeArea(
        child: user == null
            ? const _LoggedOutView()
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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

            final favoriteDrinkNoticeEnabled =
            _readBoolWithFallback(
              data['favoriteDrinkNoticeEnabled'],
              fallback: true,
            );

            final machineUpdateNoticeEnabled =
            _readBoolWithFallback(
              data['machineUpdateNoticeEnabled'],
              fallback: false,
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                const _SectionCard(
                  title: '通知について',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '今後、近くの自販機情報や更新情報を受け取りやすくするための設定です。',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF60707A),
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: '通知項目',
                  child: Column(
                    children: [
                      _NotificationToggleCard(
                        icon: Icons.notifications_active_rounded,
                        title: 'お気に入りドリンク近く通知',
                        description:
                        'お気に入り登録したドリンクが近くで見つかった時に知らせます。',
                        value: favoriteDrinkNoticeEnabled,
                        isSaving: _isSavingFavorite,
                        onChanged: (value) async {
                          await _updateSetting(
                            uid: user.uid,
                            key: 'favoriteDrinkNoticeEnabled',
                            value: value,
                            setSaving: (saving) {
                              setState(() {
                                _isSavingFavorite = saving;
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _NotificationToggleCard(
                        icon: Icons.update_rounded,
                        title: 'チェックイン自販機更新通知',
                        description:
                        '登録した自販機の内容が更新された時に知らせます。',
                        value: machineUpdateNoticeEnabled,
                        isSaving: _isSavingMachine,
                        onChanged: (value) async {
                          await _updateSetting(
                            uid: user.uid,
                            key: 'machineUpdateNoticeEnabled',
                            value: value,
                            setSaving: (saving) {
                              setState(() {
                                _isSavingMachine = saving;
                              });
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
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
                          '通知そのものの配信ロジックはこのあと実装します。今は設定値の保存までを先に整えています。',
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
            );
          },
        ),
      ),
    );
  }

  static bool _readBoolWithFallback(
      dynamic value, {
        required bool fallback,
      }) {
    if (value is bool) return value;
    return fallback;
  }
}

class _LoggedOutView extends StatelessWidget {
  const _LoggedOutView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        const _SectionCard(
          title: '通知設定',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 40),
              SizedBox(height: 10),
              Text(
                'ログインすると通知設定を保存できます。',
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
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
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
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _NotificationToggleCard extends StatelessWidget {
  const _NotificationToggleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.isSaving,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final bool isSaving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE3E7EB)),
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
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF60707A),
                    height: 1.5,
                  ),
                ),
                if (isSaving) ...[
                  const SizedBox(height: 8),
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
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: isSaving ? null : onChanged,
          ),
        ],
      ),
    );
  }
}