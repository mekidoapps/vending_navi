import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route.dart';
import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../favorite_products/application/favorite_products_controller.dart';
import '../../favorite_products/presentation/v2_favorite_products_card.dart';
import '../application/v2_my_page_controller.dart';
import '../application/v2_my_page_state.dart';

class V2MyPageScreen extends ConsumerStatefulWidget {
  const V2MyPageScreen({super.key, this.enableFavoriteProducts = false});

  final bool enableFavoriteProducts;

  @override
  ConsumerState<V2MyPageScreen> createState() => _V2MyPageScreenState();
}

class _V2MyPageScreenState extends ConsumerState<V2MyPageScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _refreshAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(v2MyPageControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('マイページ')),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              V2Spacing.md,
              V2Spacing.md,
              V2Spacing.md,
              V2Spacing.xl,
            ),
            children: <Widget>[
              if (state.failure != null) ...<Widget>[
                _FailureCard(
                  state: state,
                  onDismiss: () {
                    ref
                        .read(v2MyPageControllerProvider.notifier)
                        .clearFailure();
                  },
                ),
                const SizedBox(height: V2Spacing.md),
              ],
              if (state.isAuthenticated)
                _AuthenticatedMyPage(
                  state: state,
                  onEditDisplayName: _editDisplayName,
                  onSignOut: _confirmSignOut,
                  enableFavoriteProducts: widget.enableFavoriteProducts,
                )
              else
                _GuestMyPage(onLogin: _openAuthentication),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshAll() async {
    await ref.read(v2MyPageControllerProvider.notifier).refresh();

    if (!mounted || !widget.enableFavoriteProducts) {
      return;
    }

    await ref.read(favoriteProductsControllerProvider.notifier).refresh();
  }

  Future<void> _openAuthentication() async {
    await context.pushNamed<bool>(AppRoute.v2EmailAuth.name);

    if (!mounted) {
      return;
    }

    await _refreshAll();
  }

  Future<void> _editDisplayName() async {
    final state = ref.read(v2MyPageControllerProvider);
    if (!state.isAuthenticated || state.isSavingDisplayName) {
      return;
    }

    var editedDisplayName = state.editableDisplayName;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('表示名を変更'),
          content: TextFormField(
            key: const Key('myPageDisplayNameField'),
            initialValue: editedDisplayName,
            autofocus: true,
            maxLength: V2MyPageController.maxDisplayNameLength,
            decoration: const InputDecoration(
              labelText: '表示名',
              hintText: '未入力でリセット',
            ),
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              editedDisplayName = value;
            },
            onFieldSubmitted: (value) {
              Navigator.of(dialogContext).pop(value);
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('キャンセル'),
            ),
            FilledButton(
              key: const Key('myPageDisplayNameSave'),
              onPressed: () {
                Navigator.of(dialogContext).pop(editedDisplayName);
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    final success = await ref
        .read(v2MyPageControllerProvider.notifier)
        .saveDisplayName(result);

    if (!mounted || !success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.trim().isEmpty ? '表示名をリセットしました' : '表示名を更新しました'),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('ログアウトしますか？'),
          content: const Text('地図の閲覧や検索は、ログアウト後も利用できます。'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('キャンセル'),
            ),
            FilledButton(
              key: const Key('myPageSignOutConfirm'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('ログアウト'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await ref.read(v2MyPageControllerProvider.notifier).signOut();

    if (widget.enableFavoriteProducts) {
      ref.read(favoriteProductsControllerProvider.notifier).clearForGuest();
    }
  }
}

class _GuestMyPage extends StatelessWidget {
  const _GuestMyPage({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('v2MyPageGuestView'),
      children: <Widget>[
        const SizedBox(height: V2Spacing.lg),
        CircleAvatar(
          radius: 36,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.person_outline_rounded, size: 40),
        ),
        const SizedBox(height: V2Spacing.md),
        Text(
          'ゲスト利用中',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: V2Spacing.sm),
        const Text(
          '地図の閲覧や商品検索は、このまま利用できます。\n'
          'ログインすると、よく飲む商品や投稿などのユーザー機能を利用できます。',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: V2Spacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('myPageLoginButton'),
            onPressed: onLogin,
            icon: const Icon(Icons.login_rounded),
            label: const Text('ログイン / 新規登録'),
          ),
        ),
      ],
    );
  }
}

class _AuthenticatedMyPage extends StatelessWidget {
  const _AuthenticatedMyPage({
    required this.state,
    required this.onEditDisplayName,
    required this.onSignOut,
    required this.enableFavoriteProducts,
  });

  final V2MyPageState state;
  final VoidCallback onEditDisplayName;
  final VoidCallback onSignOut;
  final bool enableFavoriteProducts;

  @override
  Widget build(BuildContext context) {
    final user = state.user!;

    return Column(
      key: const Key('v2MyPageAuthenticatedView'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ProfileCard(
          displayName: state.resolvedDisplayName,
          email: user.email,
          providers: _providerLabel(user.providerIds),
          isLoading: state.isLoading,
          isSaving: state.isSavingDisplayName,
          onEditDisplayName: onEditDisplayName,
        ),
        const SizedBox(height: V2Spacing.md),
        if (enableFavoriteProducts)
          const V2FavoriteProductsCard()
        else
          const _InfoCard(
            icon: Icons.local_drink_outlined,
            title: 'よく飲む商品',
            description: 'P5-07でProduct IDベースの保存機能を接続します。',
          ),
        const SizedBox(height: V2Spacing.md),
        OutlinedButton.icon(
          key: const Key('myPageSignOutButton'),
          onPressed: state.isSigningOut ? null : onSignOut,
          icon: state.isSigningOut
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout_rounded),
          label: Text(state.isSigningOut ? 'ログアウト中…' : 'ログアウト'),
        ),
      ],
    );
  }

  static String _providerLabel(List<String> providerIds) {
    final labels = <String>[];

    if (providerIds.contains('google.com')) {
      labels.add('Google');
    }
    if (providerIds.contains('password')) {
      labels.add('メール');
    }

    if (labels.isEmpty) {
      return 'Firebase Authentication';
    }
    return labels.join(' / ');
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.displayName,
    required this.email,
    required this.providers,
    required this.isLoading,
    required this.isSaving,
    required this.onEditDisplayName,
  });

  final String displayName;
  final String? email;
  final String providers;
  final bool isLoading;
  final bool isSaving;
  final VoidCallback onEditDisplayName;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: const RoundedRectangleBorder(borderRadius: V2Radius.card),
      child: Padding(
        padding: const EdgeInsets.all(V2Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 28,
                  child: Text(
                    _initial(displayName),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: V2Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        displayName,
                        key: const Key('myPageDisplayName'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: V2Spacing.xxs),
                      const Text('ログイン中'),
                    ],
                  ),
                ),
              ],
            ),
            if (isLoading) ...<Widget>[
              const SizedBox(height: V2Spacing.md),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: V2Spacing.md),
            _AccountLine(
              icon: Icons.mail_outline_rounded,
              label: email?.trim().isNotEmpty == true
                  ? email!.trim()
                  : 'メールアドレス未設定',
            ),
            const SizedBox(height: V2Spacing.sm),
            _AccountLine(icon: Icons.verified_user_outlined, label: providers),
            const SizedBox(height: V2Spacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('myPageEditDisplayNameButton'),
                onPressed: isSaving ? null : onEditDisplayName,
                icon: isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_outlined),
                label: Text(isSaving ? '保存中…' : '表示名を変更'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initial(String displayName) {
    final normalized = displayName.trim();
    if (normalized.isEmpty) {
      return 'U';
    }
    return String.fromCharCodes(normalized.runes.take(1));
  }
}

class _AccountLine extends StatelessWidget {
  const _AccountLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 20),
        const SizedBox(width: V2Spacing.sm),
        Expanded(
          child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: const RoundedRectangleBorder(borderRadius: V2Radius.card),
      child: Padding(
        padding: const EdgeInsets.all(V2Spacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon),
            const SizedBox(width: V2Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: V2Spacing.xs),
                  Text(description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.state, required this.onDismiss});

  final V2MyPageState state;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final failure = state.failure!;

    return Material(
      key: const Key('myPageFailure'),
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: V2Radius.control,
      child: Padding(
        padding: const EdgeInsets.all(V2Spacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: V2Spacing.sm),
            Expanded(
              child: Text(
                failure.userMessage,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            IconButton(
              tooltip: '閉じる',
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
