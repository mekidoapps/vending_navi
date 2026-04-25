import 'package:flutter/material.dart';

import 'auth_gate.dart';
import 'onboarding_screen.dart';

class StartupRouterScreen extends StatefulWidget {
  const StartupRouterScreen({super.key});

  @override
  State<StartupRouterScreen> createState() => _StartupRouterScreenState();
}

class _StartupRouterScreenState extends State<StartupRouterScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final bool hasSeen = await OnboardingScreen.hasSeen();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => hasSeen ? const AuthGate() : const OnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFEAF6FF),
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}