import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_gate.dart';
import '../widgets/login_required_sheet.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  static const List<int> _distanceOptions = <int>[50, 100, 300, 500];

  bool _isLoading = true;
  bool _isSaving = false;

  bool _notificationsEnabled = true;
  bool _favoriteNearbyEnabled = true;
  bool _machineUpdateEnabled = true;
  int _notifyDistanceMeters = 100;

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
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snapshot.data() ?? <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        _notificationsEnabled =
            _readBool(data['notificationsEnabled'], defaultValue: true);
        _favoriteNearbyEnabled =
            _readBool(data['favoriteNearbyNotificationEnabled'],
                defaultValue: true);
        _machineUpdateEnabled =
            _readBool(data['machineUpdateNotificationEnabled'],
                defaultValue: true);
        _notifyDistanceMeters = _sanitizeDistance(
          _readNullableInt(data['notificationDistanceMeters']) ?? 100,
        );
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = true;
        _favoriteNearbyEnabled = true;
        _machineUpdateEnabled = true;
        _notifyDistanceMeters = 100;
        _isLoading = false;
      });
    }
  }

  Future<void> _save({
    bool? notificationsEnabled,
    bool? favoriteNearbyEnabled,
    bool? machineUpdateEnabled,
    int? notifyDistanceMeters,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final nextNotificationsEnabled =
        notificationsEnabled ?? _notificationsEnabled;
    final nextFavoriteNearbyEnabled =
        favoriteNearbyEnabled ?? _favoriteNearbyEnabled;
    final nextMachineUpdateEnabled =
        machineUpdateEnabled ?? _machineUpdateEnabled;
    final nextDistance =
    _sanitizeDistance(notifyDistanceMeters ?? _notifyDistanceMeters);

    setState(() {
      _isSaving = true;
      _notificationsEnabled = nextNotificationsEnabled;
      _favoriteNearbyEnabled = nextFavoriteNearbyEnabled;
      _machineUpdateEnabled = nextMachineUpdateEnabled;
      _notifyDistanceMeters = nextDistance;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        <String, dynamic>{
          'notificationsEnabled': nextNotificationsEnabled,
          'favoriteNearbyNotificationEnabled': nextFavoriteNearbyEnabled,
          'machineUpdateNotificationEnabled': nextMachineUpdateEnabled,
          'notificationDistanceMeters': nextDistance,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('通知設定の保存に失敗しました: $e'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _openLoginRequired() async {
    await LoginRequiredSheet.show(context);
    if (!mounted) return;
    await _load();
  }

  int _sanitizeDistance(int value) {
    if (_distanceOptions.contains(value)) return value;
    return 100;
  }

  bool _readBool(dynamic value, {required bool defaultValue}) {
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return defaultValue;
  }

  int? _readNullableInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final favoriteTileEnabled = _notificationsEnabled;
    final updateTileEnabled = _notificationsEnabled;
    final distanceEnabled = _notificationsEnabled && _favoriteNearbyEnabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知設定'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
          child: CircularProgressIndicator(),
        )
            : !_isLoggedIn
            ? _GuestNotificationView(
          onLogin: _openLoginRequired,
        )
            : ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '通知',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF334148),
                          ),
                        ),
                      ),
                      if (_isSaving)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'お気に入りドリンクが近くにある時や、登録した自販機の更新を通知します。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF60707A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    value: _notificationsEnabled,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      '通知を受け取る',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334148),
                      ),
                    ),
                    subtitle: const Text(
                      '通知全体のON/OFF',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF60707A),
                      ),
                    ),
                    onChanged: (value) => _save(
                      notificationsEnabled: value,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '通知の種類',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF334148),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    value: _favoriteNearbyEnabled,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'お気に入りドリンク近く通知',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334148),
                      ),
                    ),
                    subtitle: const Text(
                      '近くにお気に入りドリンクがある自販機が見つかった時',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF60707A),
                      ),
                    ),
                    onChanged: favoriteTileEnabled
                        ? (value) => _save(
                      favoriteNearbyEnabled: value,
                    )
                        : null,
                  ),
                  const Divider(height: 18),
                  SwitchListTile.adaptive(
                    value: _machineUpdateEnabled,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      '自販機更新通知',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334148),
                      ),
                    ),
                    subtitle: const Text(
                      'チェックインした自販機の内容が更新された時',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF60707A),
                      ),
                    ),
                    onChanged: updateTileEnabled
                        ? (value) => _save(
                      machineUpdateEnabled: value,
                    )
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '通知距離',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF334148),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'お気に入りドリンク近く通知の対象距離です。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF60707A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _distanceOptions.map((meters) {
                      final selected =
                          _notifyDistanceMeters == meters;
                      return ChoiceChip(
                        label: Text('${meters}m'),
                        selected: selected,
                        onSelected: distanceEnabled
                            ? (_) => _save(
                          notifyDistanceMeters: meters,
                        )
                            : null,
                      );
                    }).toList(),
                  ),
                  if (!distanceEnabled) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'この設定は「通知を受け取る」と「お気に入りドリンク近く通知」がONの時に使われます。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF60707A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            const _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'メモ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF334148),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '通知の実配信処理は、この設定をもとに動作します。MVPではまず基本の通知導線を通す想定です。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF60707A),
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestNotificationView extends StatelessWidget {
  const _GuestNotificationView({
    required this.onLogin,
  });

  final Future<void> Function() onLogin;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '通知設定',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334148),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '通知設定はログイン後に使えます。',
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