import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route.dart';

class V2FoundationScreen extends StatelessWidget {
  const V2FoundationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF6FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE3E7EB)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDDF1FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_drink_rounded,
                      size: 36,
                      color: Color(0xFF3B82B8),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '自販機ナビ v2',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF334148),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '基盤確認画面',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4D6A7A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'go_routerによるv1・v2の共存起動が有効です。\n'
                    'この画面では、まだ検索や登録機能は実装しません。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Color(0xFF60707A),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          context.goNamed(AppRoute.legacyRoot.name),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('現行版を開く'),
                    ),
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
