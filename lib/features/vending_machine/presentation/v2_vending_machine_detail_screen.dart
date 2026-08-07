import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/v2_color_tokens.dart';
import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../../app/theme/v2_theme.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/ui/badges/v2_status_badge.dart';
import '../../../core/ui/states/v2_error_state.dart';
import '../../../core/ui/states/v2_loading_state.dart';
import '../application/models/vending_machine_detail_data.dart';
import '../application/providers/vending_machine_detail_providers.dart';
import '../domain/entities/vending_machine_enums.dart';
import '../domain/value_objects/vending_machine_id.dart';

class V2VendingMachineDetailScreen extends ConsumerWidget {
  const V2VendingMachineDetailScreen({super.key, required this.machineId});

  final VendingMachineId machineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(vendingMachineDetailProvider(machineId));

    return Theme(
      data: V2Theme.light(),
      child: Scaffold(
        appBar: AppBar(title: const Text('自販機詳細')),
        body: detail.when(
          loading: () => const V2LoadingState(message: '自販機情報を読み込んでいます'),
          error: (_, __) => V2ErrorState(
            title: '自販機情報を読み込めませんでした',
            message: '時間をおいて、もう一度お試しください。',
            onRetry: () {
              ref.invalidate(vendingMachineDetailProvider(machineId));
            },
          ),
          data: (result) {
            return result.fold(
              onSuccess: (data) => _DetailBody(data: data),
              onFailure: (failure) => _FailureBody(
                failure: failure,
                onRetry: failure.isRetryable
                    ? () {
                        ref.invalidate(vendingMachineDetailProvider(machineId));
                      }
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FailureBody extends StatelessWidget {
  const _FailureBody({required this.failure, required this.onRetry});

  final AppFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return V2ErrorState(
      title: failure.userTitle,
      message: failure.userMessage,
      onRetry: onRetry,
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.data});

  final VendingMachineDetailData data;

  @override
  Widget build(BuildContext context) {
    final machine = data.machine;

    return ListView(
      padding: const EdgeInsets.all(V2Spacing.md),
      children: <Widget>[
        _MachineHeaderCard(data: data),
        const SizedBox(height: V2Spacing.md),
        _SectionCard(
          title: '設置情報',
          child: Column(
            children: <Widget>[
              _InfoRow(
                icon: Icons.business_rounded,
                label: 'メーカー',
                value: data.manufacturerName,
              ),
              const SizedBox(height: V2Spacing.sm),
              _InfoRow(
                icon: Icons.place_rounded,
                label: '場所',
                value: machine.placeDescription?.trim().isNotEmpty == true
                    ? machine.placeDescription!.trim()
                    : '場所の説明は未登録です',
              ),
              const SizedBox(height: V2Spacing.sm),
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: '位置',
                value:
                    '${machine.location.latitude.toStringAsFixed(5)}, '
                    '${machine.location.longitude.toStringAsFixed(5)}',
              ),
            ],
          ),
        ),
        const SizedBox(height: V2Spacing.md),
        _SectionCard(
          title: 'ドリンク',
          child: data.products.isEmpty
              ? const _NoProducts()
              : Column(
                  children: <Widget>[
                    for (
                      var index = 0;
                      index < data.products.length;
                      index++
                    ) ...<Widget>[
                      _ProductRow(item: data.products[index]),
                      if (index != data.products.length - 1)
                        const Divider(height: V2Spacing.lg),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _MachineHeaderCard extends StatelessWidget {
  const _MachineHeaderCard({required this.data});

  final VendingMachineDetailData data;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);
    final machine = data.machine;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: V2Radius.card,
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(V2Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              machine.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: V2Spacing.xs),
            Text(
              data.manufacturerName,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: V2Spacing.sm),
            Wrap(
              spacing: V2Spacing.xs,
              runSpacing: V2Spacing.xs,
              children: <Widget>[
                if (data.hasConfirmedProducts)
                  const V2StatusBadge(type: V2StatusBadgeType.confirmed)
                else if (data.hasInferredProducts)
                  const V2StatusBadge(type: V2StatusBadgeType.inferred)
                else
                  _PlainStatusChip(
                    icon: Icons.inventory_2_outlined,
                    label: '商品情報なし',
                  ),
                if (machine.isLegacy)
                  const _PlainStatusChip(
                    icon: Icons.sync_alt_rounded,
                    label: '旧データ互換',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: V2Radius.card,
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(V2Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: V2Spacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 20, color: colors.primaryStrong),
        const SizedBox(width: V2Spacing.sm),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: V2Spacing.xs),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.item});

  final VendingMachineProductDetailItem item;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                item.productName,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: V2Spacing.xs),
              Wrap(
                spacing: V2Spacing.xs,
                runSpacing: V2Spacing.xs,
                children: <Widget>[
                  if (item.isConfirmed)
                    const V2StatusBadge(type: V2StatusBadgeType.confirmed)
                  else if (item.isInferred)
                    const V2StatusBadge(type: V2StatusBadgeType.inferred),
                  _AvailabilityChip(availability: item.availability),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvailabilityChip extends StatelessWidget {
  const _AvailabilityChip({required this.availability});

  final ProductAvailability availability;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    final presentation = switch (availability) {
      ProductAvailability.available => (
        icon: Icons.check_rounded,
        label: '販売中',
        foreground: colors.confirmed,
        background: colors.primarySoft,
      ),
      ProductAvailability.soldOut => (
        icon: Icons.remove_shopping_cart_outlined,
        label: '売り切れ',
        foreground: colors.warning,
        background: colors.warning.withValues(alpha: 0.12),
      ),
      ProductAvailability.unknown => (
        icon: Icons.help_outline_rounded,
        label: '在庫不明',
        foreground: colors.textSecondary,
        background: colors.surfaceTint,
      ),
    };

    return _PlainStatusChip(
      icon: presentation.icon,
      label: presentation.label,
      foreground: presentation.foreground,
      background: presentation.background,
    );
  }
}

class _PlainStatusChip extends StatelessWidget {
  const _PlainStatusChip({
    required this.icon,
    required this.label,
    this.foreground,
    this.background,
  });

  final IconData icon;
  final String label;
  final Color? foreground;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);
    final effectiveForeground = foreground ?? colors.textSecondary;
    final effectiveBackground = background ?? colors.surfaceTint;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: effectiveBackground,
        borderRadius: V2Radius.chip,
        border: Border.all(color: effectiveForeground.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: effectiveForeground),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: effectiveForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoProducts extends StatelessWidget {
  const _NoProducts();

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.inventory_2_outlined, color: colors.textSecondary),
        const SizedBox(width: V2Spacing.sm),
        Expanded(
          child: Text(
            '登録されたドリンク情報はまだありません。',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
        ),
      ],
    );
  }
}
