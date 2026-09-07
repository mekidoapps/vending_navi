import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/vending_machine/domain/entities/public_machine_photo.dart';

void main() {
  test('public photo retains only document identity and public state', () {
    final createdAt = Timestamp.fromDate(DateTime.utc(2026, 1, 2));
    final photo = PublicMachinePhoto.fromDocument('p_0123456789abcdef0123456789abcd', <String, dynamic>{'status': 'active', 'createdAt': createdAt});
    expect(photo?.photoId, 'p_0123456789abcdef0123456789abcd');
    expect(photo?.status, 'active');
    expect(photo?.createdAt, createdAt.toDate());
    expect(photo?.displayReferenceFor('machine_001'), 'vending_machines/machine_001/p_0123456789abcdef0123456789abcd/original.jpg');
  });

  test('invalid public status is rejected and private fields are not modeled', () {
    expect(PublicMachinePhoto.fromDocument('p_x', <String, dynamic>{}), isNull);
    final source = File('lib/features/vending_machine/domain/entities/public_machine_photo.dart').readAsStringSync();
    for (final privateField in <String>['uploadedBy', 'email', 'displayName', 'storagePath', 'thumbnailPath', 'recognitionStatus', 'recognitionProvider']) {
      expect(source, isNot(contains(privateField)));
    }
  });
}
import 'dart:io';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
