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

class V2MachineReportScreen extends ConsumerStatefulWidget {
  const V2MachineReportScreen({
    super.key,
    required this.machineId,
    this.photoId,
    this.onReviewPressed,
  });

  final VendingMachineId machineId;

  /// 写真単体から報告する場合に指定する正式photoId。
  /// 通常の自販機報告ではnull。
  final String? photoId;

  final VoidCallback? onReviewPressed;

  @override
  ConsumerState<V2MachineReportScreen> createState() =>
      _V2MachineReportScreenState();
}

class _V2MachineReportScreenState extends ConsumerState<V2MachineReportScreen> {
  final _messageController = TextEditingController();

  MachineReportCategory? _selectedCategory;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return Theme(
      data: V2Theme.light(),
      child: Scaffold(
        appBar: AppBar(title: const Text('問題を報告')),
        body: SafeArea(
          child: ListView(
            key: const Key('machineReportScreen'),
            padding: const EdgeInsets.all(V2Spacing.md),
            children: <Widget>[
              Text(
                '問題の種類を選んでください',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: V2Spacing.xs),
              Text(
                '確認できた内容に一番近いものを選んでください。',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: V2Spacing.lg),
              for (final category in MachineReportCategory.values) ...<Widget>[
                _CategoryCard(
                  category: category,
                  selected: _selectedCategory == category,
                  onSelected: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                ),
                const SizedBox(height: V2Spacing.sm),
              ],
              const SizedBox(height: V2Spacing.sm),
              TextField(
                key: const Key('machineReportMessageField'),
                controller: _messageController,
                maxLength: 500,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '補足（任意）',
                  hintText: '状況や確認したことを入力してください',
                ),
              ),
              if (widget.photoId != null) ...<Widget>[
                const SizedBox(height: V2Spacing.sm),
                DecoratedBox(
                  key: const Key('machineReportPhotoTargetNotice'),
                  decoration: BoxDecoration(
                    color: colors.surfaceTint,
                    borderRadius: V2Radius.card,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(V2Spacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(Icons.photo_outlined),
                        SizedBox(width: V2Spacing.sm),
                        Expanded(child: Text('この自販機の写真を対象にした報告として送信します。')),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: V2Spacing.lg),
              FilledButton.icon(
                key: const Key('machineReportReviewButton'),
                onPressed: widget.onReviewPressed == null ? null : _review,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('報告内容を確認'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _review() {
    final category = _selectedCategory;

    if (category == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('問題の種類を選んでください。')));
      return;
    }

    final normalizedMessage = _messageController.text.trim();

    ref
        .read(machineReportControllerProvider.notifier)
        .begin(
          MachineReportDraft(
            machineId: widget.machineId,
            photoId: widget.photoId,
            category: category,
            message: normalizedMessage.isEmpty ? null : normalizedMessage,
          ),
        );

    widget.onReviewPressed?.call();
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.selected,
    required this.onSelected,
  });

  final MachineReportCategory category;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return Material(
      color: selected ? colors.surfaceTint : colors.surfaceElevated,
      borderRadius: V2Radius.card,
      child: InkWell(
        key: Key('machineReportCategory_${category.name}'),
        borderRadius: V2Radius.card,
        onTap: onSelected,
        child: Container(
          padding: const EdgeInsets.all(V2Spacing.md),
          decoration: BoxDecoration(
            borderRadius: V2Radius.card,
            border: Border.all(
              color: selected ? colors.primaryStrong : colors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? colors.primaryStrong : colors.textSecondary,
              ),
              const SizedBox(width: V2Spacing.md),
              Expanded(
                child: Text(
                  _categoryLabel(category),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
