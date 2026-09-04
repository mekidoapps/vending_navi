import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route.dart';
import '../../auth/application/auth_required_action_runner.dart';
import '../../auth/application/providers/auth_action_gate_provider.dart';
import '../../auth/presentation/v2_login_required_sheet.dart';

abstract final class V2RegistrationAuthGate {
  static Future<AuthRequiredActionResult> run(
    BuildContext context,
    WidgetRef ref, {
    required String actionLabel,
    required AuthenticatedAction action,
  }) {
    return ref.read(authRequiredActionRunnerProvider).run(
      requestAuthentication: () async {
        final shouldOpenAuth = await V2LoginRequiredSheet.show(
          context,
          actionLabel: actionLabel,
        );
        if (!context.mounted || !shouldOpenAuth) {
          return false;
        }

        return await context.pushNamed<bool>(AppRoute.v2EmailAuth.name) == true;
      },
      action: action,
    );
  }
}
