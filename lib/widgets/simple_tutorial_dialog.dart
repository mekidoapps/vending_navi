import 'package:flutter/material.dart';

class SimpleTutorialDialog extends StatefulWidget {
  const SimpleTutorialDialog({super.key});

  @override
  State<SimpleTutorialDialog> createState() => _SimpleTutorialDialogState();
}

class _SimpleTutorialDialogState extends State<SimpleTutorialDialog> {
  int _index = 0;

  static const List<_TutorialPageData> _pages = <_TutorialPageData>[
    _TutorialPageData(
      icon: Icons.search_rounded,
      title: '飲みたいドリンクを探す',
      message: '検索バーから、今飲みたいドリンクを探せます。',
    ),
    _TutorialPageData(
      icon: Icons.tune_rounded,
      title: '気分で絞り込む',
      message: '甘い・スッキリ・眠気覚ましなど、気分からも探せます。',
    ),
    _TutorialPageData(
      icon: Icons.add_location_alt_rounded,
      title: '見つけた自販機を登録',
      message: '見かけた自販機やドリンク情報を、あとから追加できます。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final _TutorialPageData page = _pages[_index];
    final bool isLast = _index == _pages.length - 1;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            page.icon,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            page.message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 18),
          Text(
            '${_index + 1} / ${_pages.length}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF60707A),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('スキップ'),
        ),
        FilledButton(
          onPressed: () {
            if (isLast) {
              Navigator.of(context).pop();
            } else {
              setState(() {
                _index += 1;
              });
            }
          },
          child: Text(isLast ? 'はじめる' : '次へ'),
        ),
      ],
    );
  }
}

class _TutorialPageData {
  const _TutorialPageData({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;
}
