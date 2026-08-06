import 'package:flutter/foundation.dart';

import 'bootstrap_config.dart';
import 'bootstrap_result.dart';

Future<BootstrapResult> bootstrap({BootstrapConfig? config}) async {
  final resolvedConfig = config ?? BootstrapConfig.production();

  try {
    await resolvedConfig.initializeFirebase();
    await resolvedConfig.connectFirebaseEmulators?.call();
    await resolvedConfig.activateAppCheck();
    return const BootstrapResult.success();
  } catch (error) {
    debugPrint('Application bootstrap failed: ${error.runtimeType}');
    return BootstrapResult.failure(error.toString());
  }
}
