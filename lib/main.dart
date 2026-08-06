import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/router/entry_mode.dart';
import 'app/vending_navi_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bootstrapResult = await bootstrap();
  final entryMode = AppEntryMode.fromEnvironment();

  runApp(
    ProviderScope(
      child: VendingNaviApp(
        bootstrapResult: bootstrapResult,
        entryMode: entryMode,
      ),
    ),
  );
}
