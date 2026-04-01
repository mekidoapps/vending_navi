import 'package:flutter/material.dart';

import '../models/vending_machine.dart';
import '../services/map_launcher_service.dart';
import '../theme/app_colors.dart';
import '../utils/distance_util.dart';

class MachineDetailScreen extends StatefulWidget {
  const MachineDetailScreen({
    super.key,
    required this.machine,
  });

  final VendingMachine machine;

  @override
  State<MachineDetailScreen> createState() => _MachineDetailScreenState();
}

class _MachineDetailScreenState extends State<MachineDetailScreen> {
  final MapLauncherService _mapLauncherService = MapLauncherService();

  bool _isLaunchingMap = false;

  Future<void> _openNavigation() async {
    if (_isLaunchingMap) return;

    setState(() {
      _isLaunchingMap = true;
    });

    try {
      await _mapLauncherService.openWalkingNavigation(
        latitude: widget.machine.latitude,
        longitude: widget.machine.longitude,
        label: widget.machine.name,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('地図アプリを起動できませんでした'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLaunchingMap = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final machine = widget.machine;
    final photos = machine.photoUrls;
    final tags = machine.tags;
    final drinks = machine.drinks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('自販機詳細'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _HeroSection(
                machine: machine,
                isLaunchingMap: _isLaunchingMap,
                onOpenNavigation: _openNavigation,
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: '写真',
                child: photos.isEmpty
                    ? _EmptyPhotoState(machineName: machine.name)
                    : SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final url = photos[index];
                      final isMain = index == 0;

                      return Stack(
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Container(
                              width: 260,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSoft,
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) {
                                  return Container(
                                    color: AppColors.surfaceSoft,
                                    child: const Center(
                                      child: Icon(
                                        Icons.broken_image_rounded,
                                        size: 42,
                                        color: AppColors.textHint,
                                      ),
                                    ),
                                  );
                                },
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    color: AppColors.surfaceSoft,
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isMain
                                    ? AppColors.accent
                                    : Colors.black.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isMain ? 'メイン写真' : '写真 ${index + 1}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'タグ',
                child: tags.isEmpty
                    ? Text(
                  'タグ情報はまだありません',
                  style: theme.textTheme.bodySmall,
                )
                    : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags
                      .map(
                        (String tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'ドリンク一覧',
                child: drinks.isEmpty
                    ? Text(
                  'ドリンク情報はまだありません',
                  style: theme.textTheme.bodySmall,
                )
                    : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: drinks
                      .map(
                        (drink) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.local_drink_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                drink.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (drink.brand.isNotEmpty)
                                Text(
                                  drink.brand,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: '更新情報',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      machine.updatedLabel.isEmpty ? '更新情報なし' : machine.updatedLabel,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '登録した自販機が役に立ったよ！',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (machine.checkinCount > 0) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        'チェックイン ${machine.checkinCount} 回',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    if (machine.reliabilityScore > 0) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        '信頼度スコア ${machine.reliabilityScore}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.machine,
    required this.isLaunchingMap,
    required this.onOpenNavigation,
  });

  final VendingMachine machine;
  final bool isLaunchingMap;
  final VoidCallback onOpenNavigation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  machine.name,
                  style: theme.textTheme.headlineMedium?.copyWith(fontSize: 26),
                ),
              ),
              if (machine.hasFavoriteMatch)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2E7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'おすすめ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            machine.headline,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _MetaChip(
                icon: Icons.place_rounded,
                text:
                '${DistanceUtil.formatDistance(machine.distanceMeters)} ${DistanceUtil.formatWalkingTime(machine.distanceMeters)}',
              ),
              if (machine.paymentLabel.isNotEmpty)
                _MetaChip(
                  icon: Icons.payments_rounded,
                  text: machine.paymentLabel,
                ),
              if (machine.updatedLabel.isNotEmpty)
                _MetaChip(
                  icon: Icons.update_rounded,
                  text: machine.updatedLabel,
                ),
            ],
          ),
          if (machine.addressHint.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              machine.addressHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'ここにありそう',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isLaunchingMap ? null : onOpenNavigation,
                  icon: isLaunchingMap
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.directions_walk_rounded),
                  label: Text(isLaunchingMap ? '起動中...' : 'ここに行く'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLaunchingMap ? null : onOpenNavigation,
                  icon: const Icon(Icons.map_rounded),
                  label: const Text('地図で開く'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyPhotoState extends StatelessWidget {
  const _EmptyPhotoState({
    required this.machineName,
  });

  final String machineName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 190,
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.photo_camera_back_rounded,
              size: 40,
              color: AppColors.primary,
            ),
            const SizedBox(height: 10),
            const Text(
              'まだ写真はありません',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              machineName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}