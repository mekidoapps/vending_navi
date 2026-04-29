import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/user_progress_service.dart';
import '../widgets/login_required_sheet.dart';
import '../widgets/my_page_feedback_section.dart';
import 'auth_gate.dart' show AuthGate;
import 'favorite_drinks_screen.dart';
import 'notification_settings_screen.dart';
import 'onboarding_screen.dart';

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
  static const List<int> _distanceOptions = <int>[50, 100, 500];

  bool _isLoggingOut = false;
  bool _isLoadingProgress = false;
  bool _isLoadingProfile = false;
  bool _isSavingDisplayName = false;
  bool _isSavingDistance = false;
  bool _didAutoOpenTitleList = false;

  UserProgressSnapshot? _progress;
  String? _appDisplayName;
  int _defaultDistanceMeters = 100;
  bool _isPremium = false;

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
        _defaultDistanceMeters = 100;
        _isPremium = false;
        _isLoadingProfile = false;
      });
      return;
    }

    setState(() {
      _isLoadingProfile = true;
    });

    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        _appDisplayName = _readNonEmptyString(data['appDisplayName']) ??
            _readNonEmptyString(data['displayName']);
        _defaultDistanceMeters = _sanitizeDistance(
          _readNullableInt(data['defaultDistanceMeters']) ?? 100,
        );
        _isPremium = data['isPremium'] == true;
        _isLoadingProfile = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
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

  String? _readNonEmptyString(dynamic value) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  int? _readNullableInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  int _sanitizeDistance(int value) {
    if (_distanceOptions.contains(value)) return value;
    return 100;
  }

  String _fallbackDisplayName(User? user) {
    final String authName = (user?.displayName ?? '').trim();
    if (authName.isNotEmpty) return authName;

    final String email = (user?.email ?? '').trim();
    if (email.isNotEmpty && email.contains('@')) return email.split('@').first;
    if (email.isNotEmpty) return email;

    return 'ゲスト';
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
              children: <Widget>[
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
                    itemBuilder: (BuildContext context, int index) {
                      final TitleRule definition =
                      UserProgressService.titleRules[index];
                      final bool owned = ownedTitles.contains(definition.title);
                      final bool current =
                          progress.currentTitle == definition.title;

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
                          children: <Widget>[
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
                                children: <Widget>[
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment:
                                    WrapCrossAlignment.center,
                                    children: <Widget>[
                                      Text(
                                        definition.title,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF334148),
                                        ),
                                      ),
                                      if (current)
                                        _SmallPill(
                                          label: '現在の称号',
                                          backgroundColor:
                                          const Color(0xFF64B5F6),
                                          textColor: Colors.white,
                                        ),
                                      _SmallPill(
                                        label: owned ? '取得済み' : '未取得',
                                        backgroundColor: owned
                                            ? const Color(0xFFDDF1FF)
                                            : const Color(0xFFE9EEF2),
                                        textColor: owned
                                            ? const Color(0xFF2E607E)
                                            : const Color(0xFF60707A),
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

  Future<void> _editDisplayName() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || _isSavingDisplayName) return;

    final String initialValue = _appDisplayName?.trim().isNotEmpty == true
        ? _appDisplayName!.trim()
        : _fallbackDisplayName(user);
    final TextEditingController controller =
    TextEditingController(text: initialValue == 'ゲスト' ? '' : initialValue);

    String? errorText;

    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('表示名を変更'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
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
              actions: <Widget>[
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
          'displayName': result.isEmpty ? FieldValue.delete() : result,
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
          content: Text(result.isEmpty ? 'アプリ内表示名を解除しました' : '表示名を更新しました'),
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

  Future<void> _saveDefaultDistance(int meters) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || _isSavingDistance) return;

    final int sanitized = _sanitizeDistance(meters);

    setState(() {
      _isSavingDistance = true;
      _defaultDistanceMeters = sanitized;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('距離デフォルトを${sanitized}mに変更しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('距離デフォルトの保存に失敗しました: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSavingDistance = false;
      });
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await FirebaseAuth.instance.signOut();
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoggingOut = false;
      });

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const AuthGate()),
            (Route<dynamic> route) => false,
      );
    }
  }

  Future<void> _openNotifications() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null && !widget.isLoggedIn) {
      await _openLoginRequired();
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const NotificationSettingsScreen(),
      ),
    );
  }

  Future<void> _openFavoriteDrinks() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null && !widget.isLoggedIn) {
      await _openLoginRequired();
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const FavoriteDrinksScreen(),
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

  void _showFeedbackInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('フィードバックはこの画面内のフォームから送信できます。')),
    );
  }

  void _showContactInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('お問い合わせ導線は次の段階で接続します。')),
    );
  }

  void _showPremiumInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('プレミアム導線は今後追加予定です。')),
    );
  }

  Future<void> _openSafetyGuide() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const _SafetyGuideScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final bool loggedIn = widget.isLoggedIn || user != null;

    final String displayName = (_appDisplayName?.trim().isNotEmpty == true)
        ? _appDisplayName!.trim()
        : _fallbackDisplayName(user);
    final String email = user?.email?.trim().isNotEmpty == true
        ? user!.email!.trim()
        : 'メール未設定';

    final UserProgressSnapshot effectiveProgress = _progress ??
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
              isPremium: _isPremium,
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
            _SettingsSection(
              loggedIn: loggedIn,
              defaultDistanceMeters: _defaultDistanceMeters,
              isSavingDistance: _isSavingDistance,
              onSelectedDistance: _saveDefaultDistance,
              onTapNotifications: _openNotifications,
              onTapPremium: _showPremiumInfo,
            ),
            const SizedBox(height: 16),
            _ActionMenuSection(
              loggedIn: loggedIn,
              onTapFavorites: _openFavoriteDrinks,
              onTapNotifications: _openNotifications,
            ),
            const SizedBox(height: 16),
            _SupportSection(
              onTapFeedback: _showFeedbackInfo,
              onTapContact: _showContactInfo,
            ),
            const SizedBox(height: 16),
            _GuideSection(
              onTapOnboarding: _openOnboardingAgain,
              onTapSafety: _openSafetyGuide,
            ),
            const SizedBox(height: 16),
            if (loggedIn) ...<Widget>[
              const MyPageFeedbackSection(initialScreenName: 'my_page'),
              const SizedBox(height: 16),
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
            ],
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
    required this.isPremium,
    required this.onTapEditName,
  });

  final String displayName;
  final String email;
  final bool loggedIn;
  final bool isLoadingProfile;
  final bool isSavingDisplayName;
  final bool hasCustomName;
  final bool isPremium;
  final VoidCallback? onTapEditName;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
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
                  children: <Widget>[
                    isLoadingProfile
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
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF60707A),
                      ),
                    ),
                  ],
                ),
              ),
              if (isPremium) const _PremiumBadge(),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _SmallPill(
                label: loggedIn ? 'ログイン中' : 'ゲスト利用中',
                backgroundColor:
                loggedIn ? const Color(0xFFEAF6FF) : const Color(0xFFF5F7F8),
                textColor: const Color(0xFF4B6472),
              ),
              if (loggedIn && hasCustomName)
                const _SmallPill(
                  label: 'アプリ内表示名を使用中',
                  backgroundColor: Color(0xFFF7FBFC),
                  textColor: Color(0xFF60707A),
                  borderColor: Color(0xFFE3E7EB),
                ),
            ],
          ),
          if (loggedIn) ...<Widget>[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isSavingDisplayName ? null : onTapEditName,
                icon: isSavingDisplayName
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.edit_rounded),
                label: Text(isSavingDisplayName ? '保存中…' : '表示名を変更'),
              ),
            ),
          ],
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
          title: 'ステータス',
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
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
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
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: '称号',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      '取得した称号',
                      style: TextStyle(
                        fontSize: 14,
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
                  'まだ称号はありません。登録やチェックインで増えていきます。',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF60707A),
                    height: 1.5,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: progress.titles.map((String title) {
                    return _TitleChip(
                      label: title,
                      isCurrent: title == progress.currentTitle,
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

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.loggedIn,
    required this.defaultDistanceMeters,
    required this.isSavingDistance,
    required this.onSelectedDistance,
    required this.onTapNotifications,
    required this.onTapPremium,
  });

  final bool loggedIn;
  final int defaultDistanceMeters;
  final bool isSavingDistance;
  final ValueChanged<int> onSelectedDistance;
  final VoidCallback onTapNotifications;
  final VoidCallback onTapPremium;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '設定',
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
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
              if (isSavingDistance)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const SizedBox(width: 8),
              PopupMenuButton<int>(
                enabled: loggedIn && !isSavingDistance,
                onSelected: onSelectedDistance,
                itemBuilder: (BuildContext context) {
                  return const <int>[50, 100, 500].map((int meters) {
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
                    border: Border.all(color: const Color(0xFFE3E7EB)),
                  ),
                  child: Text(
                    '${defaultDistanceMeters}m',
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
            onTap: onTapNotifications,
          ),
          const SizedBox(height: 8),
          _MenuRow(
            icon: Icons.workspace_premium_outlined,
            title: 'プレミアム（予定）',
            subtitle: '上限拡張・広告非表示・編集期限延長',
            onTap: onTapPremium,
          ),
        ],
      ),
    );
  }
}

