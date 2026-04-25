import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/user_progress_service.dart';
import '../widgets/my_page_feedback_section.dart';
import 'auth_gate.dart';
import 'favorite_drinks_screen.dart';
import 'notification_settings_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({
    super.key,
    this.isLoggedIn = false,
    this.openTitleListOnOpen = false,
  });

  final bool isLoggedIn;
  final bool openTitleListOnOpen;

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  bool _isLoggingOut = false;
  bool _isLoadingProgress = false;
  bool _isLoadingProfile = false;
  bool _isSavingDisplayName = false;
  bool _didAutoOpenTitleList = false;

  UserProgressSnapshot? _progress;
  String? _appDisplayName;

  UserProgressService get _progressService => UserProgressService.instance;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadProgress();
  }

  Future<void> _loadProfile() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _appDisplayName = null;
        _isLoadingProfile = false;
      });
      return;
    }

    setState(() {
      _isLoadingProfile = true;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? <String, dynamic>{};
      final String? savedName = _readNonEmptyString(data['appDisplayName']);

      if (!mounted) return;
      setState(() {
        _appDisplayName = savedName;
        _isLoadingProfile = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  String? _readNonEmptyString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  Future<void> _editDisplayName() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || _isSavingDisplayName) return;

    final String initialValue = _appDisplayName?.trim().isNotEmpty == true
        ? _appDisplayName!.trim()
        : ((user.displayName ?? '').trim().isNotEmpty
        ? user.displayName!.trim()
        : '');

    final TextEditingController controller =
    TextEditingController(text: initialValue);

    String? errorText;

    final String? result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('表示名を変更'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    maxLength: 20,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: '表示名',
                      hintText: 'アプリ内で表示する名前',
                      errorText: errorText,
                    ),
                    onChanged: (_) {
                      if (errorText != null) {
                        setDialogState(() {
                          errorText = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Googleアカウント名とは別に設定できます',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF60707A),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('キャンセル'),
                ),
                TextButton(
                  onPressed: () {
                    controller.clear();
                    Navigator.of(context).pop('');
                  },
                  child: const Text('アプリ名を解除'),
                ),
                FilledButton(
                  onPressed: () {
                    final String value = controller.text.trim();
                    if (value.isEmpty) {
                      setDialogState(() {
                        errorText = '1文字以上入力してください';
                      });
                      return;
                    }
                    Navigator.of(context).pop(value);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );


    if (result == null) return;

    setState(() {
      _isSavingDisplayName = true;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        <String, dynamic>{
          'appDisplayName': result.isEmpty ? FieldValue.delete() : result,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        _appDisplayName = result.isEmpty ? null : result;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isEmpty ? 'アプリ内表示名を解除しました' : '表示名を更新しました',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('表示名の保存に失敗しました: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSavingDisplayName = false;
      });
    }
  }

  Future<void> _loadProgress() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _progress = null;
        _isLoadingProgress = false;
      });
      return;
    }

    setState(() {
      _isLoadingProgress = true;
    });

    try {
      final UserProgressSnapshot snapshot =
      await _progressService.getProgress(uid: user.uid);

      if (!mounted) return;
      setState(() {
        _progress = snapshot;
        _isLoadingProgress = false;
      });

      _scheduleAutoOpenTitleListIfNeeded();
    } catch (_) {
      if (!mounted) return;
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
        _isLoadingProgress = false;
      });

      _scheduleAutoOpenTitleListIfNeeded();
    }
  }

  void _scheduleAutoOpenTitleListIfNeeded() {
    if (!widget.openTitleListOnOpen) return;
    if (_didAutoOpenTitleList) return;
    if (_isLoadingProgress) return;
    if (_progress == null) return;

    _didAutoOpenTitleList = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _showTitleList(_progress!);
    });
  }

  Set<String> _ownedTitleSet(UserProgressSnapshot progress) {
    return progress.titles
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toSet();
  }

  Future<void> _showTitleList(UserProgressSnapshot progress) async {
    final Set<String> ownedTitles = _ownedTitleSet(progress);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '称号一覧',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF334148),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '取得済み ${ownedTitles.length} / ${UserProgressService.titleRules.length}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF60707A),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView.separated(
                    itemCount: UserProgressService.titleRules.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final TitleRule definition =
                      UserProgressService.titleRules[index];
                      final bool owned = ownedTitles.contains(definition.title);
                      final bool current = progress.currentTitle == definition.title;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: owned
                              ? const Color(0xFFEAF6FF)
                              : const Color(0xFFF7F9FB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: current
                                ? const Color(0xFF64B5F6)
                                : owned
                                ? const Color(0xFFB6DBF6)
                                : const Color(0xFFE3E7EB),
                            width: current ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: owned
                                    ? const Color(0xFF64B5F6)
                                    : const Color(0xFFD9E0E5),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                owned
                                    ? Icons.emoji_events_rounded
                                    : Icons.lock_outline_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        definition.title,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF334148),
                                        ),
                                      ),
                                      if (current)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF64B5F6),
                                            borderRadius:
                                            BorderRadius.circular(999),
                                          ),
                                          child: const Text(
                                            '現在の称号',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: owned
                                              ? const Color(0xFFDDF1FF)
                                              : const Color(0xFFE9EEF2),
                                          borderRadius:
                                          BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          owned ? '取得済み' : '未取得',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: owned
                                                ? const Color(0xFF2E607E)
                                                : const Color(0xFF60707A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    definition.condition,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF60707A),
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}

      await FirebaseAuth.instance.signOut();
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoggingOut = false;
      });

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const AuthGate(),
        ),
            (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final bool loggedIn = widget.isLoggedIn || user != null;

    final String googleDisplayName =
    ((user?.displayName ?? '').trim().isNotEmpty)
        ? user!.displayName!.trim()
        : 'ゲスト';
    final String displayName = (_appDisplayName?.trim().isNotEmpty == true)
        ? _appDisplayName!.trim()
        : googleDisplayName;
    final String email = user?.email ?? 'メール未設定';

    final UserProgressSnapshot effectiveProgress =
        _progress ??
            const UserProgressSnapshot(
              exp: 0,
              level: 1,
              currentTitle: 'はじめの一歩',
              titles: <String>[],
              registeredMachineCount: 0,
              registeredDrinkCount: 0,
              checkinCount: 0,
            );

    return Scaffold(
      backgroundColor: const Color(0xFFEAF6FF),
      appBar: AppBar(
        title: const Text('マイページ'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadProfile();
          await _loadProgress();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _ProfileCard(
              displayName: displayName,
              email: email,
              loggedIn: loggedIn,
              isLoadingProfile: _isLoadingProfile,
              isSavingDisplayName: _isSavingDisplayName,
              hasCustomName: _appDisplayName?.trim().isNotEmpty == true,
              onTapEditName: loggedIn ? _editDisplayName : null,
            ),
            const SizedBox(height: 16),
            if (loggedIn)
              _isLoadingProgress
                  ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
                  : _ProgressSection(
                progress: effectiveProgress,
                progressRate: _progressService.levelProgressRate(
                  effectiveProgress.exp,
                ),
                expToNextLevel: _progressService.expToNextLevel(
                  effectiveProgress.exp,
                ),
                onTapTitleList: () => _showTitleList(effectiveProgress),
              )
            else
              const _GuestGuideCard(),
            const SizedBox(height: 16),
            _ActionMenuSection(loggedIn: loggedIn),
            const SizedBox(height: 16),
            if (loggedIn) ...<Widget>[
              const MyPageFeedbackSection(
                initialScreenName: 'my_page',
              ),
              const SizedBox(height: 16),
            ],
            //_PremiumSection(loggedIn: loggedIn),
            //const SizedBox(height: 16),
            if (loggedIn)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoggingOut ? null : _logout,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF60707A),
                  ),
                  child: _isLoggingOut
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('ログアウト'),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.displayName,
    required this.email,
    required this.loggedIn,
    required this.isLoadingProfile,
    required this.isSavingDisplayName,
    required this.hasCustomName,
    required this.onTapEditName,
  });

  final String displayName;
  final String email;
  final bool loggedIn;
  final bool isLoadingProfile;
  final bool isSavingDisplayName;
  final bool hasCustomName;
  final VoidCallback? onTapEditName;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: isLoadingProfile
                    ? const SizedBox(
                  height: 28,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
                    : Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334148),
                  ),
                ),
              ),
              if (loggedIn)
                OutlinedButton.icon(
                  onPressed: isSavingDisplayName ? null : onTapEditName,
                  icon: isSavingDisplayName
                      ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('表示名変更'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            email,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF60707A),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: loggedIn
                      ? const Color(0xFFEAF6FF)
                      : const Color(0xFFF5F7F8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  loggedIn ? 'ログイン中' : 'ゲスト利用中',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4B6472),
                  ),
                ),
              ),
              if (loggedIn && hasCustomName)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FBFC),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE3E7EB)),
                  ),
                  child: const Text(
                    'アプリ内表示名を使用中',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF60707A),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuestGuideCard extends StatelessWidget {
  const _GuestGuideCard();

  @override
  Widget build(BuildContext context) {
    return const _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'ログインするとできること',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334148),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '経験値・称号の保存、お気に入り管理、通知設定、フィードバック送信が使えます。',
            style: TextStyle(
              fontSize: 13,
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

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({
    required this.progress,
    required this.progressRate,
    required this.expToNextLevel,
    required this.onTapTitleList,
  });

  final UserProgressSnapshot progress;
  final double progressRate;
  final int expToNextLevel;
  final VoidCallback onTapTitleList;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF6FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Lv ${progress.level}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2E607E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      progress.currentTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334148),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progressRate,
                  minHeight: 12,
                  backgroundColor: const Color(0xFFE3E7EB),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF64B5F6),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'EXP ${progress.exp} / 次のレベルまで $expToNextLevel',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF60707A),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'ステータス',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334148),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _StatItem(
                      label: 'チェックイン',
                      value: '${progress.checkinCount}',
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      label: '登録自販機',
                      value: '${progress.registeredMachineCount}',
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      label: '登録ドリンク',
                      value: '${progress.registeredDrinkCount}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '称号',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334148),
                      ),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: onTapTitleList,
                    child: const Text('一覧を見る'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (progress.titles.isEmpty)
                const Text(
                  'まだ称号はありません',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF60707A),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: progress.titles.map((String title) {
                    final bool isCurrent = title == progress.currentTitle;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? const Color(0xFFEAF6FF)
                            : const Color(0xFFF5F7F8),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isCurrent
                              ? const Color(0xFFB6DBF6)
                              : const Color(0xFFE3E7EB),
                        ),
                      ),
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isCurrent
                              ? const Color(0xFF2E607E)
                              : const Color(0xFF4B6472),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionMenuSection extends StatelessWidget {
  const _ActionMenuSection({
    required this.loggedIn,
  });

  final bool loggedIn;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        children: <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.favorite_border_rounded),
            title: const Text('お気に入りドリンク'),
            subtitle: const Text('登録したドリンクを確認する'),
            trailing: const Icon(Icons.chevron_right),
            onTap: loggedIn
                ? () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FavoriteDrinksScreen(),
                ),
              );
            }
                : null,
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_none_rounded),
            title: const Text('通知設定'),
            subtitle: const Text('近くのドリンク通知や更新通知'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF334148),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF60707A),
          ),
        ),
      ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E7EB)),
      ),
      child: child,
    );
  }
}