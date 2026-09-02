import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/repositories/account_deletion_repository_impl.dart';
import '../../data/repositories/user_profile_repository_impl.dart';
import '../../data/sources/account_deletion_data_source.dart';
import '../../data/sources/callable_account_deletion_data_source.dart';
import '../../data/sources/firestore_user_profile_data_source.dart';
import '../../data/sources/user_profile_data_source.dart';
import '../../domain/repositories/account_deletion_repository.dart';
import '../../domain/repositories/user_profile_repository.dart';

final userProfileDataSourceProvider = Provider<UserProfileDataSource>(
  (ref) => FirestoreUserProfileDataSource(ref.watch(firestoreProvider)),
  name: 'userProfileDataSourceProvider',
);

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => UserProfileRepositoryImpl(ref.watch(userProfileDataSourceProvider)),
  name: 'userProfileRepositoryProvider',
);

final accountDeletionDataSourceProvider = Provider<AccountDeletionDataSource>(
  (ref) => CallableAccountDeletionDataSource(ref.watch(cloudFunctionsProvider)),
  name: 'accountDeletionDataSourceProvider',
);

final accountDeletionRepositoryProvider = Provider<AccountDeletionRepository>(
  (ref) => AccountDeletionRepositoryImpl(
    ref.watch(accountDeletionDataSourceProvider),
  ),
  name: 'accountDeletionRepositoryProvider',
);
