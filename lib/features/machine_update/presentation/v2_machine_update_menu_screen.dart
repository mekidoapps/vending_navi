import 'package:flutter/material.dart';

import '../../../app/theme/v2_color_tokens.dart';
import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../../app/theme/v2_theme.dart';
import '../../vending_machine/domain/value_objects/vending_machine_id.dart';

class V2MachineUpdateMenuScreen extends StatelessWidget {
  const V2MachineUpdateMenuScreen({
    super.key,
    required this.machineId,
    required this.onManualProductUpdatePressed,
    this.onPhotoUpdatePressed,
    this.onBasicInfoCorrectionPressed,
  });

  final VendingMachineId machineId;
  final VoidCallback onManualProductUpdatePressed;
  final VoidCallback? onPhotoUpdatePressed;
  final VoidCallback? onBasicInfoCorrectionPressed;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return Theme(
      data: V2Theme.light(),
      child: Scaffold(
        appBar: AppBar(title: const Text('情報を更新')),
        body: ListView(
          padding: const EdgeInsets.all(V2Spacing.md),
          children: <Widget>[
            Text(
              '更新する情報を選んでください',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: V2Spacing.xs),
            Text(
              '実際に確認できた情報だけを更新してください。',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: V2Spacing.lg),
            _UpdateActionCard(
              key: const Key('photoProductUpdateMenuItem'),
              icon: Icons.photo_camera_outlined,
              title: '写真から商品情報を更新',
              description: '今の自販機を撮影して、AIが見つけた商品候補を確認します。',
              onPressed: onPhotoUpdatePressed,
            ),
            const SizedBox(height: V2Spacing.md),
            _UpdateActionCard(
              key: const Key('manualProductUpdateMenuItem'),
              icon: Icons.local_drink_outlined,
              title: '商品情報を更新',
              description: '商品の追加、売り切れ、なくなった商品の反映などを行います。',
              onPressed: onManualProductUpdatePressed,
            ),
            const SizedBox(height: V2Spacing.md),
            _UpdateActionCard(
              key: const Key('basicInfoCorrectionMenuItem'),
              icon: Icons.edit_location_alt_outlined,
              title: '基本情報の修正を提案',
              description: '名前、メーカー、位置、場所メモ、屋内・屋外の修正を提案します。',
              onPressed: onBasicInfoCorrectionPressed,
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateActionCard extends StatelessWidget {
  const _UpdateActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return Material(
      color: colors.surfaceElevated,
      borderRadius: V2Radius.card,
      child: InkWell(
        borderRadius: V2Radius.card,
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(V2Spacing.md),
          decoration: BoxDecoration(
            borderRadius: V2Radius.card,
            border: Border.all(color: colors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: colors.primaryStrong, size: 28),
              const SizedBox(width: V2Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: V2Spacing.xs),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: V2Spacing.sm),
              Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
