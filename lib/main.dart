import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/search_home_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  runApp(const VendingNaviApp());
}

class VendingNaviApp extends StatelessWidget {
  const VendingNaviApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '自販機ナビ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SearchHomeScreen(),
    );
  }
}