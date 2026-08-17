import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/v2_color_tokens.dart';
import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../../app/theme/v2_theme.dart';
import '../../product_master/domain/entities/product.dart';
import '../../vending_machine/domain/value_objects/vending_machine_id.dart';
import '../application/machine_photo_update_controller.dart';
import '../application/machine_photo_update_state.dart';

class V2MachinePhotoUpdateScreen extends ConsumerWidget {
  const V2MachinePhotoUpdateScreen({super.key, required this.machineId});

  final VendingMachineId machineId;

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
                '写真から商品候補を探します。AIの結果だけで自動更新はせず、このあと内容を確認します。',
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
                _RecognitionReadyCard(state: state),
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

class _RecognitionReadyCard extends StatelessWidget {
  const _RecognitionReadyCard({required this.state});

  final MachinePhotoUpdateState state;

  @override
  Widget build(BuildContext context) {
    final candidateProducts = _candidateProducts(state);

    return Card(
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: V2Radius.card),
      child: Padding(
        padding: const EdgeInsets.all(V2Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.auto_awesome_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: V2Spacing.xs),
                Text(
                  'AI候補を取得しました',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: V2Spacing.xs),
            const Text('まだ自販機の公開情報は変更していません。'),
            const SizedBox(height: V2Spacing.md),
            if (candidateProducts.isEmpty)
              const Text('商品マスタに一致する候補はありませんでした。')
            else
              for (final product in candidateProducts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.local_drink_outlined),
                  title: Text(product.name),
                  trailing: const Chip(label: Text('AI候補')),
                ),
            if (state.unresolvedLabels.isNotEmpty) ...<Widget>[
              const SizedBox(height: V2Spacing.sm),
              Text(
                '商品マスタに安全に結び付けられなかった表示',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: V2Spacing.xs),
              Wrap(
                spacing: V2Spacing.xs,
                runSpacing: V2Spacing.xs,
                children: <Widget>[
                  for (final label in state.unresolvedLabels)
                    Chip(label: Text(label)),
                ],
              ),
            ],
            const SizedBox(height: V2Spacing.md),
            Text(
              '次の工程で、現在の商品情報と見比べながら追加・変更する内容を確認します。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  static List<Product> _candidateProducts(MachinePhotoUpdateState state) {
    final ids = state.aiProductCandidateIds.toSet();

    return state.products
        .where((product) => ids.contains(product.id.value))
        .toList(growable: false);
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
