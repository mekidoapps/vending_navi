import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/v2_color_tokens.dart';
import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../../app/theme/v2_theme.dart';
import '../../../core/ui/states/v2_error_state.dart';
import '../../../core/ui/states/v2_loading_state.dart';
import '../../vending_machine/application/models/vending_machine_detail_data.dart';
import '../../vending_machine/application/providers/vending_machine_detail_providers.dart';
import '../../vending_machine/domain/value_objects/vending_machine_id.dart';
import '../application/machine_photo_product_update_plan.dart';
import '../application/machine_photo_update_controller.dart';
import '../application/machine_photo_update_state.dart';
import '../application/machine_photo_update_submit_controller.dart';
import '../application/machine_photo_update_submit_state.dart';
import '../../ugc_terms/presentation/ugc_terms_gate.dart';

class V2MachinePhotoUpdateReviewScreen extends ConsumerWidget {
  const V2MachinePhotoUpdateReviewScreen({
    super.key,
    required this.machineId,
    required this.onCompleted,
  });

  final VendingMachineId machineId;
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoState = ref.watch(machinePhotoUpdateControllerProvider);

    if (photoState.stage != MachinePhotoUpdateStage.ready ||
        photoState.uploadId == null) {
      return const Scaffold(
        body: SafeArea(
          child: V2ErrorState(
            title: '更新内容を表示できません',
            message: '写真候補の確認からやり直してください。',
          ),
        ),
      );
    }

    final detail = ref.watch(vendingMachineDetailProvider(machineId));

    final submitState = ref.watch(machinePhotoUpdateSubmitControllerProvider);

