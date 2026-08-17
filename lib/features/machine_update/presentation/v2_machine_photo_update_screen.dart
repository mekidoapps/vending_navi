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
import 'v2_machine_product_picker.dart';

class V2MachinePhotoUpdateScreen extends ConsumerWidget {
  const V2MachinePhotoUpdateScreen({
    super.key,
    required this.machineId,
    this.onReviewPressed,
  });

  final VendingMachineId machineId;
  final VoidCallback? onReviewPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machinePhotoUpdateControllerProvider);
    final controller = ref.read(machinePhotoUpdateControllerProvider.notifier);

    return Theme(
      data: V2Theme.light(),
      child: Scaffold(
        appBar: AppBar(title: const Text('写真から商品情報を更新')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(V2Spacing.md),
            children: <Widget>[
              Text(
                '今の自販機を撮影してください',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: V2Spacing.xs),
              Text(
                '写真から商品候補を探します。AIの結果だけでは自動更新しません。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: V2Spacing.lg),
              const _PhotoGuideCard(),
              const SizedBox(height: V2Spacing.lg),
              if (state.previewBytes != null) ...<Widget>[
                ClipRRect(
                  borderRadius: V2Radius.card,
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.memory(
                      state.previewBytes!,
                      key: const Key('machinePhotoUpdatePreview'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: V2Spacing.lg),
              ],
              if (state.stage ==
                  MachinePhotoUpdateStage.recognizing) ...<Widget>[
                const _RecognitionProgressCard(),
                const SizedBox(height: V2Spacing.md),
              ],
              if (state.failureMessage != null) ...<Widget>[
                _FailureCard(
                  message: state.failureMessage!,
                  canRetryRecognition: state.canRetryRecognition,
                  onRetryRecognition: controller.reanalyze,
                ),
                const SizedBox(height: V2Spacing.md),
              ],
              if (state.stage == MachinePhotoUpdateStage.ready) ...<Widget>[
                _ReadySection(
                  machineId: machineId,
                  state: state,
                  onReviewPressed: onReviewPressed,
                ),
                const SizedBox(height: V2Spacing.md),
              ],
              FilledButton.icon(
                key: const Key('machinePhotoUpdateCaptureButton'),
                onPressed: state.isBusy
                    ? null
                    : () async {
                        await controller.captureAndRecognize();
                      },
                icon: state.isBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_camera_outlined),
                label: Text(_captureButtonLabel(state.stage)),
              ),
              const SizedBox(height: V2Spacing.xs),
              Text(
                '撮影した写真は、商品候補の確認と自販機写真の追加に使用します。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _captureButtonLabel(MachinePhotoUpdateStage stage) {
    return switch (stage) {
      MachinePhotoUpdateStage.capturing => 'カメラを開いています…',
      MachinePhotoUpdateStage.normalizing => '写真を整えています…',
      MachinePhotoUpdateStage.uploading => '写真を送信しています…',
      MachinePhotoUpdateStage.recognizing => '商品候補を探しています…',
      MachinePhotoUpdateStage.ready => '撮り直す',
      MachinePhotoUpdateStage.failed => '別の写真を撮る',
      MachinePhotoUpdateStage.idle => 'カメラで撮影',
    };
  }
}

class _ReadySection extends ConsumerWidget {
  const _ReadySection({
    required this.machineId,
    required this.state,
    required this.onReviewPressed,
  });

  final VendingMachineId machineId;
  final MachinePhotoUpdateState state;
  final VoidCallback? onReviewPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(vendingMachineDetailProvider(machineId));

    return detail.when(
      loading: () => const V2LoadingState(message: '現在の商品情報と照合しています'),
      error: (_, _) => V2ErrorState(
        title: '現在の商品情報を読み込めませんでした',
        message: '時間をおいて、もう一度お試しください。',
        onRetry: () {
          ref.invalidate(vendingMachineDetailProvider(machineId));
        },
      ),
      data: (result) {
        return result.fold(
          onSuccess: (data) => _buildReady(context, ref, data),
          onFailure: (failure) => V2ErrorState(
            title: failure.userTitle,
            message: failure.userMessage,
            onRetry: failure.isRetryable
                ? () {
                    ref.invalidate(vendingMachineDetailProvider(machineId));
                  }
                : null,
          ),
        );
      },
    );
  }

  Widget _buildReady(
    BuildContext context,
    WidgetRef ref,
    VendingMachineDetailData data,
  ) {
    final plan = MachinePhotoProductUpdatePlanner.build(
      currentProducts: data.products,
      productMaster: state.products,
      aiProductCandidateIds: state.aiProductCandidateIds.toSet(),
      selectedProductIds: state.selectedProductIds,
    );

    final aiProducts = state.products
        .where(
          (product) => state.aiProductCandidateIds.contains(product.id.value),
        )
        .toList(growable: false);

    final manuallySelected = state.products
        .where(
          (product) =>
              state.selectedProductIds.contains(product.id.value) &&
              !state.aiProductCandidateIds.contains(product.id.value),
        )
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'AI候補を確認',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: V2Spacing.xs),
        const Text('実際に置いてある商品だけを選んでください。'),
        const SizedBox(height: V2Spacing.sm),
        _SafetyNotice(),
        const SizedBox(height: V2Spacing.md),
        if (aiProducts.isEmpty)
          const _EmptyAiCandidates()
        else
          Card(
            margin: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(borderRadius: V2Radius.card),
            child: Column(
              children: <Widget>[
                for (final product in aiProducts)
                  CheckboxListTile(
                    key: Key('photoCandidate_${product.id.value}'),
                    value: state.selectedProductIds.contains(product.id.value),
                    title: Text(product.name),
                    subtitle: const Text('AI候補'),
                    onChanged: (selected) {
                      final working = <String>{...state.selectedProductIds};

                      if (selected == true) {
                        working.add(product.id.value);
                      } else {
                        working.remove(product.id.value);
                      }

                      ref
                          .read(machinePhotoUpdateControllerProvider.notifier)
                          .replaceSelectedProducts(working);
                    },
                  ),
              ],
            ),
          ),
        if (manuallySelected.isNotEmpty) ...<Widget>[
          const SizedBox(height: V2Spacing.md),
          Text(
            '手動で追加した商品',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: V2Spacing.sm),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (final product in manuallySelected)
                  ListTile(
                    key: Key('photoManualSelected_${product.id.value}'),
                    title: Text(product.name),
                    subtitle: const Text('実物を見て手動で追加'),
                    trailing: IconButton(
                      tooltip: '選択から外す',
                      onPressed: () {
                        final working = <String>{...state.selectedProductIds}
                          ..remove(product.id.value);

                        ref
                            .read(machinePhotoUpdateControllerProvider.notifier)
                            .replaceSelectedProducts(working);
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: V2Spacing.md),
        OutlinedButton.icon(
          key: const Key('photoUpdateAddProductButton'),
          onPressed: () => _addProduct(context, ref),
          icon: const Icon(Icons.add_rounded),
          label: const Text('AI候補にない商品を追加'),
        ),
        const SizedBox(height: V2Spacing.lg),
        _PlanSummary(plan: plan),
        if (state.unresolvedLabels.isNotEmpty) ...<Widget>[
          const SizedBox(height: V2Spacing.md),
          _UnresolvedLabels(labels: state.unresolvedLabels),
        ],
        const SizedBox(height: V2Spacing.lg),
        FilledButton(
          key: const Key('photoUpdateReviewButton'),
          onPressed: state.uploadId == null || onReviewPressed == null
              ? null
              : onReviewPressed,
          child: const Text('変更内容を確認'),
        ),
      ],
    );
  }

  Future<void> _addProduct(BuildContext context, WidgetRef ref) async {
    final product = await V2MachineProductPicker.show(
      context,
      existingProductIds: state.selectedProductIds,
    );

    if (product == null || !context.mounted) {
      return;
    }

    ref
        .read(machinePhotoUpdateControllerProvider.notifier)
        .replaceSelectedProducts(<String>{
          ...state.selectedProductIds,
          product.id.value,
        });
  }
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.plan});

  final MachinePhotoProductUpdatePlan plan;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: V2Radius.card),
      child: Padding(
        padding: const EdgeInsets.all(V2Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '選択した商品の反映内容',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: V2Spacing.sm),
            if (plan.items.isEmpty)
              const Text('反映する商品は選択されていません。')
            else
              for (final item in plan.items)
                ListTile(
                  key: Key('photoPlan_${item.productId}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.productName),
                  subtitle: Text(_actionLabel(item.action)),
                  trailing: item.changesPublicData
                      ? const Icon(Icons.arrow_forward_rounded)
                      : const Icon(Icons.check_rounded),
                ),
          ],
        ),
      ),
    );
  }

  static String _actionLabel(MachinePhotoProductUpdateAction action) {
    return switch (action) {
      MachinePhotoProductUpdateAction.alreadyConfirmed => 'すでに確認済み・商品情報の変更なし',
      MachinePhotoProductUpdateAction.confirmInferred => '置いてあることを確認済みに変更',
      MachinePhotoProductUpdateAction.addPhotoConfirmed => '写真で確認した商品として追加',
      MachinePhotoProductUpdateAction.addManualConfirmed => '手動で確認した商品として追加',
    };
  }
}

