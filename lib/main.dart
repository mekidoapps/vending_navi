import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';

import 'providers/auth_provider.dart';
import 'providers/checkin_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/machine_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/search_provider.dart';
import 'providers/title_provider.dart';

import 'screens/auth_gate.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // すでに初期化済みの場合は無視する
    if (!e.toString().contains('duplicate-app')) {
      rethrow;
    }
  }

  runApp(const VendingNaviApp());
}


class VendingNaviApp extends StatelessWidget {
  const VendingNaviApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider<SearchProvider>(
          create: (_) => SearchProvider(),
        ),
        ChangeNotifierProvider<MachineProvider>(
          create: (_) => MachineProvider(),
        ),
        ChangeNotifierProvider<CheckinProvider>(
          create: (_) => CheckinProvider(),
        ),
        ChangeNotifierProvider<FavoritesProvider>(
          create: (_) => FavoritesProvider(),
        ),
        ChangeNotifierProvider<ProfileProvider>(
          create: (_) => ProfileProvider(),
        ),
        ChangeNotifierProvider<TitleProvider>(
          create: (_) => TitleProvider(),
        ),
      ],
      child: MaterialApp(
        title: '自販機ナビ',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthGate(),
      ),
    );
  }
}