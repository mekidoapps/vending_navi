import 'package:cloud_firestore/cloud_firestore.dart';

class DrinkCatalogService {
  DrinkCatalogService._();

  static final DrinkCatalogService instance = DrinkCatalogService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const List<DrinkCatalogItem> fallbackItems = <DrinkCatalogItem>[
    DrinkCatalogItem(
      id: 'coca_cola',
      name: 'コカ・コーラ',
      manufacturer: 'コカ・コーラ',
      tags: <String>['炭酸', 'ジュース', '加糖'],
    ),
    DrinkCatalogItem(
      id: 'ayataka',
      name: '綾鷹',
      manufacturer: 'コカ・コーラ',
      tags: <String>['お茶', '無糖'],
    ),
    DrinkCatalogItem(
      id: 'irohas',
      name: 'い・ろ・は・す',
      manufacturer: 'コカ・コーラ',
      tags: <String>['水'],
    ),
    DrinkCatalogItem(
      id: 'georgia',
      name: 'ジョージア',
      manufacturer: 'コカ・コーラ',
      tags: <String>['コーヒー', 'カフェイン'],
    ),
    DrinkCatalogItem(
      id: 'boss',
      name: 'BOSS',
      manufacturer: 'サントリー',
      tags: <String>['コーヒー', 'カフェイン'],
    ),
    DrinkCatalogItem(
      id: 'iyemon',
      name: '伊右衛門',
      manufacturer: 'サントリー',
      tags: <String>['お茶', '無糖'],
    ),
    DrinkCatalogItem(
      id: 'suntory_tennensui',
      name: '天然水',
      manufacturer: 'サントリー',
      tags: <String>['水'],
    ),
    DrinkCatalogItem(
      id: 'oi_ocha',
      name: 'お〜いお茶',
      manufacturer: '伊藤園',
      tags: <String>['お茶', '無糖'],
    ),
    DrinkCatalogItem(
      id: 'mugicha',
      name: '健康ミネラルむぎ茶',
      manufacturer: '伊藤園',
      tags: <String>['お茶', '無糖'],
    ),
    DrinkCatalogItem(
      id: 'gogo_no_kocha',
      name: '午後の紅茶',
      manufacturer: 'キリン',
      tags: <String>['紅茶'],
    ),
    DrinkCatalogItem(
      id: 'namacha',
      name: '生茶',
      manufacturer: 'キリン',
      tags: <String>['お茶', '無糖'],
    ),
    DrinkCatalogItem(
      id: 'wanda',
      name: 'WONDA',
      manufacturer: 'アサヒ',
      tags: <String>['コーヒー', 'カフェイン'],
    ),
    DrinkCatalogItem(
      id: 'mitsuya_cider',
      name: '三ツ矢サイダー',
      manufacturer: 'アサヒ',
      tags: <String>['炭酸', 'ジュース', '加糖'],
    ),
    DrinkCatalogItem(
      id: 'pocari',
      name: 'ポカリスエット',
      manufacturer: '大塚製薬',
      tags: <String>['スポーツ', 'スッキリ'],
    ),
  ];

  Future<List<DrinkCatalogItem>> getDrinkCatalogItems() async {
    final List<DrinkCatalogItem> fromProducts =
    await _getFromProductsCollection();

    if (fromProducts.isNotEmpty) {
      return _mergeAndSort(<DrinkCatalogItem>[
        ...fromProducts,
        ...fallbackItems,
      ]);
    }

    final List<DrinkCatalogItem> fromMachines =
    await _getFromVendingMachines();

    return _mergeAndSort(<DrinkCatalogItem>[
      ...fromMachines,
      ...fallbackItems,
    ]);
  }

  Future<List<DrinkCatalogItem>> _getFromProductsCollection() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
      await _db.collection('products').limit(300).get();

