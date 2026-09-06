import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/firebase/firebase_providers.dart';

abstract final class UgcTermsGate {
  static const _version = '2026-09-06';

  static Future<bool> ensure(BuildContext context, WidgetRef ref) async {
    final functions = ref.read(cloudFunctionsProvider);
    try {
      final result = await functions.httpsCallable('getUgcTermsConsent').call<Map<Object?, Object?>>();
      if (result.data?['accepted'] == true) return true;
    } on FirebaseFunctionsException {
      if (context.mounted) _error(context);
      return false;
    }
    if (!context.mounted) return false;
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _TermsSheet(),
    );
    if (accepted != true || !context.mounted) return false;
    try {
      await functions.httpsCallable('acceptUgcTerms').call<Map<Object?, Object?>>(<String, Object?>{'version': _version});
      return true;
    } on FirebaseFunctionsException {
      if (context.mounted) _error(context);
      return false;
    }
  }

  static void _error(BuildContext context) => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('投稿ルールを確認できませんでした。時間をおいて再度お試しください。')),
  );
}

class _TermsSheet extends StatelessWidget {
  const _TermsSheet();
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text('投稿ルールの確認', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        const Text('自販機ナビでは、みんなが安心して使えるよう投稿ルールを設けています。'),
        const SizedBox(height: 12),
        const Text('虚偽情報、個人情報、危険・違法な内容、不適切な画像や文章、権利侵害、嫌がらせ、スパムは投稿しないでください。'),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => launchUrl(Uri.parse('https://vendingnavi.web.app/terms'), mode: LaunchMode.externalApplication),
          child: const Text('利用規約・投稿ルールを見る'),
        ),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('同意して続ける'))),
        Center(child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル'))),
      ]),
    ),
  );
}