class _SafetyNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return Container(
      key: const Key('photoAbsenceSafetyNotice'),
      padding: const EdgeInsets.all(V2Spacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceTint,
        borderRadius: V2Radius.card,
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline),
          SizedBox(width: V2Spacing.sm),
          Expanded(child: Text('写真に写らなかった既存商品は、この更新では削除・非表示にしません。')),
        ],
      ),
    );
  }
}

class _UnresolvedLabels extends StatelessWidget {
  const _UnresolvedLabels({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(V2Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '商品マスタに安全に結び付けられなかった表示',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: V2Spacing.sm),
            Wrap(
              spacing: V2Spacing.xs,
              runSpacing: V2Spacing.xs,
              children: <Widget>[
                for (final label in labels) Chip(label: Text(label)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAiCandidates extends StatelessWidget {
  const _EmptyAiCandidates();

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(V2Spacing.md),
        child: Text('商品マスタに一致するAI候補はありませんでした。必要なら商品を手動で追加できます。'),
      ),
    );
  }
}

class _PhotoGuideCard extends StatelessWidget {
  const _PhotoGuideCard();

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return Container(
      padding: const EdgeInsets.all(V2Spacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: V2Radius.card,
        border: Border.all(color: colors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.center_focus_strong_outlined),
              SizedBox(width: V2Spacing.xs),
              Text('撮影のコツ', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          SizedBox(height: V2Spacing.md),
          Text('・自販機の正面から、全体が入るように撮る'),
          SizedBox(height: V2Spacing.xs),
          Text('・商品名が見える距離で撮る'),
          SizedBox(height: V2Spacing.xs),
          Text('・人の顔や車のナンバーが映り込まないようにする'),
          SizedBox(height: V2Spacing.xs),
          Text('・危険な場所や私有地には入らない'),
        ],
      ),
    );
  }
}

class _RecognitionProgressCard extends StatelessWidget {
  const _RecognitionProgressCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(V2Spacing.md),
        child: Row(
          children: <Widget>[
            SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: V2Spacing.md),
            Expanded(child: Text('写真から商品候補を探しています…')),
          ],
        ),
      ),
    );
  }
}

class _FailureCard extends StatelessWidget {
  const _FailureCard({
    required this.message,
    required this.canRetryRecognition,
    required this.onRetryRecognition,
  });

  final String message;
  final bool canRetryRecognition;
  final Future<bool> Function() onRetryRecognition;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(V2Spacing.md),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: V2Radius.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.error_outline, color: colors.onErrorContainer),
              const SizedBox(width: V2Spacing.xs),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: colors.onErrorContainer),
                ),
              ),
            ],
          ),
          if (canRetryRecognition) ...<Widget>[
            const SizedBox(height: V2Spacing.md),
            OutlinedButton(
              key: const Key('machinePhotoUpdateRetryRecognitionButton'),
              onPressed: () async {
                await onRetryRecognition();
              },
              child: const Text('同じ写真でもう一度認識'),
            ),
          ],
        ],
      ),
    );
  }
}
