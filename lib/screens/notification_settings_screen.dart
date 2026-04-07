import 'package:flutter/material.dart';

import '../services/nearby_favorite_notification_service.dart';
import '../services/notification_settings_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  bool _enabled = true;
  double _radiusMeters = 300;

  static const List<double> _radiusOptions = <double>[100, 300, 500];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await NotificationSettingsService.load();
    if (!mounted) return;

    setState(() {
      _enabled = settings.enabled;
      _radiusMeters = settings.radiusMeters;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
    });

    await NotificationSettingsService.save(
      enabled: _enabled,
      radiusMeters: _radiusMeters,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('通知設定を保存しました')),
    );
  }

  void _clearCache() {
    NearbyFavoriteNotificationService.clearNotifiedCache();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('通知済みキャッシュをリセットしました')),
    );
  }

  Widget _buildRadiusCard(double radius) {
    final selected = _radiusMeters == radius;

    return InkWell(
      onTap: () {
        setState(() {
          _radiusMeters = radius;
        });
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF6F7) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : const Color(0xFFE3E7EB),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.near_me_rounded,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : const Color(0xFF60707A),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${radius.toInt()}m 以内',
                style: TextStyle(
                  fontFamily: 'Noto Sans JP',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : const Color(0xFF334148),
                ),
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知設定'),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFEAEFF2)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading || _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.save_rounded),
              label: Text(_isSaving ? '保存中...' : '設定を保存'),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE3E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'お気に入りドリンク通知',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  '近くにお気に入りドリンクがある自販機を見つけたときに通知します。',
                  style: TextStyle(
                    fontFamily: 'Noto Sans JP',
                    fontSize: 13,
                    color: Color(0xFF60707A),
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _enabled,
                  title: const Text(
                    '通知を有効にする',
                    style: TextStyle(
                      fontFamily: 'Noto Sans JP',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _enabled = value;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Opacity(
            opacity: _enabled ? 1 : 0.5,
            child: IgnorePointer(
              ignoring: !_enabled,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE3E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '通知距離',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'まずは300mがおすすめです。',
                      style: TextStyle(
                        fontFamily: 'Noto Sans JP',
                        fontSize: 13,
                        color: Color(0xFF60707A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._radiusOptions.map((radius) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildRadiusCard(radius),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE3E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '通知キャッシュ',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  '同じ自販機から何度も通知されないように一時保存しています。',
                  style: TextStyle(
                    fontFamily: 'Noto Sans JP',
                    fontSize: 13,
                    color: Color(0xFF60707A),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _clearCache,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('通知済みキャッシュをリセット'),
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