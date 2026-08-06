import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route.dart';
import '../../../app/theme/v2_color_tokens.dart';
import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_shadows.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../../app/theme/v2_theme.dart';
import '../../../core/ui/badges/v2_status_badge.dart';
import '../../../core/ui/buttons/v2_map_action_button.dart';
import '../../../core/ui/buttons/v2_primary_button.dart';
import '../../../core/ui/buttons/v2_secondary_button.dart';
import '../../../core/ui/states/v2_empty_state.dart';
import '../../../core/ui/states/v2_error_state.dart';
import '../../../core/ui/states/v2_loading_state.dart';

class V2FoundationScreen extends StatelessWidget {
  const V2FoundationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(data: V2Theme.light(), child: const _FoundationContent());
  }
}

class _FoundationContent extends StatelessWidget {
  const _FoundationContent();

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('自販機ナビ v2')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            V2Spacing.md,
            V2Spacing.xs,
            V2Spacing.md,
            V2Spacing.xl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _FoundationCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.primarySoft,
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(V2Spacing.sm),
                                child: Icon(
                                  Icons.local_drink_rounded,
                                  size: 32,
                                  color: colors.primaryStrong,
                                ),
                              ),
                            ),
                            const SizedBox(width: V2Spacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'デザイン基盤確認',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineSmall,
                                  ),
                                  const SizedBox(height: V2Spacing.xxs),
                                  Text(
                                    '白・水色・淡い青を基準にしたMVPテーマです。',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: V2Spacing.lg),
                        V2PrimaryButton(
                          label: 'ここに行く',
                          icon: Icons.directions_rounded,
                          onPressed: () {},
                        ),
                        const SizedBox(height: V2Spacing.sm),
                        V2SecondaryButton(
                          label: '情報を更新する',
                          icon: Icons.edit_rounded,
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: V2Spacing.md),
                  _FoundationCard(
                    title: '地図上の操作ボタン',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        V2MapActionButton(
                          key: const Key('registerMapAction'),
                          icon: Icons.add_rounded,
                          semanticLabel: '登録',
                          onPressed: () {},
                        ),
                        const SizedBox(width: V2Spacing.sm),
                        V2MapActionButton(
                          key: const Key('searchMapAction'),
                          icon: Icons.search_rounded,
                          semanticLabel: '探す',
                          size: 60,
                          isPrimary: true,
                          onPressed: () {},
                        ),
                        const SizedBox(width: V2Spacing.sm),
                        V2MapActionButton(
                          key: const Key('profileMapAction'),
                          icon: Icons.person_rounded,
                          semanticLabel: 'マイ',
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: V2Spacing.md),
                  const _FoundationCard(
                    title: '情報の状態',
                    child: Wrap(
                      spacing: V2Spacing.xs,
                      runSpacing: V2Spacing.xs,
                      children: <Widget>[
                        V2StatusBadge(type: V2StatusBadgeType.confirmed),
                        V2StatusBadge(type: V2StatusBadgeType.inferred),
                        V2StatusBadge(type: V2StatusBadgeType.stale),
                      ],
                    ),
                  ),
                  const SizedBox(height: V2Spacing.md),
                  const _FoundationCard(
                    title: '画面状態',
                    child: Column(
                      children: <Widget>[
                        V2LoadingState(message: '周辺の自販機を探しています'),
                        Divider(),
                        V2EmptyState(
                          title: '近くに自販機が見つかりません',
                          message: 'この地域では、まだ情報が登録されていない可能性があります。',
                        ),
                        Divider(),
                        V2ErrorState(
                          title: '読み込めませんでした',
                          message: '通信状態を確認して、もう一度お試しください。',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: V2Spacing.lg),
                  TextButton.icon(
                    onPressed: () => context.goNamed(AppRoute.legacyRoot.name),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('現行版を開く'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FoundationCard extends StatelessWidget {
  const _FoundationCard({this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: V2Radius.card,
        border: Border.all(color: colors.border),
        boxShadow: V2Shadows.subtle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(V2Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (title != null) ...<Widget>[
              Text(title!, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: V2Spacing.sm),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
