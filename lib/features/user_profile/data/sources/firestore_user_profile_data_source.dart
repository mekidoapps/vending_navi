import 'package:cloud_firestore/cloud_firestore.dart';

import '../dtos/user_profile_dto.dart';
import 'user_profile_data_source.dart';

final class FirestoreUserProfileDataSource implements UserProfileDataSource {
  const FirestoreUserProfileDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  @override
  Future<UserProfileDto> getOrCreateProfile({required String uid}) {
    final normalizedUid = _validatedUid(uid);

    return _firestore.runTransaction<UserProfileDto>((transaction) async {
      final reference = _users.doc(normalizedUid);
      final snapshot = await transaction.get(reference);

      if (snapshot.exists) {
        return UserProfileDto.fromFirestore(
          documentId: normalizedUid,
          data: snapshot.data() ?? const <String, dynamic>{},
        );
      }

      transaction.set(reference, <String, dynamic>{
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return UserProfileDto(
        documentId: normalizedUid,
        appDisplayName: null,
        legacyDisplayName: null,
      );
    });
  }

  @override
  Future<UserProfileDto> saveDisplayName({
    required String uid,
    required String? displayName,
  }) {
    final normalizedUid = _validatedUid(uid);
    final normalizedDisplayName = _normalizedOptional(displayName);

    return _firestore.runTransaction<UserProfileDto>((transaction) async {
      final reference = _users.doc(normalizedUid);
      final snapshot = await transaction.get(reference);

      final payload = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!snapshot.exists) {
        payload['createdAt'] = FieldValue.serverTimestamp();
      }

      if (normalizedDisplayName == null) {
        if (snapshot.exists) {
          payload['appDisplayName'] = FieldValue.delete();
          payload['displayName'] = FieldValue.delete();
        }
      } else {
        payload['appDisplayName'] = normalizedDisplayName;
        payload['displayName'] = normalizedDisplayName;
      }

      transaction.set(reference, payload, SetOptions(merge: true));

      return UserProfileDto(
        documentId: normalizedUid,
        appDisplayName: normalizedDisplayName,
        legacyDisplayName: normalizedDisplayName,
      );
    });
  }

  static String _validatedUid(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'uid', 'uid must not be empty');
    }
    return normalized;
  }

  static String? _normalizedOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
