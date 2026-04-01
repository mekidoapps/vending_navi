import '../models/drink_item.dart';
import '../models/vending_machine.dart';

class MockVendingRepository {
  const MockVendingRepository();

  List<DrinkItem> getAllDrinks() {
    return const <DrinkItem>[
      DrinkItem(
        id: 'd1',
        name: 'お〜いお茶',
        brand: '伊藤園',
        category: 'お茶',
        searchKeywords: <String>['緑茶', 'itoen', 'おーいお茶'],
        isHotCompatible: true,
      ),
      DrinkItem(
        id: 'd2',
        name: '綾鷹',
        brand: 'Coca-Cola',
        category: 'お茶',
        searchKeywords: <String>['緑茶', 'あやたか'],
        isHotCompatible: true,
      ),
      DrinkItem(
        id: 'd3',
        name: '伊右衛門',
        brand: 'サントリー',
        category: 'お茶',
        searchKeywords: <String>['緑茶', 'いえもん'],
        isHotCompatible: true,
      ),
      DrinkItem(
        id: 'd4',
        name: 'ボス ブラック',
        brand: 'サントリー',
        category: 'コーヒー',
        searchKeywords: <String>['boss', 'ブラックコーヒー', '缶コーヒー'],
        isHotCompatible: true,
      ),
      DrinkItem(
        id: 'd5',
        name: 'ジョージア',
        brand: 'Coca-Cola',
        category: 'コーヒー',
        searchKeywords: <String>['georgia', '缶コーヒー'],
        isHotCompatible: true,
      ),
      DrinkItem(
        id: 'd6',
        name: 'コカ・コーラ',
        brand: 'Coca-Cola',
        category: '炭酸',
        searchKeywords: <String>['coke', 'cola', 'コーラ'],
      ),
      DrinkItem(
        id: 'd7',
        name: '午後の紅茶',
        brand: 'キリン',
        category: '紅茶',
        searchKeywords: <String>['ミルクティー', 'ストレートティー', 'ごごてぃー'],
        isHotCompatible: true,
      ),
      DrinkItem(
        id: 'd8',
        name: 'いろはす',
        brand: 'Coca-Cola',
        category: '水',
        searchKeywords: <String>['天然水', 'water'],
      ),
      DrinkItem(
        id: 'd9',
        name: 'ポカリスエット',
        brand: '大塚製薬',
        category: 'スポーツドリンク',
        searchKeywords: <String>['スポドリ', 'pocari'],
      ),
      DrinkItem(
        id: 'd10',
        name: 'デカビタC',
        brand: 'サントリー',
        category: 'エナジー',
        searchKeywords: <String>['炭酸', 'エナジー'],
      ),
    ];
  }

  List<VendingMachine> getNearbyMachines() {
    final drinks = getAllDrinks();

    DrinkItem byId(String id) {
      return drinks.firstWhere((e) => e.id == id);
    }

    return <VendingMachine>[
      VendingMachine(
        id: 'm1',
        name: '駅前ロータリー横',
        latitude: 35.0,
        longitude: 139.0,
        distanceMeters: 120,
        addressHint: '駅の改札を出て右',
        paymentLabel: '電子決済OK',
        updatedLabel: '2日前に更新',
        tags: const <String>['電子決済OK', 'ゴミ箱あり', '屋外'],
        drinks: <DrinkItem>[
          byId('d1'),
          byId('d2'),
          byId('d4'),
          byId('d6'),
        ],
        photoUrls: const <String>[],
        reliabilityScore: 90,
        hasFavoriteMatch: true,
      ),
      VendingMachine(
        id: 'm2',
        name: '公園入口の自販機',
        latitude: 35.0005,
        longitude: 139.0008,
        distanceMeters: 260,
        addressHint: '公園入口の左側',
        paymentLabel: '現金のみ',
        updatedLabel: '6日前に更新',
        tags: const <String>['現金のみ', '屋外', '冷たいのみ'],
        drinks: <DrinkItem>[
          byId('d6'),
          byId('d8'),
          byId('d9'),
          byId('d10'),
        ],
        photoUrls: const <String>[],
        reliabilityScore: 72,
        hasFavoriteMatch: false,
      ),
      VendingMachine(
        id: 'm3',
        name: 'ビル1階入口横',
        latitude: 35.0010,
        longitude: 139.0012,
        distanceMeters: 420,
        addressHint: 'ビル入口の自動ドア横',
        paymentLabel: '電子決済OK',
        updatedLabel: '12日前に更新',
        tags: const <String>['電子決済OK', '屋内', 'ホットあり'],
        drinks: <DrinkItem>[
          byId('d3'),
          byId('d4'),
          byId('d5'),
          byId('d7'),
        ],
        photoUrls: const <String>[],
        reliabilityScore: 58,
        hasFavoriteMatch: false,
      ),
    ];
  }

  List<DrinkItem> searchDrinks(String query) {
    final drinks = getAllDrinks();
    if (query.trim().isEmpty) return drinks;
    return drinks.where((drink) => drink.matches(query)).toList();
  }

  List<VendingMachine> searchMachines({
    required String query,
    List<String> selectedTags = const <String>[],
  }) {
    final machines = getNearbyMachines();

    return machines.where((machine) {
      final matchesQuery = query.trim().isEmpty
          ? true
          : machine.name.toLowerCase().contains(query.toLowerCase()) ||
          machine.drinks.any((drink) => drink.matches(query));

      final matchesTags = selectedTags.isEmpty
          ? true
          : selectedTags.every(machine.tags.contains);

      return matchesQuery && matchesTags;
    }).toList();
  }
}