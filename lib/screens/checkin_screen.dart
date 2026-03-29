import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/enums/app_enums.dart';
import '../providers/auth_provider.dart';
import '../providers/checkin_provider.dart';

class CheckinScreen extends StatefulWidget {
  final String machineId;
  final String? productId;
  final String? machineName;

  const CheckinScreen({
    super.key,
    required this.machineId,
    this.productId,
    this.machineName,
  });

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  late final TextEditingController _priceController;
  late final TextEditingController _commentController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController();
    _commentController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) return;
    _initialized = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CheckinProvider>().initialize(
            machineId: widget.machineId,
            productId: widget.productId,
          );
    });
  }

  @override
  void dispose() {
    _priceController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit(CheckinProvider provider) async {
    // ✅ アクション未選択チェック
    if (provider.actionType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('内容を選択してください')),
      );
      return;
    }

    // ✅ 価格更新なのに未入力チェック
    if (provider.actionType == CheckinActionType.priceUpdate &&
        _priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('確認した価格を入力してください')),
      );
      return;
    }

    provider.setReportedPriceText(_priceController.text);
    provider.setComment(_commentController.text);

    // ✅ FirebaseAuth直参照をAuthProvider経由に変更
    final String? userId = context.read<AuthProvider>().currentUser?.uid;
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    final bool success = await provider.submit(userId: userId);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.successMessage ?? 'チェックインを保存しました'),
        ),
      );
      Navigator.of(context).pop(true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(provider.errorMessage ?? '保存に失敗しました'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CheckinProvider>(
      builder: (BuildContext context, CheckinProvider provider, _) {
        final CheckinActionType? actionType = provider.actionType;
        final bool showPriceInput = actionType == CheckinActionType.priceUpdate;

        return Scaffold(
          appBar: AppBar(
            title: const Text('チェックイン'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.machineName ?? '対象の自販機',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '現地で確認した内容を投稿します',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '内容を選択',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionChoiceChip(
                    label: '行った',
                    selected: actionType == CheckinActionType.visit,
                    onSelected: () =>
                        provider.setActionType(CheckinActionType.visit),
                  ),
                  _ActionChoiceChip(
                    label: 'あった',
                    selected: actionType == CheckinActionType.found,
                    onSelected: () =>
                        provider.setActionType(CheckinActionType.found),
                  ),
                  _ActionChoiceChip(
                    label: '売り切れ',
                    selected: actionType == CheckinActionType.soldOut,
                    onSelected: () =>
                        provider.setActionType(CheckinActionType.soldOut),
                  ),
                  _ActionChoiceChip(
                    label: '値段が違った',
                    selected: actionType == CheckinActionType.priceUpdate,
                    onSelected: () =>
                        provider.setActionType(CheckinActionType.priceUpdate),
                  ),
                  _ActionChoiceChip(
                    label: '写真更新',
                    selected: actionType == CheckinActionType.photoUpdate,
                    onSelected: () =>
                        provider.setActionType(CheckinActionType.photoUpdate),
                  ),
                ],
              ),
              if (showPriceInput) ...[
                const SizedBox(height: 20),
                TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '確認した価格',
                    hintText: '140',
                    prefixIcon: Icon(Icons.currency_yen),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              TextField(
                controller: _commentController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'コメント（任意）',
                  hintText: '例: 綾鷹はまだ売っていました',
                  prefixIcon: Icon(Icons.comment_outlined),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                // ✅ アクション未選択または送信中は無効化
                onPressed: provider.isSubmitting || provider.actionType == null
                    ? null
                    : () => _submit(provider),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: provider.isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('送信する'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _ActionChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
