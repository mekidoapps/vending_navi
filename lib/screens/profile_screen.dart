import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/common/empty_state_view.dart';
import '../widgets/common/loading_view.dart';
import 'auth_gate.dart';
import 'dev_seed_screen.dart';
import 'terms_screen.dart';
import 'title_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) return;
    _initialized = true;

    final authProvider = context.read<AuthProvider>();
    final String? userId = authProvider.currentUser?.uid;
    if (userId != null) {
      final String displayName =
          authProvider.currentUser?.displayName?.trim().isNotEmpty == true
              ? authProvider.currentUser!.displayName!.trim()
              : authProvider.currentUser?.email?.split('@').first ?? 'ユーザー';
      final String? photoUrl = authProvider.currentUser?.photoURL;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ProfileProvider>().loadProfile(
          userId,
          displayName: displayName,
          photoUrl: photoUrl,
        );
      });
    }
  }

  Future<void> _confirmLogout() async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ログアウトしますか？'),
          content: const Text('現在のアカウントからログアウトします。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('ログアウト'),
            ),
          ],
        );
      },
    );

    if (result != true || !mounted) return;

    final AuthProvider authProvider = context.read<AuthProvider>();
    final bool success = await authProvider.signOut();

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const AuthGate(),
        ),
        (_) => false,
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(authProvider.errorMessage ?? 'ログアウトに失敗しました'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (BuildContext context, ProfileProvider profileProvider, _) {
        final String? userId = context.watch<AuthProvider>().currentUser?.uid;

        return Scaffold(
          appBar: AppBar(
            title: const Text('マイページ'),
          ),
          body: userId == null
              ? const EmptyStateView(
                  title: 'ログインが必要です',
                  description: 'プロフィールを表示するにはログインしてください。',
                  icon: Icons.person_off_outlined,
                )
              : profileProvider.isLoading && profileProvider.userStats == null
                  ? const LoadingView(
                      message: 'プロフィールを読み込み中…',
                    )
                  : RefreshIndicator(
                      onRefresh: () {
                        final auth = context.read<AuthProvider>();
                        final String dn =
                            auth.currentUser?.displayName?.trim().isNotEmpty == true
                                ? auth.currentUser!.displayName!.trim()
                                : auth.currentUser?.email?.split('@').first ?? 'ユーザー';
                        return profileProvider.refresh(
                          userId,
                          displayName: dn,
                          photoUrl: auth.currentUser?.photoURL,
                        );
                      },
                      child: _buildBody(context, profileProvider, userId),
                    ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    ProfileProvider profileProvider,
    String userId,
  ) {
    final userStats = profileProvider.userStats;

    if (userStats == null) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          EmptyStateView(
            title: 'プロフィール情報がありません',
            description: 'アカウント情報の読み込み後に表示されます。',
            icon: Icons.account_circle_outlined,
          ),
        ],
      );
    }

    final String displayName =
        context.read<AuthProvider>().currentUser?.displayName?.trim().isNotEmpty == true
            ? context.read<AuthProvider>().currentUser!.displayName!.trim()
            : userStats.displayName;
    final String? photoUrl =
        context.read<AuthProvider>().currentUser?.photoURL ?? userStats.photoUrl;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _ProfileHeader(
          displayName: displayName,
          photoUrl: photoUrl,
          currentTitle: userStats.currentTitleId ?? '未設定',
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: '実績',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: 'チェックイン',
                      value: '${userStats.checkinCount}',
                      icon: Icons.location_on_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      label: '登録自販機',
                      value: '${userStats.machineCreatedCount}',
                      icon: Icons.local_drink_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: '貢献スコア',
                      value: '${userStats.contributionScore}',
                      icon: Icons.workspace_premium_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      label: 'お気に入り',
                      value: '${userStats.favoriteTotalCount}',
                      icon: Icons.favorite_border,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'お気に入り内訳',
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.local_cafe_outlined,
                label: '商品お気に入り',
                value: '${userStats.favoriteProductCount}件',
              ),
              const Divider(height: 20),
              _InfoRow(
                icon: Icons.pin_drop_outlined,
                label: '自販機お気に入り',
                value: '${userStats.favoriteMachineCount}件',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'メニュー',
          child: Column(
            children: [
              _MenuTile(
                icon: Icons.workspace_premium_outlined,
                title: '称号一覧',
                subtitle: '獲得した称号を確認',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TitleListScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              _MenuTile(
                icon: Icons.description_outlined,
                title: '利用規約',
                subtitle: 'アプリの利用条件を確認',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TermsScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              // 🛠 開発用：本番リリース前に削除
              _MenuTile(
                icon: Icons.developer_mode,
                title: '🛠 シードデータ投入',
                subtitle: '開発用：本番前に削除',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DevSeedScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              _MenuTile(
                icon: Icons.logout,
                title: 'ログアウト',
                subtitle: '現在のアカウントからログアウト',
                titleColor: Theme.of(context).colorScheme.error,
                onTap: _confirmLogout,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String? photoUrl;
  final String currentTitle;

  const _ProfileHeader({
    required this.displayName,
    required this.photoUrl,
    required this.currentTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                  ? NetworkImage(photoUrl!)
                  : null,
              child: (photoUrl == null || photoUrl!.isEmpty)
                  ? const Icon(Icons.person, size: 30)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '現在の称号: $currentTitle',
                      style: Theme.of(context).textTheme.bodySmall,
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

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? titleColor;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(
        title,
        style: TextStyle(color: titleColor),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
