import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth_required_action_runner.dart';
import 'auth_providers.dart';

final authRequiredActionRunnerProvider = Provider<AuthRequiredActionRunner>(
  (ref) => AuthRequiredActionRunner(ref.watch(authRepositoryProvider)),
  name: 'authRequiredActionRunnerProvider',
);
