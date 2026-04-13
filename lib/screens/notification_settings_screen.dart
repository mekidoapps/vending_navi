import 'package:flutter/material.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _favoriteDrinkNearby = false;
  bool _checkedMachineUpdated = false;
  bool _appNews = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('お知らせ / 通知'),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFE3E7EB),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '通知設定',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '今後の近所通知や更新通知の入口です。まずは画面だけ先に用意しています。',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('お気に入りドリンク近所通知'),
                    subtitle: const Text('近くで見つかった時に知らせる'),
                    value: _favoriteDrinkNearby,
                    onChanged: (value) {
                      setState(() {
                        _favoriteDrinkNearby = value;
                      });
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('チェックインした自販機更新通知'),
                    subtitle: const Text('登録内容の更新を知らせる'),
                    value: _checkedMachineUpdated,
                    onChanged: (value) {
                      setState(() {
                        _checkedMachineUpdated = value;
                      });
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('アプリからのお知らせ'),
                    subtitle: const Text('新機能やお知らせを表示'),
                    value: _appNews,
                    onChanged: (value) {
                      setState(() {
                        _appNews = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FBFC),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFE3E7EB),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'メモ',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '・通知の実配信処理は次段階で接続します。\n'
                        '・今はオンオフのUIと導線を先に用意しています。',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: Color(0xFF60707A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}