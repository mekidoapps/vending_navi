import 'package:flutter/material.dart';

import '../data/seed/product_master_data.dart';
import '../services/firestore_service.dart';

/// 開発用：Firestoreにシードデータを投入する画面
/// 本番リリース前に削除すること
class DevSeedScreen extends StatefulWidget {
  const DevSeedScreen({super.key});

  @override
  State<DevSeedScreen> createState() => _DevSeedScreenState();
}

class _DevSeedScreenState extends State<DevSeedScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  bool _isLoading = false;
  String _log = '';
  int _successCount = 0;
  int _failCount = 0;

  Future<void> _seedProductMaster() async {
    setState(() {
      _isLoading = true;
      _log = '';
      _successCount = 0;
      _failCount = 0;
    });

    final products = ProductMasterData.items;

    for (final item in products) {
      try {
        await _firestoreService
            .productMaster()
            .doc(item.product.id)
            .set(item.product.toMap());

        setState(() {
          _successCount++;
          _log += '✅ ${item.product.displayName}\n';
        });
      } catch (e) {
        setState(() {
          _failCount++;
          _log += '❌ ${item.product.displayName}: $e\n';
        });
      }
    }

    setState(() => _isLoading = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('完了：成功 $_successCount件 / 失敗 $_failCount件'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛠 開発用：シードデータ投入'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '⚠️ この画面は開発専用です。本番リリース前に削除してください。',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '投入対象：product_master（${ProductMasterData.items.length}件）',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isLoading ? null : _seedProductMaster,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_rounded),
              label: Text(_isLoading
                  ? '投入中… $_successCount / ${ProductMasterData.items.length}'
                  : 'product_masterを投入する'),
            ),
            if (_log.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '成功: $_successCount件 / 失敗: $_failCount件',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _log,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
