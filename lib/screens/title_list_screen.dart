import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/title_provider.dart';
import '../repositories/title_repository.dart';
import '../widgets/common/empty_state_view.dart';
import '../widgets/common/loading_view.dart';

class TitleListScreen extends StatefulWidget {
  const TitleListScreen({super.key});

  @override
  State<TitleListScreen> createState() => _TitleListScreenState();
}

class _TitleListScreenState extends State<TitleListScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) return;
    _initialized = true;

    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<TitleProvider>().loadTitles(userId: user.uid);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TitleProvider>(
      builder: (BuildContext context, TitleProvider titleProvider, _) {
        final User? user = FirebaseAuth.instance.currentUser;

        return Scaffold(
          appBar: AppBar(
            title: const Text('称号一覧'),
          ),
          body: user == null
              ? const EmptyStateView(
            title: 'ログインが必要です',
            description: '称号を表示するにはログインしてください。',
            icon: Icons.workspace_premium_outlined,
          )
              : titleProvider.isLoading && titleProvider.titleMaster.isEmpty
              ? const LoadingView(message: '称号を読み込み中…')
              : _buildBody(context, titleProvider, user.uid),
        );
      },
    );
  }

  Widget _buildBody(
      BuildContext context,
      TitleProvider titleProvider,
      String userId,
      ) {
    final List<TitleMasterItem> titleMaster = titleProvider.titleMaster;

    if (titleMaster.isEmpty) {
      return const EmptyStateView(
        title: '称号がまだありません',
        description: '称号データが追加されるとここに表示されます。',
        icon: Icons.workspace_premium_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () => titleProvider.loadTitles(userId: userId),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: titleMaster.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (BuildContext context, int index) {
          final TitleMasterItem item = titleMaster[index];
          final bool hasTitle = titleProvider.hasTitle(item.id);

          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              leading: CircleAvatar(
                backgroundColor: hasTitle
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  hasTitle
                      ? Icons.workspace_premium_outlined
                      : Icons.lock_outline,
                ),
              ),
              title: Text(item.name),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.description),
                    const SizedBox(height: 6),
                    Text(
                      '条件: ${item.unlockType} / ${item.unlockThreshold}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              trailing: hasTitle
                  ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '獲得済み',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              )
                  : const Icon(Icons.chevron_right),
            ),
          );
        },
      ),
    );
  }
}