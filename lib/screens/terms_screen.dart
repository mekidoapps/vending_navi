import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('利用規約'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            '自販機ナビ 利用規約',
            style: textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          _Section(
            title: '1. サービスについて',
            body:
            '本アプリは、飲みたいドリンクを買える自販機を探しやすくするための情報共有サービスです。'
                ' 投稿された情報には誤差や更新遅れが含まれる場合があります。',
          ),
          _Section(
            title: '2. 投稿情報について',
            body:
            'ユーザーが投稿する自販機情報、商品情報、価格、売り切れ情報などは、必ずしも最新・正確であることを保証するものではありません。'
                ' 実際の販売状況は現地でご確認ください。',
          ),
          _Section(
            title: '3. 禁止事項',
            body:
            '他人への迷惑行為、虚偽投稿、危険な場所への立ち入りを促す行為、第三者の権利を侵害する行為、法令や公序良俗に反する行為を禁止します。',
          ),
          _Section(
            title: '4. 安全について',
            body:
            '自販機を探す際は、交通ルールや施設ルールを守り、夜間や立入禁止エリアなど危険な場所での行動は避けてください。',
          ),
          _Section(
            title: '5. 免責',
            body:
            '本アプリ利用中に生じた損害、トラブル、事故について、運営は故意または重過失がない限り責任を負いません。',
          ),
          _Section(
            title: '6. 変更について',
            body:
            '本規約は必要に応じて改定される場合があります。重要な変更がある場合は、アプリ内で案内します。',
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;

  const _Section({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}