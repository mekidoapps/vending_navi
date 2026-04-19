import 'package:cloud_firestore/cloud_firestore.dart';

import 'storage_service.dart';

class DrinkCandidateService {
  DrinkCandidateService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const Map<String, List<String>> _seedByManufacturer =
  <String, List<String>>{
    'コカコーラ': <String>[
      'コカコーラ',
      '綾鷹',
      'いろはす',
      'アクエリアス',
      'ジョージア',
      'ファンタ',
      '爽健美茶',
    ],
    'サントリー': <String>[
      'BOSS',
      '伊右衛門',
      'なっちゃん',
      '天然水',
      'ペプシ',
      'C.C.レモン',
      'GREEN DA・KA・RA',
    ],
    '大塚製薬': <String>[
      'ポカリ',
      'オロナミンC',
      'MATCH',
      'ボディメンテ',
    ],
    '伊藤園': <String>[
      'お〜いお茶',
      '健康ミネラルむぎ茶',
      'TULLY’S',
      '充実野菜',
    ],
    'キリン': <String>[
      '午後の紅茶',
      '生茶',
      'FIRE',
      'キリンレモン',
    ],
    'アサヒ': <String>[
      'WONDA',
      '十六茶',
      '三ツ矢サイダー',
      'カルピス',
      'ウィルキンソン',
    ],
    'その他': <String>[
      '水',
      'お茶',
      'コーヒー',
      '炭酸水',
      'ジュース',
    ],
  };

  Future<List<String>> getCandidates(String manufacturer) async {
    final Map<String, int> counter = <String, int>{};

    final List<String> seed =
        _seedByManufacturer[manufacturer] ?? _seedByManufacturer['その他']!;
    for (final String s in seed) {
      counter[s] = 0;
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _db
          .collection('vending_machines')
          .where('manufacturer', isEqualTo: manufacturer)
          .get();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
        final Map<String, dynamic> data = doc.data();

        final dynamic drinks = data['drinks'];
        if (drinks is List) {
          for (final dynamic d in drinks) {
            final String name = d.toString().trim();
            if (name.isEmpty) continue;
            counter[name] = (counter[name] ?? 0) + 1;
          }
        }

        final dynamic slots = data['drinkSlots'];
        if (slots is List) {
          for (final dynamic slot in slots) {
            if (slot is! Map) continue;
            final String name = (slot['name'] ?? '').toString().trim();
            if (name.isEmpty) continue;
            counter[name] = (counter[name] ?? 0) + 1;
          }
        }
      }
    } catch (_) {
      // 候補は seed だけでも成立するので握りつぶす
    }

    final List<String> recent = await StorageService.getRecentDrinks();

    final List<MapEntry<String, int>> list = counter.entries.toList()
      ..sort((a, b) {
        final bool aRecent = recent.contains(a.key);
        final bool bRecent = recent.contains(b.key);

        if (aRecent != bRecent) {
          return aRecent ? -1 : 1;
        }

        final int countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) return countCompare;

        return a.key.compareTo(b.key);
      });

    return list.map((e) => e.key).toList(growable: false);
  }
}
