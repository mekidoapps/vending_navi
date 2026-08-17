import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class V2MachinePhotoUpdateReviewScreen extends ConsumerWidget {
  const V2MachinePhotoUpdateReviewScreen({super.key, required this.machineId});

  final VendingMachineId machineId;

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
              onSuccess: (data) =>
                  _ReviewBody(photoState: photoState, detail: data),
              onFailure: (failure) => V2ErrorState(
                title: failure.userTitle,
                message: failure.userMessage,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({required this.photoState, required this.detail});

  final MachinePhotoUpdateState photoState;
  final VendingMachineDetailData detail;

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
        ),
        const SizedBox(height: V2Spacing.lg),
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
      ],
    );
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
