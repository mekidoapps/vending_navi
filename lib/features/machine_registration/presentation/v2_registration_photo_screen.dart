import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_spacing.dart';
import '../application/machine_registration_controller.dart';
import '../application/registration_photo_controller.dart';
import '../application/registration_photo_state.dart';
import '../domain/services/registration_photo_exception.dart';
import 'v2_registration_auth_gate.dart';
import 'v2_registration_home_action.dart';

final registrationCameraSettingsProvider = Provider<Future<bool> Function()>(
  (_) => Geolocator.openAppSettings,
);

class V2RegistrationPhotoScreen extends ConsumerStatefulWidget {
  const V2RegistrationPhotoScreen({super.key, this.onPhotoPrepared});

  final VoidCallback? onPhotoPrepared;

  @override
  ConsumerState<V2RegistrationPhotoScreen> createState() =>
      _V2RegistrationPhotoScreenState();
}

class _V2RegistrationPhotoScreenState
    extends ConsumerState<V2RegistrationPhotoScreen> {
  bool _capturePending = false;

  Future<void> _requestCapture() async {
    if (_capturePending ||
        ref.read(registrationPhotoControllerProvider).isBusy) {
      return;
    }
    setState(() => _capturePending = true);
    try {
      var decisionMade = false;
      final agreed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          void decide(bool agreed) {
            if (decisionMade) return;
            decisionMade = true;
            Navigator.pop(dialogContext, agreed);
          }

          return AlertDialog(
            title: const Text('写真の送信と画像認識について'),
            content: const SingleChildScrollView(
              child: Text(
                '撮影した写真は、GoogleのFirebase Storageにアップロードされ、'
                'サーバーを通じてGoogle CloudのVertex AIへ送信されます。'
                '自販機の商品・メーカー候補を画像認識で見つけるために使います。\n\n'
                '同意して進むとカメラが開き、撮影した写真が送信されます。'
                '人の顔や個人情報が写らないようにしてください。'
                '認識結果は確認・修正でき、正式登録は別の確認で行います。'
                'キャンセルすると撮影・送信は行いません。',
              ),
            ),
            actions: [
              TextButton(
                key: const Key('registrationPhotoConsentCancel'),
                onPressed: () => decide(false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                key: const Key('registrationPhotoConsentAgree'),
                onPressed: () => decide(true),
                child: const Text('同意して進む'),
              ),
            ],
          );
        },
      );
      if (agreed != true || !mounted) return;
      bool canContinue() =>
          mounted && ModalRoute.of(context)?.isCurrent == true;
      String? uploadId;
      await V2RegistrationAuthGate.run(
        context,
        ref,
        actionLabel: '写真からの自販機登録',
        action: () async {
          if (!canContinue()) return;
          uploadId = await ref
              .read(registrationPhotoControllerProvider.notifier)
              .captureNormalizeAndUpload(canContinue: canContinue);
        },
      );
      final preparedUploadId = uploadId;
      if (preparedUploadId == null || !canContinue()) return;
      ref
          .read(machineRegistrationControllerProvider.notifier)
          .setTemporaryPhotoUploadId(preparedUploadId);
      widget.onPhotoPrepared?.call();
    } finally {
      if (mounted) setState(() => _capturePending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoState = ref.watch(registrationPhotoControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('写真から登録'),
        actions: V2RegistrationHomeAction.appBarActions(context, ref),
      ),
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
              if (photoState.failureCode ==
                  RegistrationPhotoErrorCode.cameraPermissionDenied)
                TextButton.icon(
                  key: const Key('registrationCameraSettingsButton'),
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('端末の設定を開く'),
                  onPressed: () async {
                    var opened = false;
                    try {
                      opened = await ref.read(
                        registrationCameraSettingsProvider,
                      )();
                    } catch (_) {
                      /* Keep settings errors separate from a new capture. */
                    }
                    if (!opened && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '設定を開けませんでした。端末の設定アプリからカメラの許可をご確認ください。',
                          ),
                        ),
                      );
                    }
                  },
                ),
              const SizedBox(height: V2Spacing.md),
            ],
            FilledButton.icon(
              key: const Key('registrationPhotoCaptureButton'),
              onPressed: photoState.isBusy || _capturePending
                  ? null
                  : _requestCapture,
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