class _ActionMenuSection extends StatelessWidget {
  const _ActionMenuSection({
    required this.loggedIn,
    required this.onTapFavorites,
    required this.onTapNotifications,
  });

  final bool loggedIn;
  final VoidCallback onTapFavorites;
  final VoidCallback onTapNotifications;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'メニュー',
      child: Column(
        children: <Widget>[
          _MenuRow(
            icon: Icons.favorite_border_rounded,
            title: 'お気に入りドリンク',
            subtitle: loggedIn ? '登録したドリンクを確認する' : 'ログインすると使えます',
            onTap: onTapFavorites,
          ),
          const SizedBox(height: 8),
          _MenuRow(
            icon: Icons.notifications_none_rounded,
            title: '通知設定',
            subtitle: '近くのドリンク通知や更新通知',
            onTap: onTapNotifications,
          ),
        ],
      ),
    );
  }
}

class _SupportSection extends StatelessWidget {
  const _SupportSection({
    required this.onTapFeedback,
    required this.onTapContact,
  });

  final VoidCallback onTapFeedback;
  final VoidCallback onTapContact;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'サポート / 運営',
      child: Column(
        children: <Widget>[
          _MenuRow(
            icon: Icons.feedback_outlined,
            title: 'フィードバック',
            subtitle: '改善要望や感想を送る',
            onTap: onTapFeedback,
          ),
          const SizedBox(height: 8),
          _MenuRow(
            icon: Icons.mail_outline_rounded,
            title: 'お問い合わせ',
            subtitle: '不具合や相談の連絡先（今後接続）',
            onTap: onTapContact,
          ),
        ],
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    required this.onTapOnboarding,
    required this.onTapSafety,
  });

  final VoidCallback onTapOnboarding;
  final VoidCallback onTapSafety;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'ガイド / 注意事項',
      child: Column(
        children: <Widget>[
          _MenuRow(
            icon: Icons.menu_book_rounded,
            title: '使い方を見る',
            subtitle: '初回チュートリアルをもう一度確認',
            onTap: onTapOnboarding,
          ),
          const SizedBox(height: 8),
          _MenuRow(
            icon: Icons.shield_outlined,
            title: '注意事項を見る',
            subtitle: '私有地・危険場所・周囲配慮の確認',
            onTap: onTapSafety,
          ),
        ],
      ),
    );
  }
}

class _SafetyGuideScreen extends StatelessWidget {
  const _SafetyGuideScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注意事項')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: const <Widget>[
          _SectionCard(
            title: '安全に使うために',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
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
  const _GuideBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if ((title ?? '').trim().isNotEmpty) ...<Widget>[
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

class _SmallPill extends StatelessWidget {
  const _SmallPill({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
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
        children: <Widget>[
          Icon(icon, size: 20, color: const Color(0xFF60707A)),
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
          color: isCurrent ? const Color(0xFFFFD18B) : const Color(0xFFE3E7EB),
        ),
      ),
      child: Text(
        isCurrent ? '現在: $label' : label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: isCurrent ? const Color(0xFF8A5A00) : const Color(0xFF334148),
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
          children: <Widget>[
            Icon(icon, size: 20, color: const Color(0xFF60707A)),
            const SizedBox(width: 10),
            Expanded(
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
