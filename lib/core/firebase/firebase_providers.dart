import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAppProvider = Provider<FirebaseApp>(
  (ref) => Firebase.app(),
  name: 'firebaseAppProvider',
);

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
  name: 'firebaseAuthProvider',
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
  name: 'firestoreProvider',
);

final firebaseStorageProvider = Provider<FirebaseStorage>(
  (ref) => FirebaseStorage.instance,
  name: 'firebaseStorageProvider',
);

final cloudFunctionsProvider = Provider<FirebaseFunctions>(
  (ref) => FirebaseFunctions.instance,
  name: 'cloudFunctionsProvider',
);

final firebaseAppCheckProvider = Provider<FirebaseAppCheck>(
  (ref) => FirebaseAppCheck.instance,
  name: 'firebaseAppCheckProvider',
);
