import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'main_shell_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    this.initialMachineId,
  });

  final String? initialMachineId;

  @override
  Widget build(BuildContext context) {
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
            initialMachineId: initialMachineId,
          );
        }

        return LoginScreen(
          initialMachineId: initialMachineId,
        );
      },
    );
  }
}