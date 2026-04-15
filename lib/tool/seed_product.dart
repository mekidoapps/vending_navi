import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';


Future<void> main() async {


  final firestore = FirebaseFirestore.instance;
  final machinesSnapshot = await firestore.collection('vending_machines').get();

  if (machinesSnapshot.docs.isEmpty) {
    print('vending_machines にデータがありません');
    return;
  }

  final defaultProducts = <String>[
    'お〜いお茶',
    '綾鷹',
    'BOSS ブラック',
    'ジョージア エメラルドマウンテン',
    '午後の紅茶 ミルクティー',
    'いろはす',
    'コカ・コーラ',
  ];

  int updatedCount = 0;
  int skippedCount = 0;

  for (final doc in machinesSnapshot.docs) {
    final data = doc.data();
    final currentProducts = _readStringList(data['products']);

    if (currentProducts.isNotEmpty) {
      skippedCount++;
      print('SKIP: ${doc.id} (${data['name'] ?? '名称未設定'})');
      continue;
    }

    final suggestedProducts = _buildProductsFromName(
      name: (data['name'] ?? '').toString(),
      tags: _readStringList(data['tags']),
      fallback: defaultProducts,
    );

    await doc.reference.update({
      'products': suggestedProducts,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    updatedCount++;
    print('UPDATE: ${doc.id} -> $suggestedProducts');
  }

  print('完了');
  print('更新件数: $updatedCount');
  print('スキップ件数: $skippedCount');
}

List<String> _readStringList(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).toList();
  }
  return <String>[];
}

List<String> _buildProductsFromName({
  required String name,
  required List<String> tags,
  required List<String> fallback,
}) {
  final normalizedName = name.toLowerCase();
  final normalizedTags = tags.map((e) => e.toLowerCase()).toList();

  if (normalizedName.contains('コーヒー') ||
      normalizedTags.any((e) => e.contains('コーヒー'))) {
    return <String>[
      'BOSS ブラック',
      'ジョージア エメラルドマウンテン',
      'ワンダ モーニングショット',
      'お〜いお茶',
      'いろはす',
    ];
  }

  if (normalizedName.contains('お茶') ||
      normalizedTags.any((e) => e.contains('お茶'))) {
    return <String>[
      'お〜いお茶',
      '綾鷹',
      '伊右衛門',
      '午後の紅茶 ストレートティー',
      'いろはす',
    ];
  }

  if (normalizedName.contains('炭酸') ||
      normalizedTags.any((e) => e.contains('炭酸'))) {
    return <String>[
      'コカ・コーラ',
      '三ツ矢サイダー',
      'ファンタ グレープ',
      '午後の紅茶 ミルクティー',
      'いろはす',
    ];
  }

  return fallback;
}