import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route.dart';
import '../application/machine_registration_controller.dart';
import '../application/manufacturer_selection_controller.dart';
import '../application/registration_duplicate_candidates_controller.dart';
import '../application/registration_photo_controller.dart';
import '../application/registration_photo_recognition_controller.dart';

abstract final class V2RegistrationHomeAction {
  static List<Widget> appBarActions(BuildContext context, WidgetRef ref) {
    final registration = ref.watch(machineRegistrationControllerProvider);
    final photo = ref.watch(registrationPhotoControllerProvider);
    final enabled = !registration.isSubmitting && !photo.isBusy;

    return <Widget>[
      IconButton(
        key: const Key('registrationHomeButton'),
        tooltip: enabled ? 'ホームへ戻る' : '処理が終わるまでお待ちください',
        onPressed: enabled ? () => returnHome(context, ref) : null,
        icon: const Icon(Icons.home_outlined),
      ),
    ];
  }

  static Future<void> returnHome(BuildContext context, WidgetRef ref) async {
    final hasDraft = ref.read(machineRegistrationControllerProvider).draft.hasUserInput;
    if (hasDraft) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('登録を中止してホームへ戻りますか？'),
          content: const Text('入力した登録内容は保存されません。'),
          actions: <Widget>[
            TextButton(
              key: const Key('registrationHomeContinueButton'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('登録を続ける'),
            ),
            FilledButton(
              key: const Key('registrationHomeDiscardButton'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('登録を中止してホームへ戻る'),
            ),
          ],
        ),
      );
      if (discard != true || !context.mounted) {
        return;
      }
    }

    ref.read(machineRegistrationControllerProvider.notifier).reset();
    ref.read(registrationDuplicateCandidatesControllerProvider.notifier).reset();
    ref.read(manufacturerSelectionControllerProvider.notifier).reset();
    ref.read(registrationPhotoControllerProvider.notifier).reset();
    ref.read(registrationPhotoRecognitionControllerProvider.notifier).reset();

    if (context.mounted) {
      context.goNamed(AppRoute.v2Foundation.name);
    }
  }
}
