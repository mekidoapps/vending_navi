import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_spacing.dart';
import '../application/machine_registration_controller.dart';
import '../application/registration_photo_controller.dart';
import '../application/registration_photo_state.dart';

class V2RegistrationPhotoScreen extends ConsumerWidget {
  const V2RegistrationPhotoScreen({super.key, this.onPhotoPrepared});

  final VoidCallback? onPhotoPrepared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoState = ref.watch(registrationPhotoControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('写真から登録')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(V2Spacing.lg),
          children: <Widget>[
            Text(
              '自販機全体を1枚に収めてください',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: V2Spacing.xs),
            Text(
              '商品が見えるように正面から撮影すると、候補を見つけやすくなります。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: V2Spacing.lg),
            const _PhotoGuideCard(),
            const SizedBox(height: V2Spacing.lg),
            if (photoState.previewBytes != null) ...<Widget>[
              ClipRRect(
                borderRadius: V2Radius.card,
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.memory(
                    photoState.previewBytes!,
                    key: const Key('registrationPhotoPreview'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: V2Spacing.lg),
            ],
            if (photoState.failureMessage != null) ...<Widget>[
              _FailureCard(message: photoState.failureMessage!),
              const SizedBox(height: V2Spacing.md),
            ],
            FilledButton.icon(
              key: const Key('registrationPhotoCaptureButton'),
              onPressed: photoState.isBusy
                  ? null
                  : () async {
                      final uploadId = await ref
                          .read(registrationPhotoControllerProvider.notifier)
                          .captureNormalizeAndUpload();
                      if (uploadId == null || !context.mounted) {
                        return;
                      }

                      ref
                          .read(machineRegistrationControllerProvider.notifier)
                          .setTemporaryPhotoUploadId(uploadId);

                      onPhotoPrepared?.call();
                    },
              icon: photoState.isBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_camera_outlined),
              label: Text(_buttonLabel(photoState.stage)),
            ),
            const SizedBox(height: V2Spacing.xs),
            Text(
              '撮影した写真は登録候補の確認に使います。候補はこのあと確認・修正できます。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  static String _buttonLabel(RegistrationPhotoStage stage) {
    return switch (stage) {
      RegistrationPhotoStage.capturing => 'カメラを開いています…',
      RegistrationPhotoStage.normalizing => '写真を整えています…',
      RegistrationPhotoStage.uploading => '写真を送信しています…',
      RegistrationPhotoStage.ready => '撮り直す',
      RegistrationPhotoStage.failed => 'もう一度撮影',
      RegistrationPhotoStage.idle => 'カメラで撮影',
    };
  }
}

class _PhotoGuideCard extends StatelessWidget {
  const _PhotoGuideCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: V2Radius.card),
      child: Padding(
        padding: const EdgeInsets.all(V2Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.center_focus_strong_outlined,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: V2Spacing.xs),
                Text(
                  '撮影のコツ',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: V2Spacing.md),
            const Text('・自販機の正面から、全体が入るように撮る'),
            const SizedBox(height: V2Spacing.xs),
            const Text('・商品名が見える距離で撮る'),
            const SizedBox(height: V2Spacing.xs),
            const Text('・人の顔や車のナンバーが映り込まないようにする'),
            const SizedBox(height: V2Spacing.xs),
            const Text('・危険な場所や私有地には入らない'),
          ],
        ),
      ),
    );
  }
}

class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(V2Spacing.md),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: V2Radius.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: V2Spacing.xs),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
