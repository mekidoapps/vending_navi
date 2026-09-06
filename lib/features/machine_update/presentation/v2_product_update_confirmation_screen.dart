import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/v2_color_tokens.dart';
import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../../app/theme/v2_theme.dart';
import '../../vending_machine/domain/value_objects/vending_machine_id.dart';
import '../application/machine_product_update_controller.dart';
import '../application/machine_product_update_review.dart';
import '../../ugc_terms/presentation/ugc_terms_gate.dart';

class V2ProductUpdateConfirmationScreen extends ConsumerStatefulWidget {
  const V2ProductUpdateConfirmationScreen({
    super.key,
    required this.machineId,
    required this.onCompleted,
  });

  final VendingMachineId machineId;
  final VoidCallback onCompleted;

  @override
  ConsumerState<V2ProductUpdateConfirmationScreen> createState() =>
      _V2ProductUpdateConfirmationScreenState();
}

class _V2ProductUpdateConfirmationScreenState
    extends ConsumerState<V2ProductUpdateConfirmationScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(machineProductUpdateControllerProvider);

    final draft = state.draft;

    return Theme(
      data: V2Theme.light(),
      child: Scaffold(
        appBar: AppBar(title: const Text('変更内容を確認')),
        body:
            draft == null ||
                draft.machineId != widget.machineId ||
                draft.operations.isEmpty
            ? const _MissingDraftBody()
            : _ReviewBody(
                items: buildMachineProductUpdateReviewItems(draft),
                isSubmitting: state.isSubmitting,
                failureMessage: state.failure?.userMessage,
                onSubmit: _submit,
              ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!await UgcTermsGate.ensure(context, ref)) return;
    final submitted = await ref
        .read(machineProductUpdateControllerProvider.notifier)
        .submit();

    if (!mounted || !submitted) {
      return;
    }

    widget.onCompleted();
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({
    required this.items,
    required this.isSubmitting,
    required this.failureMessage,
    required this.onSubmit,
  });

  final List<MachineProductUpdateReviewItem> items;
  final bool isSubmitting;
  final String? failureMessage;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return ListView(
      key: const Key('productUpdateConfirmationScreen'),
      padding: const EdgeInsets.all(V2Spacing.md),
      children: <Widget>[
        Text(
          '以下の内容で更新します',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: V2Spacing.xs),
        Text(
          '内容に間違いがないか確認してください。',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: V2Spacing.lg),
        for (final item in items) ...<Widget>[
          _ReviewItemCard(item: item),
          const SizedBox(height: V2Spacing.sm),
        ],
        if (failureMessage != null) ...<Widget>[
          const SizedBox(height: V2Spacing.sm),
          DecoratedBox(
            key: const Key('productUpdateSubmitFailure'),
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.12),
              borderRadius: V2Radius.control,
              border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(V2Spacing.md),
              child: Text(
                failureMessage!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
              ),
            ),
          ),
        ],
        const SizedBox(height: V2Spacing.lg),
        FilledButton.icon(
          key: const Key('submitMachineProductUpdateButton'),
          onPressed: isSubmitting ? null : onSubmit,
          icon: isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_upload_outlined),
          label: Text(isSubmitting ? '更新しています…' : 'この内容で更新'),
        ),
        const SizedBox(height: V2Spacing.sm),
        Text(
          '戻ると変更内容を修正できます。',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

class _ReviewItemCard extends StatelessWidget {
  const _ReviewItemCard({required this.item});

  final MachineProductUpdateReviewItem item;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return DecoratedBox(
      key: Key('productUpdateReview_${item.productId}'),
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
              item.productName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: V2Spacing.sm),
            for (final change in item.changes)
              Padding(
                padding: const EdgeInsets.only(bottom: V2Spacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18,
                      color: colors.primaryStrong,
                    ),
                    const SizedBox(width: V2Spacing.xs),
                    Expanded(
                      child: Text(
                        change,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textPrimary,
                        ),
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

class _MissingDraftBody extends StatelessWidget {
  const _MissingDraftBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('missingProductUpdateDraft'),
      child: Padding(
        padding: EdgeInsets.all(V2Spacing.lg),
        child: Text(
          '確認できる変更内容がありません。\n前の画面から変更内容を選び直してください。',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
