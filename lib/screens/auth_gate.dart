import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';
import 'main_shell_screen.dart';
import 'onboarding_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    this.initialMachineId,
  });

  final String? initialMachineId;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  static const String _onboardingSeenKey = 'onboarding_seen_v1';

  bool _isCheckingOnboarding = true;

  @override
  void initState() {
    super.initState();
    _prepareOnboarding();
  }

  Future<void> _prepareOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool(_onboardingSeenKey) ?? false;

      if (!mounted) return;
      setState(() {
        _isCheckingOnboarding = false;
      });

      if (!seen) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await _openOnboarding();
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCheckingOnboarding = false;
      });
    }
  }

  Future<void> _openOnboarding() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const OnboardingScreen(),
      ),
    );

    if (result == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_onboardingSeenKey, true);
      } catch (_) {
        // 継続
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingOnboarding) {
      return const _AuthLoadingScreen();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData) {
          return MainShellScreen(
            initialMachineId: widget.initialMachineId,
          );
        }

        return LoginScreen(
          initialMachineId: widget.initialMachineId,
        );
      },
    );
  }
}

class LoginRequiredSheet {
  LoginRequiredSheet._();

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _LoginRequiredSheetBody(
          parentContext: context,
        );
      },
    );
  }
}

class _LoginRequiredSheetBody extends StatefulWidget {
  const _LoginRequiredSheetBody({
    required this.parentContext,
  });

  final BuildContext parentContext;

  @override
  State<_LoginRequiredSheetBody> createState() => _LoginRequiredSheetBodyState();
}

class _LoginRequiredSheetBodyState extends State<_LoginRequiredSheetBody> {
  bool _isOpeningLogin = false;

  Future<void> _openLogin() async {
    if (_isOpeningLogin) return;

    setState(() {
      _isOpeningLogin = true;
    });

    try {
      await Navigator.of(widget.parentContext).push(
        MaterialPageRoute<void>(
          builder: (_) => const LoginScreen(),
        ),
      );

      if (!mounted) return;

      final loggedIn = FirebaseAuth.instance.currentUser != null;
      if (loggedIn) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningLogin = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF6FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 28,
                  color: Color(0xFF3E7BFA),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'この操作はログインが必要です',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334148),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '自販機の登録やお気に入りの保存にはログインが必要です。\nマップの閲覧や検索はそのまま使えます。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF60707A),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isOpeningLogin ? null : _openLogin,
                  icon: _isOpeningLogin
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.login_rounded),
                  label: Text(_isOpeningLogin ? '開いています…' : 'ログイン / 新規登録'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isOpeningLogin
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('あとで'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFD6ECFF),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(height: 14),
            Text(
              '読み込み中…',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334148),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
