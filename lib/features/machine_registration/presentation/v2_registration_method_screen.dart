import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_spacing.dart';
import '../application/machine_registration_controller.dart';

class V2RegistrationMethodScreen extends ConsumerWidget {
  const V2RegistrationMethodScreen({
    super.key,
    this.onPhotoSelected,
    this.onManufacturerSelected,
  });

  /// Phase 7 connection point. Null keeps the photo route unavailable while
  /// Phase 6 is being implemented.
  final VoidCallback? onPhotoSelected;

  /// P6-07 connection point.
  final VoidCallback? onManufacturerSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('登録方法')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(V2Spacing.lg),
          children: <Widget>[
            Text(
              '自販機をどう登録しますか？',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: V2Spacing.xs),
            Text(
              '写真から候補を探す方法と、メーカーを選ぶだけの簡単な方法があります。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: V2Spacing.lg),
            _RegistrationMethodCard(
              key: const Key('registrationPhotoMethodCard'),
              icon: Icons.photo_camera_outlined,
              title: '写真から登録',
              description: '自販機を撮影して、メーカーや商品の候補を探します。候補は確認・修正してから登録します。',
              actionLabel: onPhotoSelected == null ? '準備中' : '写真から登録',
              onPressed: onPhotoSelected == null
                  ? null
                  : () {
                      ref
                          .read(machineRegistrationControllerProvider.notifier)
                          .choosePhotoMethod();
                      onPhotoSelected?.call();
                    },
            ),
            const SizedBox(height: V2Spacing.md),
            _RegistrationMethodCard(
              key: const Key('registrationManufacturerMethodCard'),
              icon: Icons.local_drink_outlined,
              title: 'メーカーから簡単登録',
              description: 'メーカーを選ぶだけで、代表商品を「あるかも」として登録できます。実物の商品追加は任意です。',
              actionLabel: 'メーカーを選ぶ',
              onPressed: onManufacturerSelected == null
                  ? null
                  : () {
                      ref
                          .read(machineRegistrationControllerProvider.notifier)
                          .chooseManufacturerMethod();
                      onManufacturerSelected?.call();
                    },
              emphasized: true,
            ),
            const SizedBox(height: V2Spacing.md),
            const _PhaseNotice(),
          ],
        ),
      ),
    );
  }
}

class _RegistrationMethodCard extends StatelessWidget {
  const _RegistrationMethodCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onPressed,
    this.emphasized = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback? onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: V2Radius.card),
      child: Padding(
        padding: const EdgeInsets.all(V2Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: emphasized
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  foregroundColor: emphasized
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  child: Icon(icon),
                ),
                const SizedBox(width: V2Spacing.md),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: V2Spacing.md),
            Text(description),
            const SizedBox(height: V2Spacing.lg),
            if (emphasized)
              FilledButton(
                key: const Key('registrationManufacturerMethodButton'),
                onPressed: onPressed,
                child: Text(actionLabel),
              )
            else
              OutlinedButton(
                key: const Key('registrationPhotoMethodButton'),
                onPressed: onPressed,
                child: Text(actionLabel),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhaseNotice extends StatelessWidget {
  const _PhaseNotice();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          Icons.info_outline_rounded,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: V2Spacing.xs),
        Expanded(
          child: Text(
            '写真を使わなくても登録できます。メーカーが分からない場合は、次の画面で「分からない」を選べます。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