    return Theme(
      data: V2Theme.light(),
      child: Scaffold(
        appBar: AppBar(title: const Text('更新内容の確認')),
        body: SafeArea(
          child: detail.when(
            loading: () => const V2LoadingState(message: '更新内容を確認しています'),
            error: (_, _) => V2ErrorState(
              title: '更新内容を読み込めませんでした',
              message: '時間をおいて、もう一度お試しください。',
              onRetry: () {
                ref.invalidate(vendingMachineDetailProvider(machineId));
              },
            ),
            data: (result) => result.fold(
              onSuccess: (data) => _ReviewBody(
                photoState: photoState,
                detail: data,
                submitState: submitState,
                onSubmit: () => _submit(context, ref, photoState, data),
              ),
              onFailure: (failure) => V2ErrorState(
                title: failure.userTitle,
                message: failure.userMessage,
                onRetry: failure.isRetryable
                    ? () {
                        ref.invalidate(vendingMachineDetailProvider(machineId));
                      }
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    MachinePhotoUpdateState photoState,
    VendingMachineDetailData detail,
  ) async {
    final uploadId = photoState.uploadId;

    if (uploadId == null) {
      return;
    }

    if (!await UgcTermsGate.ensure(context, ref)) return;

    final plan = MachinePhotoProductUpdatePlanner.build(
      currentProducts: detail.products,
      productMaster: photoState.products,
      aiProductCandidateIds: photoState.aiProductCandidateIds.toSet(),
      selectedProductIds: photoState.selectedProductIds,
    );

    final draft = plan.toDraft(
      machineId: machineId,
      temporaryPhotoUploadId: uploadId,
    );

    final completed = await ref
        .read(machinePhotoUpdateSubmitControllerProvider.notifier)
        .submit(draft);

    if (!context.mounted || !completed) {
      return;
    }

    ref.invalidate(vendingMachineDetailProvider(machineId));

    ref.read(machinePhotoUpdateControllerProvider.notifier).reset();

    ref.read(machinePhotoUpdateSubmitControllerProvider.notifier).reset();

    onCompleted();
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({
    required this.photoState,
    required this.detail,
    required this.submitState,
    required this.onSubmit,
  });

  final MachinePhotoUpdateState photoState;
  final VendingMachineDetailData detail;
  final MachinePhotoUpdateSubmitState submitState;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final plan = MachinePhotoProductUpdatePlanner.build(
      currentProducts: detail.products,
      productMaster: photoState.products,
      aiProductCandidateIds: photoState.aiProductCandidateIds.toSet(),
      selectedProductIds: photoState.selectedProductIds,
    );

    return ListView(
      key: const Key('machinePhotoUpdateReviewScreen'),
      padding: const EdgeInsets.all(V2Spacing.md),
      children: <Widget>[
        if (photoState.previewBytes != null) ...<Widget>[
          ClipRRect(
            borderRadius: V2Radius.card,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.memory(
                photoState.previewBytes!,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: V2Spacing.lg),
        ],
        Text(
          detail.machine.name,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: V2Spacing.xs),
        Text(
          plan.hasProductChanges
              ? '${plan.changedProductCount}件の商品情報を変更し、写真を追加します。'
              : '商品情報は変更せず、写真だけを追加します。',
          key: const Key('photoUpdateReviewSummary'),
        ),
        const SizedBox(height: V2Spacing.lg),
        if (plan.items.isEmpty)
          const Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.all(V2Spacing.md),
              child: Text('商品情報の変更はありません。'),
            ),
          )
        else
          for (final item in plan.items) ...<Widget>[
            Card(
              key: Key('photoReview_${item.productId}'),
              margin: EdgeInsets.zero,
              child: ListTile(
                title: Text(item.productName),
                subtitle: Text(_label(item.action)),
                trailing: item.changesPublicData
                    ? const Icon(Icons.arrow_forward_rounded)
                    : const Icon(Icons.check_rounded),
              ),
            ),
            const SizedBox(height: V2Spacing.sm),
          ],
        const SizedBox(height: V2Spacing.sm),
        Card(
          margin: EdgeInsets.zero,
          child: const Padding(
            padding: EdgeInsets.all(V2Spacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.photo_outlined),
                SizedBox(width: V2Spacing.sm),
                Expanded(child: Text('撮影した写真を、この自販機の写真として追加します。')),
              ],
            ),
          ),
        ),
        const SizedBox(height: V2Spacing.md),
        const Text('写真に写らなかった既存商品は変更しません。', textAlign: TextAlign.center),
        if (submitState.failure != null) ...<Widget>[
          const SizedBox(height: V2Spacing.lg),
          _SubmitFailureCard(message: submitState.failure!.userMessage),
        ],
        const SizedBox(height: V2Spacing.lg),
        FilledButton.icon(
          key: const Key('submitMachinePhotoUpdateButton'),
          onPressed: submitState.isSubmitting ? null : onSubmit,
          icon: submitState.isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_upload_outlined),
          label: Text(_submitButtonLabel(submitState.stage)),
        ),
        const SizedBox(height: V2Spacing.sm),
        Text(
          submitState.productCompleted && !submitState.photoCompleted
              ? '商品情報の更新は完了しています。写真の保存だけを再試行します。'
              : '戻ると選択内容を修正できます。',
          key: const Key('photoUpdateSubmitHint'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  static String _submitButtonLabel(MachinePhotoUpdateSubmitStage stage) {
    return switch (stage) {
      MachinePhotoUpdateSubmitStage.updatingProducts => '商品情報を更新しています…',
      MachinePhotoUpdateSubmitStage.finalizingPhoto => '写真を保存しています…',
      MachinePhotoUpdateSubmitStage.completed => '更新が完了しました',
      MachinePhotoUpdateSubmitStage.idle => 'この内容で更新',
    };
  }

  static String _label(MachinePhotoProductUpdateAction action) {
    return switch (action) {
      MachinePhotoProductUpdateAction.alreadyConfirmed => 'すでに確認済み・変更なし',
      MachinePhotoProductUpdateAction.confirmInferred => '確認済みに変更',
      MachinePhotoProductUpdateAction.addPhotoConfirmed => '写真で確認した商品として追加',
      MachinePhotoProductUpdateAction.addManualConfirmed => '手動で確認した商品として追加',
    };
  }
}

class _SubmitFailureCard extends StatelessWidget {
  const _SubmitFailureCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return DecoratedBox(
      key: const Key('machinePhotoUpdateSubmitFailure'),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.12),
        borderRadius: V2Radius.control,
        border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(V2Spacing.md),
        child: Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
        ),
      ),
    );
  }
}