      return snapshot.docs
          .map((doc) => DrinkCatalogItem.fromProductDoc(doc.id, doc.data()))
          .where((item) => item.name.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <DrinkCatalogItem>[];
    }
  }

  Future<List<DrinkCatalogItem>> _getFromVendingMachines() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
      await _db.collection('vending_machines').limit(300).get();

      final List<DrinkCatalogItem> result = <DrinkCatalogItem>[];

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
      in snapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        final String machineManufacturer =
        _readString(data['manufacturer'], fallback: 'その他');

        _appendProductMaps(
          result,
          data['products'],
          fallbackManufacturer: machineManufacturer,
        );
        _appendProductMaps(
          result,
          data['drinkSlots'],
          fallbackManufacturer: machineManufacturer,
        );
        _appendStringList(
          result,
          data['drinks'],
          fallbackManufacturer: machineManufacturer,
        );
      }

      return result;
    } catch (_) {
      return const <DrinkCatalogItem>[];
    }
  }

  void _appendProductMaps(
      List<DrinkCatalogItem> result,
      dynamic source, {
        required String fallbackManufacturer,
      }) {
    if (source is! List) return;

    for (final dynamic value in source) {
      if (value is Map) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(value);
        final String name = _readString(map['name']);
        if (name.isEmpty) continue;

        final String manufacturer =
        _readString(map['manufacturer'], fallback: fallbackManufacturer);

        result.add(
          DrinkCatalogItem(
            id: _readString(map['id'], fallback: _normalize(name)),
            name: name,
            manufacturer: manufacturer,
            tags: _readStringList(map['tags']),
          ),
        );
      } else {
        final String name = value.toString().trim();
        if (name.isEmpty) continue;

        result.add(
          DrinkCatalogItem(
            id: _normalize(name),
            name: name,
            manufacturer: fallbackManufacturer,
            tags: const <String>[],
          ),
        );
      }
    }
  }

  void _appendStringList(
      List<DrinkCatalogItem> result,
      dynamic source, {
        required String fallbackManufacturer,
      }) {
    if (source is! List) return;

    for (final dynamic value in source) {
      final String name = value.toString().trim();
      if (name.isEmpty) continue;

      result.add(
        DrinkCatalogItem(
          id: _normalize(name),
          name: name,
          manufacturer: fallbackManufacturer,
          tags: const <String>[],
        ),
      );
    }
  }

  List<DrinkCatalogItem> _mergeAndSort(List<DrinkCatalogItem> items) {
    final Map<String, DrinkCatalogItem> merged = <String, DrinkCatalogItem>{};

    for (final DrinkCatalogItem item in items) {
      final String key = _normalize('${item.manufacturer}_${item.name}');
      if (key.isEmpty) continue;

      final DrinkCatalogItem? existing = merged[key];
      if (existing == null) {
        merged[key] = item;
      } else {
        merged[key] = existing.merge(item);
      }
    }

    final List<DrinkCatalogItem> result = merged.values.toList();
    result.sort((a, b) {
      final int manufacturerCompare = a.manufacturer.compareTo(b.manufacturer);
      if (manufacturerCompare != 0) return manufacturerCompare;
      return a.name.compareTo(b.name);
    });

    return result;
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List) return const <String>[];

    final Set<String> used = <String>{};
    final List<String> result = <String>[];

    for (final dynamic item in value) {
      final String text = item.toString().trim();
      if (text.isEmpty) continue;

      final String key = _normalize(text);
      if (used.contains(key)) continue;

      used.add(key);
      result.add(text);
    }

    return result;
  }

  static String _normalize(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll('　', '')
        .replaceAll(' ', '')
        .replaceAll('〜', 'ー')
        .replaceAll('～', 'ー')
        .replaceAll('-', 'ー');
  }
}

class DrinkCatalogItem {
  const DrinkCatalogItem({
    required this.id,
    required this.name,
    required this.manufacturer,
    this.tags = const <String>[],
  });

  final String id;
  final String name;
  final String manufacturer;
  final List<String> tags;

  factory DrinkCatalogItem.fromProductDoc(
      String id,
      Map<String, dynamic> data,
      ) {
    return DrinkCatalogItem(
      id: id,
      name: DrinkCatalogService._readString(
        data['name'] ?? data['displayName'] ?? data['productName'],
      ),
      manufacturer: DrinkCatalogService._readString(
        data['manufacturer'] ?? data['maker'],
        fallback: 'その他',
      ),
      tags: DrinkCatalogService._readStringList(data['tags']),
    );
  }

  DrinkCatalogItem merge(DrinkCatalogItem other) {
    final Set<String> used = <String>{};
    final List<String> mergedTags = <String>[];

    for (final String tag in <String>[...tags, ...other.tags]) {
      final String trimmed = tag.trim();
      if (trimmed.isEmpty) continue;

      final String key = DrinkCatalogService._normalize(trimmed);
      if (used.contains(key)) continue;

      used.add(key);
      mergedTags.add(trimmed);
    }

    return DrinkCatalogItem(
      id: id.isNotEmpty ? id : other.id,
      name: name,
      manufacturer: manufacturer.isNotEmpty ? manufacturer : other.manufacturer,
      tags: mergedTags,
    );
  }
}
