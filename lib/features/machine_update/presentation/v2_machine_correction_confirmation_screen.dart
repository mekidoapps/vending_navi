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
import '../../vending_machine/domain/entities/vending_machine_enums.dart';
import '../../vending_machine/domain/value_objects/geo_coordinate.dart';
import '../../vending_machine/domain/value_objects/vending_machine_id.dart';
import '../application/machine_correction_controller.dart';
import '../domain/models/machine_correction_draft.dart';

class V2MachineCorrectionConfirmationScreen extends ConsumerStatefulWidget {
  const V2MachineCorrectionConfirmationScreen({
    super.key,
    required this.machineId,
    required this.onCompleted,
  });

  final VendingMachineId machineId;
  final VoidCallback onCompleted;

  @override
  ConsumerState<V2MachineCorrectionConfirmationScreen> createState() =>
      _V2MachineCorrectionConfirmationScreenState();
}

class _V2MachineCorrectionConfirmationScreenState
    extends ConsumerState<V2MachineCorrectionConfirmationScreen> {
  late final TextEditingController _messageController;

  @override
  void initState() {
    super.initState();

    _messageController = TextEditingController(
      text: ref.read(machineCorrectionControllerProvider).draft?.message ?? '',
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final correctionState = ref.watch(machineCorrectionControllerProvider);
    final draft = correctionState.draft;

    if (draft == null ||
        draft.machineId != widget.machineId ||
        !draft.hasChanges) {
      return Theme(
        data: V2Theme.light(),
        child: Scaffold(
          appBar: AppBar(title: const Text('修正内容を確認')),
          body: const _MissingDraftBody(),
        ),
      );
    }

    final detail = ref.watch(vendingMachineDetailProvider(widget.machineId));

    return Theme(
      data: V2Theme.light(),
      child: Scaffold(
        appBar: AppBar(title: const Text('修正内容を確認')),
        body: SafeArea(
          child: detail.when(
            loading: () => const V2LoadingState(message: '現在の情報と比較しています'),
            error: (_, _) => V2ErrorState(
              title: '現在の情報を読み込めませんでした',
              message: '時間をおいて、もう一度お試しください。',
              onRetry: () {
                ref.invalidate(vendingMachineDetailProvider(widget.machineId));
              },
            ),
            data: (result) => result.fold(
              onSuccess: (data) => _ReviewBody(
                detail: data,
                draft: draft,
                isSubmitting: correctionState.isSubmitting,
                failureMessage: correctionState.failure?.userMessage,
                messageController: _messageController,
                onMessageChanged: _replaceMessage,
                onSubmit: _submit,
              ),
              onFailure: (failure) => V2ErrorState(
                title: failure.userTitle,
                message: failure.userMessage,
                onRetry: failure.isRetryable
                    ? () {
                        ref.invalidate(
                          vendingMachineDetailProvider(widget.machineId),
                        );
                      }
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _replaceMessage(String rawValue) {
    final currentDraft = ref.read(machineCorrectionControllerProvider).draft;
    if (currentDraft == null) {
      return;
    }

    final normalized = rawValue.trim();
    final nextMessage = normalized.isEmpty ? null : normalized;
    final currentMessage = currentDraft.message?.trim();

    if (nextMessage == currentMessage) {
      return;
    }

    ref
        .read(machineCorrectionControllerProvider.notifier)
        .replaceDraft(
          MachineCorrectionDraft(
            machineId: currentDraft.machineId,
            name: currentDraft.name,
            manufacturerId: currentDraft.manufacturerId,
            location: currentDraft.location,
            placeDescription: currentDraft.placeDescription,
            installationType: currentDraft.installationType,
            message: nextMessage,
          ),
        );
  }

  Future<void> _submit() async {
    final submitted = await ref
        .read(machineCorrectionControllerProvider.notifier)
        .submit();

    if (!mounted || !submitted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('修正提案を受け付けました。確認後に反映されます。')));

    widget.onCompleted();
  }
}

class _ReviewBody extends ConsumerWidget {
  const _ReviewBody({
    required this.detail,
    required this.draft,
    required this.isSubmitting,
    required this.failureMessage,
    required this.messageController,
    required this.onMessageChanged,
    required this.onSubmit,
  });

  final VendingMachineDetailData detail;
  final MachineCorrectionDraft draft;
  final bool isSubmitting;
  final String? failureMessage;
  final TextEditingController messageController;
  final ValueChanged<String> onMessageChanged;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <_ReviewItem>[];

    if (draft.name.isChanged) {
      items.add(
        _ReviewItem(
          keyName: 'name',
          label: '名前',
          before: detail.machine.name,
          after: draft.name.value ?? '',
        ),
      );
    }

    if (draft.manufacturerId.isChanged) {
      final proposedId = draft.manufacturerId.value;

      final proposedName = proposedId == null
          ? 'メーカー不明'
          : ref
                .watch(manufacturerDisplayNameProvider(proposedId))
                .when(
                  loading: () => proposedId.value,
                  error: (_, _) => proposedId.value,
                  data: (value) => value,
                );

      items.add(
        _ReviewItem(
          keyName: 'manufacturer',
          label: 'メーカー',
          before: detail.manufacturerName,
          after: proposedName,
        ),
      );
    }

    if (draft.location.isChanged && draft.location.value != null) {
      items.add(
        _ReviewItem(
          keyName: 'location',
          label: '位置',
          before: _formatLocation(detail.machine.location),
          after: _formatLocation(draft.location.value!),
        ),
      );
    }

    if (draft.placeDescription.isChanged) {
      items.add(
        _ReviewItem(
          keyName: 'placeDescription',
          label: '場所メモ',
          before: _optionalText(detail.machine.placeDescription),
          after: _optionalText(draft.placeDescription.value),
        ),
      );
    }

    if (draft.installationType.isChanged &&
        draft.installationType.value != null) {
      items.add(
        _ReviewItem(
          keyName: 'installationType',
          label: '設置場所',
          before: _installationLabel(detail.machine.installationType),
          after: _installationLabel(draft.installationType.value!),
        ),
      );
    }

    final colors = V2ColorTokens.of(context);

    return ListView(
      key: const Key('machineCorrectionConfirmationScreen'),
      padding: const EdgeInsets.all(V2Spacing.md),
      children: <Widget>[
        Text(
          '変更した項目だけを提案します',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: V2Spacing.xs),
        Text(
          '現在の公開情報は、この送信では直接変更されません。',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: V2Spacing.lg),
        for (final item in items) ...<Widget>[
          _ReviewItemCard(item: item),
          const SizedBox(height: V2Spacing.sm),
        ],
        const SizedBox(height: V2Spacing.sm),
        TextField(
          key: const Key('machineCorrectionMessageField'),
          controller: messageController,
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '補足（任意）',
            hintText: '確認する人に伝えたいことがあれば入力してください',
          ),
          onChanged: onMessageChanged,
        ),
        const SizedBox(height: V2Spacing.sm),
        DecoratedBox(
          key: const Key('machineCorrectionModerationNotice'),
          decoration: BoxDecoration(
            color: colors.surfaceTint,
            borderRadius: V2Radius.card,
          ),
          child: const Padding(
            padding: EdgeInsets.all(V2Spacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.schedule_outlined),
                SizedBox(width: V2Spacing.sm),
                Expanded(
                  child: Text('修正内容はすぐには反映されません。内容を確認したあとで公開情報へ反映されます。'),
                ),
              ],
            ),
          ),
        ),
        if (failureMessage != null) ...<Widget>[
          const SizedBox(height: V2Spacing.md),
          DecoratedBox(
            key: const Key('machineCorrectionSubmitFailure'),
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.12),
              borderRadius: V2Radius.control,
              border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(V2Spacing.md),
              child: Text(failureMessage!),
            ),
          ),
        ],
        const SizedBox(height: V2Spacing.lg),
        FilledButton.icon(
          key: const Key('submitMachineCorrectionButton'),
          onPressed: isSubmitting ? null : onSubmit,
          icon: isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: Text(isSubmitting ? '送信しています…' : '修正を提案する'),
        ),
        const SizedBox(height: V2Spacing.sm),
        Text(
          '戻ると修正内容を変更できます。',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }

  static String _formatLocation(GeoCoordinate value) {
    return '${value.latitude.toStringAsFixed(5)}, '
        '${value.longitude.toStringAsFixed(5)}';
  }

  static String _optionalText(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? '未登録' : normalized;
  }

  static String _installationLabel(InstallationType value) {
    return switch (value) {
      InstallationType.outdoor => '屋外',
      InstallationType.indoor => '屋内',
      InstallationType.unknown => '不明',
    };
  }
}

final class _ReviewItem {
  const _ReviewItem({
    required this.keyName,
    required this.label,
    required this.before,
    required this.after,
  });

  final String keyName;
  final String label;
  final String before;
  final String after;
}

class _ReviewItemCard extends StatelessWidget {
  const _ReviewItemCard({required this.item});

  final _ReviewItem item;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return DecoratedBox(
      key: Key('machineCorrectionReview_${item.keyName}'),
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
              item.label,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: V2Spacing.sm),
            Text(
              item.before,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: V2Spacing.xs),
              child: Icon(Icons.arrow_downward_rounded, size: 18),
            ),
            Text(
              item.after,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
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
      key: Key('missingMachineCorrectionDraft'),
      child: Padding(
        padding: EdgeInsets.all(V2Spacing.lg),
        child: Text(
          '確認できる修正内容がありません。\n前の画面から修正内容を選び直してください。',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
