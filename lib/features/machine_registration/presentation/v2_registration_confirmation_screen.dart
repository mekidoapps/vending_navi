import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../product_master/domain/entities/manufacturer.dart';
import '../application/machine_registration_controller.dart';
import '../application/manufacturer_selection_controller.dart';
import '../domain/entities/machine_registration_method.dart';

class V2RegistrationConfirmationScreen extends ConsumerWidget {
  const V2RegistrationConfirmationScreen({super.key, this.onSubmit});

  /// Production supplies the P6-09 Callable-backed submit action from the
  /// app composition layer. Tests/previews may leave it null.
  final Future<void> Function()? onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registrationState = ref.watch(machineRegistrationControllerProvider);
    final draft = registrationState.draft;
    final manufacturerState = ref.watch(
      manufacturerSelectionControllerProvider,
    );

    final manufacturer = _findManufacturer(
      manufacturerState.manufacturers,
      draft.manufacturerId?.value,
    );
    final isLocationOnly =
        draft.registrationMethod == MachineRegistrationMethod.locationOnly;
    final isSubmitting = registrationState.isSubmitting;
    final failure = registrationState.failure;

    return Scaffold(
      appBar: AppBar(title: const Text('登録内容の確認')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(V2Spacing.lg),
          children: <Widget>[
            Text(
              'この内容で登録します',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: V2Spacing.xs),
            Text(
              isLocationOnly
                  ? 'メーカーや商品を推定せず、自販機の位置を登録します。'
                  : 'メーカーの代表商品は、確認済みではなく「あるかも」として登録されます。',
            ),
            const SizedBox(height: V2Spacing.lg),
            _ReviewCard(
              title: '位置',
              icon: Icons.location_on_outlined,
              child: draft.location == null
                  ? const Text('位置が選択されていません')
                  : Text(
                      '${draft.location!.latitude.toStringAsFixed(5)}, '
                      '${draft.location!.longitude.toStringAsFixed(5)}',
                      key: const Key('registrationConfirmationLocation'),
                    ),
            ),
            const SizedBox(height: V2Spacing.sm),
            _ReviewCard(
              title: '自販機名',
              icon: Icons.label_outline_rounded,
              child: Text(
                draft.name?.trim().isNotEmpty == true
                    ? draft.name!.trim()
                    : '登録時に自動設定',
                key: const Key('registrationConfirmationName'),
              ),
            ),
            const SizedBox(height: V2Spacing.sm),
            _ReviewCard(
              title: 'メーカー',
              icon: Icons.local_drink_outlined,
              child: Text(
                isLocationOnly
                    ? '分からない'
                    : manufacturer?.displayShortName ??
                          draft.manufacturerId?.value ??
                          '未選択',
                key: const Key('registrationConfirmationManufacturer'),
              ),
            ),
            const SizedBox(height: V2Spacing.sm),
            _ReviewCard(
              title: '商品情報',
              icon: Icons.inventory_2_outlined,
              child: _ProductSummary(
                isLocationOnly: isLocationOnly,
                manufacturer: manufacturer,
                confirmedCount: draft.confirmedProductIds.length,
              ),
            ),
            const SizedBox(height: V2Spacing.sm),
            _ReviewCard(
              title: '場所情報',
              icon: Icons.place_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '設置場所: ${_installationLabel(draft.installationType.wireValue)}',
                  ),
                  const SizedBox(height: V2Spacing.xxs),
                  Text(
                    draft.placeDescription?.trim().isNotEmpty == true
                        ? draft.placeDescription!.trim()
                        : '場所メモなし',
                  ),
                ],
              ),
            ),
            const SizedBox(height: V2Spacing.lg),
            const _ReliabilityNotice(),
            if (failure != null) ...<Widget>[
              const SizedBox(height: V2Spacing.md),
              _SubmitFailureCard(
                title: failure.userTitle,
                message: failure.userMessage,
              ),
            ],
            const SizedBox(height: V2Spacing.lg),
            FilledButton.icon(
              key: const Key('registrationConfirmationSubmitButton'),
              onPressed: onSubmit == null || isSubmitting
                  ? null
                  : () async {
                      await onSubmit!.call();
                    },
              icon: isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_location_alt_outlined),
              label: Text(
                isSubmitting
                    ? '登録中…'
                    : onSubmit == null
                    ? '保存処理を準備中'
                    : '登録する',
              ),
            ),
            const SizedBox(height: V2Spacing.sm),
            OutlinedButton(
              key: const Key('registrationConfirmationBackButton'),
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.of(context).maybePop(),
              child: const Text('修正に戻る'),
            ),
          ],
        ),
      ),
    );
  }

  static Manufacturer? _findManufacturer(
    List<Manufacturer> manufacturers,
    String? id,
  ) {
    if (id == null) {
      return null;
    }

    for (final manufacturer in manufacturers) {
      if (manufacturer.id.value == id) {
        return manufacturer;
      }
    }
    return null;
  }

  static String _installationLabel(String wireValue) {
    return switch (wireValue) {
      'outdoor' => '屋外',
      'indoor' => '屋内',
      _ => '不明',
    };
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: V2Radius.card),
      child: Padding(
        padding: const EdgeInsets.all(V2Spacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon),
            const SizedBox(width: V2Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: V2Spacing.xxs),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductSummary extends StatelessWidget {
  const _ProductSummary({
    required this.isLocationOnly,
    required this.manufacturer,
    required this.confirmedCount,
  });

  final bool isLocationOnly;
  final Manufacturer? manufacturer;
  final int confirmedCount;

  @override
  Widget build(BuildContext context) {
    if (isLocationOnly) {
      return const Text(
        '商品情報なし',
        key: Key('registrationConfirmationProductSummary'),
      );
    }

    final inferredCount = manufacturer?.presetProductIds.length;

    return Column(
      key: const Key('registrationConfirmationProductSummary'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (inferredCount != null)
          Text(
            inferredCount == 0
                ? 'メーカー代表商品の推定なし'
                : 'メーカー代表商品 $inferredCount件を「あるかも」として登録',
          )
        else
          const Text('メーカー代表商品を「あるかも」として登録'),
        if (confirmedCount > 0) ...<Widget>[
          const SizedBox(height: V2Spacing.xxs),
          Text('実物確認済み商品 $confirmedCount件'),
        ],
      ],
    );
  }
}

class _ReliabilityNotice extends StatelessWidget {
  const _ReliabilityNotice();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: V2Radius.card,
      ),
      child: const Padding(
        padding: EdgeInsets.all(V2Spacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.info_outline_rounded, size: 20),
            SizedBox(width: V2Spacing.sm),
            Expanded(
              child: Text('メーカーから推定した商品は、実際に置いてあることを確認した情報とは区別して公開します。'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmitFailureCard extends StatelessWidget {
  const _SubmitFailureCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('registrationConfirmationFailure'),
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: V2Radius.card),
      child: Padding(
        padding: const EdgeInsets.all(V2Spacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: V2Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: V2Spacing.xxs),
                  Text(message),
                  const SizedBox(height: V2Spacing.xxs),
                  const Text('内容を確認して、もう一度「登録する」を押してください。'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
