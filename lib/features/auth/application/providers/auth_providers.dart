import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/sources/auth_data_source.dart';
import '../../data/sources/firebase_auth_data_source.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';

final authDataSourceProvider = Provider<AuthDataSource>(
  (ref) => FirebaseAuthDataSource(ref.watch(firebaseAuthProvider)),
  name: 'authDataSourceProvider',
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(authDataSourceProvider)),
  name: 'authRepositoryProvider',
);

final authSessionChangesProvider = StreamProvider<AuthSession>(
  (ref) => ref.watch(authRepositoryProvider).watchSession(),
  name: 'authSessionChangesProvider',
);

final authCurrentSessionProvider = Provider<AuthSession>(
  (ref) => ref.watch(authRepositoryProvider).currentSession,
  name: 'authCurrentSessionProvider',
);
