import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/v2_color_tokens.dart';
import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../../app/theme/v2_theme.dart';
import '../../../core/ui/states/v2_error_state.dart';
import '../../../core/ui/states/v2_loading_state.dart';
import '../../product_master/domain/entities/product.dart';
import '../../vending_machine/application/models/vending_machine_detail_data.dart';
import '../../vending_machine/application/providers/vending_machine_detail_providers.dart';
import '../../vending_machine/domain/entities/vending_machine_enums.dart';
import '../../vending_machine/domain/value_objects/vending_machine_id.dart';
import '../application/machine_product_update_controller.dart';
import '../application/machine_product_update_edit_session.dart';
import '../domain/models/machine_product_update_draft.dart';
import 'v2_machine_product_picker.dart';

class V2ManualProductUpdateScreen extends ConsumerStatefulWidget {
  const V2ManualProductUpdateScreen({
    super.key,
    required this.machineId,
    this.onReviewPressed,
  });

  final VendingMachineId machineId;
  final VoidCallback? onReviewPressed;

  @override
  ConsumerState<V2ManualProductUpdateScreen> createState() =>
      _V2ManualProductUpdateScreenState();
}

class _V2ManualProductUpdateScreenState
    extends ConsumerState<V2ManualProductUpdateScreen> {
  MachineProductUpdateEditSession? _editSession;
  final Map<String, Product> _addedProducts = <String, Product>{};
  final Map<String, String> _productNames = <String, String>{};

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      ref
          .read(machineProductUpdateControllerProvider.notifier)
          .begin(
            MachineProductUpdateDraft(
              machineId: widget.machineId,
              operations: const [],
            ),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(vendingMachineDetailProvider(widget.machineId));

    return Theme(
      data: V2Theme.light(),
      child: Scaffold(
        appBar: AppBar(title: const Text('商品情報を更新')),
        body: detail.when(
          loading: () => const V2LoadingState(message: '現在の商品情報を読み込んでいます'),
          error: (_, _) => V2ErrorState(
            title: '商品情報を読み込めませんでした',
            message: '時間をおいて、もう一度お試しください。',
            onRetry: () {
              ref.invalidate(vendingMachineDetailProvider(widget.machineId));
            },
          ),
          data: (result) {
            return result.fold(
              onSuccess: _buildContent,
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(VendingMachineDetailData data) {
    _ensureEditSession(data);

    final colors = V2ColorTokens.of(context);
    final session = _editSession!;

    return ListView(
      key: const Key('manualProductUpdateScreen'),
      padding: const EdgeInsets.all(V2Spacing.md),
      children: <Widget>[
        Text(
          data.machine.name,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: V2Spacing.xs),
        Text(
          '実際に確認できた商品の状態を反映してください。',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: V2Spacing.md),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('addMachineProductButton'),
            onPressed: () => _addProduct(data),
            icon: const Icon(Icons.add_rounded),
            label: const Text('商品を追加'),
          ),
        ),
        const SizedBox(height: V2Spacing.lg),
        Text(
          '現在の商品',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: V2Spacing.sm),
        if (data.products.isEmpty && _addedProducts.isEmpty)
          const _EmptyProducts()
        else ...<Widget>[
          for (final item in data.products) ...<Widget>[
            _ProductEditCard(
              key: Key('manualProductCurrent_${item.productId.value}'),
              productId: item.productId.value,
              productName: item.productName,
              originalEvidence: item.evidenceType,
              effectiveAvailability: session.effectiveAvailability(
                item.productId.value,
              ),
              effectivelyConfirmed: session.isEffectivelyConfirmed(
                item.productId.value,
              ),
              isOriginallyInferred: item.evidenceType?.isInferred ?? false,
              isDeactivated: session.isDeactivated(item.productId.value),
              pendingLabel: session.pendingLabel(item.productId.value),
              onConfirmInferred: () {
                _confirmInferred(item.productId.value);
              },
              onToggleSoldOut: () {
                _toggleSoldOut(item.productId.value);
              },
              onDeactivate: () {
                _deactivate(item.productId.value);
              },
              onCancel: session.hasPendingChange(item.productId.value)
                  ? () {
                      _cancelChanges(item.productId.value);
                    }
                  : null,
            ),
            const SizedBox(height: V2Spacing.sm),
          ],
          for (final product in _addedProducts.values)
            Padding(
              padding: const EdgeInsets.only(bottom: V2Spacing.sm),
              child: _ProductEditCard(
                key: Key('manualProductAdded_${product.id.value}'),
                productId: product.id.value,
                productName: product.name,
                originalEvidence: null,
                effectiveAvailability: session.effectiveAvailability(
                  product.id.value,
                ),
                effectivelyConfirmed: true,
                isOriginallyInferred: false,
                isDeactivated: false,
                isNewlyAdded: true,
                pendingLabel: session.pendingLabel(product.id.value),
                onConfirmInferred: null,
                onToggleSoldOut: () {
                  _toggleSoldOut(product.id.value);
                },
                onDeactivate: null,
                onCancel: () {
                  _cancelChanges(product.id.value);
                },
              ),
            ),
        ],
        const SizedBox(height: V2Spacing.md),
        _ChangeSummaryCard(
          changedProductCount: session.changedProductIds.length,
          onReviewPressed: session.hasChanges && widget.onReviewPressed != null
              ? widget.onReviewPressed
              : null,
        ),
      ],
    );
  }

  void _ensureEditSession(VendingMachineDetailData data) {
    if (_editSession != null) {
      return;
    }

    for (final item in data.products) {
      _productNames[item.productId.value] = item.productName;
    }

    _editSession = MachineProductUpdateEditSession(
      currentProducts: data.products.map(
        (item) => MachineProductUpdateOriginalState(
          productId: item.productId.value,
          evidenceType: item.evidenceType,
          availability: item.availability,
        ),
      ),
    );
  }

  Future<void> _addProduct(VendingMachineDetailData data) async {
    final session = _editSession;
    if (session == null) {
      return;
    }

    final existingProductIds = <String>{
      for (final item in data.products) item.productId.value,
      ..._addedProducts.keys,
    };

    final product = await V2MachineProductPicker.show(
      context,
      existingProductIds: existingProductIds,
    );

    if (!mounted || product == null) {
      return;
    }

    if (!session.addConfirmed(product.id.value)) {
      return;
    }

    setState(() {
      _addedProducts[product.id.value] = product;
      _productNames[product.id.value] = product.name;
    });

    _syncDraft();
  }

  void _confirmInferred(String productId) {
    final session = _editSession;
    if (session == null || !session.confirmInferred(productId)) {
      return;
    }

    setState(() {});
    _syncDraft();
  }

  void _toggleSoldOut(String productId) {
    final session = _editSession;
    if (session == null) {
      return;
    }

    final current = session.effectiveAvailability(productId);

    final changed = session.setSoldOut(
      productId,
      soldOut: current != ProductAvailability.soldOut,
    );

    if (!changed) {
      return;
    }

    setState(() {});
    _syncDraft();
  }

  void _deactivate(String productId) {
    final session = _editSession;
    if (session == null || !session.deactivate(productId)) {
      return;
    }

    setState(() {});
    _syncDraft();
  }

  void _cancelChanges(String productId) {
    final session = _editSession;
    if (session == null) {
      return;
    }

    session.cancelChanges(productId);

    setState(() {
      _addedProducts.remove(productId);
    });

    _syncDraft();
  }

  void _syncDraft() {
    final session = _editSession;
    if (session == null) {
      return;
    }

    ref
        .read(machineProductUpdateControllerProvider.notifier)
        .replaceDraft(
          MachineProductUpdateDraft(
            machineId: widget.machineId,
            operations: session.operations,
            productNames: _productNames,
          ),
        );
  }
}

class _ProductEditCard extends StatelessWidget {
  const _ProductEditCard({
    super.key,
    required this.productId,
    required this.productName,
    required this.originalEvidence,
    required this.effectiveAvailability,
    required this.effectivelyConfirmed,
    required this.isOriginallyInferred,
    required this.isDeactivated,
    required this.pendingLabel,
    required this.onConfirmInferred,
    required this.onToggleSoldOut,
    required this.onDeactivate,
    required this.onCancel,
    this.isNewlyAdded = false,
  });

  final String productId;
  final String productName;
  final ProductEvidenceType? originalEvidence;
  final ProductAvailability effectiveAvailability;
  final bool effectivelyConfirmed;
  final bool isOriginallyInferred;
  final bool isDeactivated;
  final bool isNewlyAdded;
  final String? pendingLabel;
  final VoidCallback? onConfirmInferred;
  final VoidCallback? onToggleSoldOut;
  final VoidCallback? onDeactivate;
  final VoidCallback? onCancel;

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
              productName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: V2Spacing.xs),
            Text(
              _currentStatusLabel(),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            if (pendingLabel != null) ...<Widget>[
              const SizedBox(height: V2Spacing.sm),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceTint,
                  borderRadius: V2Radius.chip,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  child: Text(
                    pendingLabel!,
                    key: Key('pendingProductUpdate_$productId'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: V2Spacing.md),
            if (!isDeactivated)
              Wrap(
                spacing: V2Spacing.sm,
                runSpacing: V2Spacing.sm,
                children: <Widget>[
                  if (isOriginallyInferred &&
                      !effectivelyConfirmed &&
                      onConfirmInferred != null)
                    OutlinedButton(
                      key: Key('confirmInferred_$productId'),
                      onPressed: onConfirmInferred,
                      child: const Text('置いてあった'),
                    ),
                  if (effectivelyConfirmed && onToggleSoldOut != null)
                    OutlinedButton(
                      key: Key('toggleSoldOut_$productId'),
                      onPressed: onToggleSoldOut,
                      child: Text(
                        effectiveAvailability == ProductAvailability.soldOut
                            ? '販売している'
                            : '売り切れ',
                      ),
                    ),
                  if (!isNewlyAdded && onDeactivate != null)
                    TextButton(
                      key: Key('deactivateProduct_$productId'),
                      onPressed: onDeactivate,
                      child: const Text('なくなった'),
                    ),
                ],
              ),
            if (onCancel != null) ...<Widget>[
              const SizedBox(height: V2Spacing.sm),
              TextButton.icon(
                key: Key('cancelProductUpdate_$productId'),
                onPressed: onCancel,
                icon: const Icon(Icons.undo_rounded),
                label: const Text('変更を取り消す'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _currentStatusLabel() {
    if (isDeactivated) {
      return '現在の登録から外す予定です';
    }

    final evidence = isNewlyAdded
        ? '追加'
        : effectivelyConfirmed
        ? '確認済み'
        : switch (originalEvidence) {
            ProductEvidenceType.manufacturerInferred => '推定',
            ProductEvidenceType.manualConfirmed => '確認済み',
            ProductEvidenceType.photoConfirmed => '写真で確認済み',
            null => '旧データ',
          };

    final availability = switch (effectiveAvailability) {
      ProductAvailability.available => '販売中',
      ProductAvailability.soldOut => '売り切れ',
      ProductAvailability.unknown => '在庫不明',
    };

    return '$evidence・$availability';
  }
}

class _ChangeSummaryCard extends StatelessWidget {
  const _ChangeSummaryCard({
    required this.changedProductCount,
    required this.onReviewPressed,
  });

  final int changedProductCount;
  final VoidCallback? onReviewPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(V2Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              changedProductCount == 0
                  ? '変更はありません'
                  : '$changedProductCount件の商品を変更します',
              key: const Key('machineProductChangeSummary'),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: V2Spacing.md),
            FilledButton.icon(
              key: const Key('reviewMachineProductChangesButton'),
              onPressed: onReviewPressed,
              icon: const Icon(Icons.checklist_rounded),
              label: const Text('変更内容を確認'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: V2Spacing.lg),
      child: Center(child: Text('現在、商品情報は登録されていません')),
    );
  }
}
