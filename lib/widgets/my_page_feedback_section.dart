import 'package:flutter/material.dart';

import '../screens/feedback/feedback_form_screen.dart';

class MyPageFeedbackSection extends StatelessWidget {
  const MyPageFeedbackSection({
    super.key,
    this.initialScreenName = 'my_page',
  });

  final String initialScreenName;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: Theme.of(context).dividerColor.withOpacity(0.25),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('フィードバック送信'),
            subtitle: const Text('不具合・要望・使いにくかった点を送る'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final submitted = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => FeedbackFormScreen(
                    initialScreenName: initialScreenName,
                  ),
                ),
              );

              if (!context.mounted) return;

              if (submitted == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('フィードバックを受け付けました。'),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}