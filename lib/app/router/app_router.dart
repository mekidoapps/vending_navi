import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/v2_email_auth_screen.dart';
import '../../features/home_map/presentation/v2_home_map_screen.dart';
import '../../features/user_profile/presentation/v2_my_page_screen.dart';
import '../../features/vending_machine/domain/value_objects/vending_machine_id.dart';
import '../../features/vending_machine/presentation/v2_vending_machine_detail_screen.dart';
import '../../screens/startup_router_screen.dart';
import 'app_route.dart';
import 'entry_mode.dart';

typedef AppRouteWidgetBuilder = Widget Function(BuildContext context);
typedef AppMachineDetailWidgetBuilder =
    Widget Function(BuildContext context, VendingMachineId machineId);

GoRouter createAppRouter({
  required AppEntryMode entryMode,
  AppRouteWidgetBuilder? legacyBuilder,
  AppRouteWidgetBuilder? v2Builder,
  AppMachineDetailWidgetBuilder? machineDetailBuilder,
  AppRouteWidgetBuilder? emailAuthBuilder,
  AppRouteWidgetBuilder? myPageBuilder,
}) {
  return GoRouter(
    initialLocation: entryMode.initialLocation,
    routes: <RouteBase>[
      GoRoute(
        name: AppRoute.legacyRoot.name,
        path: AppRoute.legacyRoot.path,
        builder: (BuildContext context, GoRouterState state) {
          return legacyBuilder?.call(context) ?? const StartupRouterScreen();
        },
      ),
      GoRoute(
        name: AppRoute.v2Foundation.name,
        path: AppRoute.v2Foundation.path,
        builder: (BuildContext context, GoRouterState state) {
          return v2Builder?.call(context) ??
              V2HomeMapScreen(
                onProfilePressed: () {
                  context.pushNamed(AppRoute.v2MyPage.name);
                },
              );
        },
      ),
      GoRoute(
        name: AppRoute.v2MachineDetail.name,
        path: AppRoute.v2MachineDetail.path,
        builder: (BuildContext context, GoRouterState state) {
          final rawMachineId = state.pathParameters['machineId'] ?? '';
          final machineId = VendingMachineId.tryParse(rawMachineId);

          if (machineId == null) {
            return RouteErrorScreen(location: state.uri.toString());
          }

          return machineDetailBuilder?.call(context, machineId) ??
              V2VendingMachineDetailScreen(machineId: machineId);
        },
      ),
      GoRoute(
        name: AppRoute.v2EmailAuth.name,
        path: AppRoute.v2EmailAuth.path,
        builder: (BuildContext context, GoRouterState state) {
          return emailAuthBuilder?.call(context) ?? const V2EmailAuthScreen();
        },
      ),
      GoRoute(
        name: AppRoute.v2MyPage.name,
        path: AppRoute.v2MyPage.path,
        builder: (BuildContext context, GoRouterState state) {
          return myPageBuilder?.call(context) ?? const V2MyPageScreen();
        },
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) {
      return RouteErrorScreen(location: state.uri.toString());
    },
  );
}

class RouteErrorScreen extends StatelessWidget {
  const RouteErrorScreen({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.route_outlined, size: 44),
              const SizedBox(height: 12),
              const Text(
                '画面を表示できませんでした',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(location, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.goNamed(AppRoute.legacyRoot.name),
                child: const Text('現行画面へ戻る'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
