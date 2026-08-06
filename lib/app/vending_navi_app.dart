import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import 'bootstrap/bootstrap_result.dart';
import 'router/app_router.dart';
import 'router/entry_mode.dart';

class VendingNaviApp extends StatefulWidget {
  const VendingNaviApp({
    super.key,
    required this.bootstrapResult,
    required this.entryMode,
  });

  final BootstrapResult bootstrapResult;
  final AppEntryMode entryMode;

  @override
  State<VendingNaviApp> createState() => _VendingNaviAppState();
}

class _VendingNaviAppState extends State<VendingNaviApp> {
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    _initializeRouter();
  }

  @override
  void didUpdateWidget(covariant VendingNaviApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entryMode != widget.entryMode ||
        oldWidget.bootstrapResult.isSuccess !=
            widget.bootstrapResult.isSuccess) {
      _disposeRouter();
      _initializeRouter();
    }
  }

  void _initializeRouter() {
    if (widget.bootstrapResult.isSuccess) {
      _router = createAppRouter(entryMode: widget.entryMode);
    }
  }

  void _disposeRouter() {
    _router?.dispose();
    _router = null;
  }

  @override
  void dispose() {
    _disposeRouter();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.bootstrapResult.isSuccess) {
      return MaterialApp(
        title: '自販機ナビ',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: StartupErrorScreen(
          message: widget.bootstrapResult.errorMessage ?? '不明なエラーが発生しました。',
        ),
      );
    }

    final router = _router;
    if (router == null) {
      return MaterialApp(
        title: '自販機ナビ',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const StartupErrorScreen(message: 'ルーターを初期化できませんでした。'),
      );
    }

    return MaterialApp.router(
      title: '自販機ナビ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}

class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF6FF),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE3E7EB)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.error_outline_rounded,
                  size: 44,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 12),
                const Text(
                  '起動に失敗しました',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334148),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF60707A),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
