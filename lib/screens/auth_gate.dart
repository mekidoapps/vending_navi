import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'main_shell_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingScreen();
        }

        if (snapshot.data != null) {
          return MainShellScreen();
        }

        return const _GuestEntryScreen();
      },
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _GuestEntryScreen extends StatelessWidget {
  const _GuestEntryScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Spacer(),
              const Icon(
                Icons.local_drink_rounded,
                size: 72,
              ),
              const SizedBox(height: 20),
              const Text(
                '今飲みたいものを探そう',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Noto Sans JP',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '近くの自販機を見たり、飲みたいドリンクから探せます。\n登録や更新はログイン後に使えます。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Noto Sans JP',
                  fontSize: 14,
                  color: Color(0xFF60707A),
                  height: 1.6,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MainShellScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.map_rounded),
                label: const Text('ログインせずに見る'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LoginScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.login_rounded),
                label: const Text('ログイン / 新規登録'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}