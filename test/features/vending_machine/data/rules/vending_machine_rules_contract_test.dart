import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('自販機rootはactiveだけ公開する', () {
    final rules = File(
      'firebase/v2/firestore.rules',
    ).readAsStringSync();

    expect(
      rules,
      contains('match /vending_machines/{machineId}'),
    );

    expect(
      rules,
      contains("allow read: if resource.data.status == 'active';"),
    );

    expect(
      rules,
      contains('allow write: if false;'),
    );
  });

  test('自販機商品はactiveな親のactive商品だけ公開する', () {
    final rules = File(
      'firebase/v2/firestore.rules',
    ).readAsStringSync();

    expect(
      rules,
      contains('match /products/{productId}'),
    );

    expect(
      rules,
      contains('resource.data.isActive == true'),
    );

    expect(
      rules,
      contains(
        '/databases/\$(database)/documents/'
        'vending_machines/\$(machineId)',
      ),
    );

    expect(
      rules,
      contains(".data.status == 'active'"),
    );
  });

  test('公開queryはFirestore側でactive条件を持つ', () {
    final viewportSource = File(
      'lib/features/home_map/data/sources/'
      'firestore_vending_machine_viewport_source.dart',
    ).readAsStringSync();

    final documentSource = File(
      'lib/features/vending_machine/data/sources/'
      'firestore_vending_machine_document_source.dart',
    ).readAsStringSync();

    expect(
      viewportSource,
      contains(".where('status', isEqualTo: 'active')"),
    );

    expect(
      documentSource,
      contains(".where('status', isEqualTo: 'active')"),
    );

    expect(
      documentSource,
      contains(".where('isActive', isEqualTo: true)"),
    );
  });

  test('公開写真はactiveな親とphotoだけがreadでき、client writeは拒否する', () {
    final rules = File(
      'firebase/v2/firestore.rules',
    ).readAsStringSync();

    expect(
      rules,
      contains('match /{document=**}'),
    );

    expect(
      rules,
      isNot(contains('match /revisions/{revisionId}')),
    );

    expect(rules, contains('match /photos/{photoId}'));
    expect(rules, contains("resource.data.status == 'active'"));
    expect(rules, contains('allow write: if false;'));
  });

  test('正式Storage写真は公開metadataと親machineの両方を要求する', () {
    final rules = File('firebase/v2/storage.rules').readAsStringSync();
    expect(rules, contains('match /vending_machines/{machineId}/{photoId}/original.jpg'));
    expect(rules, contains('function isActiveMachine(machineId)'));
    expect(rules, contains('function isActiveFormalPhoto(machineId, photoId)'));
    expect(rules, contains('allow write: if false;'));
  });

  test('投稿ルール同意は本人だけが読め、client直接書込みを許可しない', () {
    final rules = File('firebase/v2/firestore.rules').readAsStringSync();
    expect(rules, contains('match /ugc_consent/{consentId}'));
    expect(rules, contains('allow read: if isOwner();'));
    expect(rules, contains('allow write: if false;'));
  });
}
