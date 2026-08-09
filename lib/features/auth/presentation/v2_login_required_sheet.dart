import 'package:flutter/material.dart';

import '../../../app/theme/v2_color_tokens.dart';
import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../../core/ui/buttons/v2_primary_button.dart';

abstract final class V2LoginRequiredSheet {
  static Future<bool> show(
    BuildContext context, {
    required String actionLabel,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _LoginRequiredSheetBody(actionLabel: actionLabel);
      },
    );

    return result ?? false;
  }
}

final class _LoginRequiredSheetBody extends StatelessWidget {
  const _LoginRequiredSheetBody({required this.actionLabel});

  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(V2Radius.popupValue),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          V2Spacing.lg,
          V2Spacing.lg,
          V2Spacing.lg,
          V2Spacing.xl,
        ),
        child: Column(
          key: const Key('loginRequiredSheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(bottom: V2Spacing.lg),
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: V2Radius.chip,
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.lock_outline_rounded, color: colors.primaryStrong),
                const SizedBox(width: V2Spacing.sm),
                Expanded(
                  child: Text(
                    'この操作はログインが必要です',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: V2Spacing.md),
            Text(
              '$actionLabelにはログインが必要です。'
              '地図の閲覧や検索はログインしなくても利用できます。',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: V2Spacing.lg),
            V2PrimaryButton(
              key: const Key('loginRequiredContinue'),
              label: 'ログイン / 新規登録',
              icon: Icons.login_rounded,
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
            const SizedBox(height: V2Spacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                key: const Key('loginRequiredCancel'),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: const Text('今はしない'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
