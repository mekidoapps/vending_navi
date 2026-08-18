import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/v2_color_tokens.dart';
import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../../app/theme/v2_theme.dart';
import '../../vending_machine/domain/value_objects/vending_machine_id.dart';
import '../application/machine_report_controller.dart';
import '../domain/models/machine_report_category.dart';
import '../domain/models/machine_report_draft.dart';

class V2MachineReportConfirmationScreen extends ConsumerStatefulWidget {
  const V2MachineReportConfirmationScreen({
    super.key,
    required this.machineId,
    required this.onCompleted,
  });

  final VendingMachineId machineId;
  final VoidCallback onCompleted;

  @override
  ConsumerState<V2MachineReportConfirmationScreen> createState() =>
      _V2MachineReportConfirmationScreenState();
}

class _V2MachineReportConfirmationScreenState
    extends ConsumerState<V2MachineReportConfirmationScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(machineReportControllerProvider);
    final draft = state.draft;

    return Theme(
      data: V2Theme.light(),
      child: Scaffold(
        appBar: AppBar(title: const Text('報告内容を確認')),
        body: SafeArea(
          child: draft == null || draft.machineId != widget.machineId
              ? const _MissingDraftBody()
              : _ReportReviewBody(
                  draft: draft,
                  isSubmitting: state.isSubmitting,
                  failureMessage: state.failure?.userMessage,
                  onSubmit: _submit,
                ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final submitted = await ref
        .read(machineReportControllerProvider.notifier)
        .submit();

    if (!mounted || !submitted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('報告を受け付けました。')));

    widget.onCompleted();
  }
}

class _ReportReviewBody extends StatelessWidget {
  const _ReportReviewBody({
    required this.draft,
    required this.isSubmitting,
    required this.failureMessage,
    required this.onSubmit,
  });

  final MachineReportDraft draft;
  final bool isSubmitting;
  final String? failureMessage;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return ListView(
      key: const Key('machineReportConfirmationScreen'),
      padding: const EdgeInsets.all(V2Spacing.md),
      children: <Widget>[
        Text(
          'この内容で報告します',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: V2Spacing.lg),
        _ReviewCard(label: '問題の種類', value: _categoryLabel(draft.category)),
        if (draft.photoId != null) ...<Widget>[
          const SizedBox(height: V2Spacing.sm),
          const _ReviewCard(label: '対象', value: 'この自販機の写真'),
        ],
        const SizedBox(height: V2Spacing.sm),
        _ReviewCard(label: '補足', value: _optionalText(draft.message)),
        const SizedBox(height: V2Spacing.lg),
        DecoratedBox(
          key: const Key('machineReportModerationNotice'),
          decoration: BoxDecoration(
            color: colors.surfaceTint,
            borderRadius: V2Radius.card,
          ),
          child: const Padding(
            padding: EdgeInsets.all(V2Spacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.info_outline_rounded),
                SizedBox(width: V2Spacing.sm),
                Expanded(
                  child: Text(
                    '報告を送信しても、この自販機が自動的に削除・非表示になることはありません。'
                    '内容を確認したうえで必要な対応を行います。',
                  ),
                ),
              ],
            ),
          ),
        ),
        if (failureMessage != null) ...<Widget>[
          const SizedBox(height: V2Spacing.md),
          DecoratedBox(
            key: const Key('machineReportSubmitFailure'),
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
          key: const Key('submitMachineReportButton'),
          onPressed: isSubmitting ? null : onSubmit,
          icon: isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.flag_outlined),
          label: Text(isSubmitting ? '送信しています…' : '報告する'),
        ),
      ],
    );
  }

  static String _optionalText(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? 'なし' : normalized;
  }

  static String _categoryLabel(MachineReportCategory value) {
    return switch (value) {
      MachineReportCategory.machineRemoved => '自販機が撤去されている',
      MachineReportCategory.duplicate => '同じ自販機が重複して登録されている',
      MachineReportCategory.inaccessible => '利用できない・立ち入れない',
      MachineReportCategory.inappropriatePhoto => '不適切な写真がある',
      MachineReportCategory.inappropriateText => '不適切な文章がある',
      MachineReportCategory.other => 'その他',
    };
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.label, required this.value});

  final String label;
  final String value;

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
              label,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: V2Spacing.xs),
            Text(value),
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
      key: Key('missingMachineReportDraft'),
      child: Padding(
        padding: EdgeInsets.all(V2Spacing.lg),
        child: Text(
          '確認できる報告内容がありません。\n前の画面から報告内容を選び直してください。',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
