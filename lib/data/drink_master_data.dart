import '../models/product.dart';

class DrinkMasterData {
  DrinkMasterData._();

  static const List<String> manufacturers = <String>[
    'すべて',
    'コカ・コーラ',
    'サントリー',
    '伊藤園',
    'キリン',
    'アサヒ',
    'ダイドー',
    '大塚製薬',
    'AQUO',
    'その他',
  ];

  static final List<Product> products = <Product>[
    // コカ・コーラ
    const Product(
      id: 'coca_cola',
      name: 'コカ・コーラ',
      manufacturer: 'コカ・コーラ',
      category: '炭酸',
      tags: <String>['炭酸', '甘い'],
      searchKeywords: <String>['コーラ'],
    ),
    const Product(
      id: 'coca_cola_zero',
      name: 'コカ・コーラ ゼロ',
      manufacturer: 'コカ・コーラ',
      category: '炭酸',
      tags: <String>['炭酸', 'ゼロ'],
      searchKeywords: <String>['コーラ', 'ゼロ'],
    ),
    const Product(
      id: 'ayataka',
      name: '綾鷹',
      manufacturer: 'コカ・コーラ',
      category: 'お茶',
      tags: <String>['お茶', '無糖'],
      searchKeywords: <String>['あやたか', '緑茶'],
    ),
    const Product(
      id: 'soukenbicha',
      name: '爽健美茶',
      manufacturer: 'コカ・コーラ',
      category: 'お茶',
      tags: <String>['お茶'],
      searchKeywords: <String>['そうけんびちゃ'],
    ),
    const Product(
      id: 'irohasu',
      name: 'い・ろ・は・す',
      manufacturer: 'コカ・コーラ',
      category: '水',
      tags: <String>['水'],
      searchKeywords: <String>['いろはす'],
    ),
    const Product(
      id: 'georgia_black',
      name: 'ジョージア ブラック',
      manufacturer: 'コカ・コーラ',
      category: 'コーヒー',
      tags: <String>['コーヒー', '無糖', 'カフェイン'],
      searchKeywords: <String>['ジョージア', 'ブラック'],
    ),
    const Product(
      id: 'fanta_grape',
      name: 'ファンタ グレープ',
      manufacturer: 'コカ・コーラ',
      category: '炭酸',
      tags: <String>['炭酸', 'ジュース', '甘い'],
      searchKeywords: <String>['ファンタ', 'グレープ'],
    ),
    const Product(
      id: 'aquarius',
      name: 'アクエリアス',
      manufacturer: 'コカ・コーラ',
      category: 'スポーツドリンク',
      tags: <String>['スポーツ', 'スッキリ'],
      searchKeywords: <String>['アクエリアス'],
    ),

    // サントリー
    const Product(
      id: 'boss_black',
      name: 'BOSS ブラック',
      manufacturer: 'サントリー',
      category: 'コーヒー',
      tags: <String>['コーヒー', '無糖', 'カフェイン'],
      searchKeywords: <String>['ボス', 'ブラック'],
    ),
    const Product(
      id: 'boss_rainbow',
      name: 'BOSS レインボーマウンテン',
      manufacturer: 'サントリー',
      category: 'コーヒー',
      tags: <String>['コーヒー', '甘い', 'カフェイン'],
      searchKeywords: <String>['ボス', 'レインボー'],
    ),
    const Product(
      id: 'craft_boss_black',
      name: 'クラフトボス ブラック',
      manufacturer: 'サントリー',
      category: 'コーヒー',
      tags: <String>['コーヒー', '無糖', 'カフェイン'],
      searchKeywords: <String>['クラフトボス', 'ブラック'],
    ),
    const Product(
      id: 'iyemon',
      name: '伊右衛門',
      manufacturer: 'サントリー',
      category: 'お茶',
      tags: <String>['お茶', '無糖'],
      searchKeywords: <String>['いえもん', '緑茶'],
    ),
    const Product(
      id: 'cc_lemon',
      name: 'C.C.レモン',
      manufacturer: 'サントリー',
      category: '炭酸',
      tags: <String>['炭酸', 'ジュース', '甘い'],
      searchKeywords: <String>['ccレモン', 'レモン'],
    ),
    const Product(
      id: 'suntory_water',
      name: '天然水',
      manufacturer: 'サントリー',
      category: '水',
      tags: <String>['水'],
      searchKeywords: <String>['天然水'],
    ),
    const Product(
      id: 'green_dakara',
      name: 'GREEN DA・KA・RA',
      manufacturer: 'サントリー',
      category: 'スポーツドリンク',
      tags: <String>['スポーツ', 'スッキリ'],
      searchKeywords: <String>['dakara', 'ダカラ'],
    ),
    const Product(
      id: 'dekavita_c',
      name: 'デカビタC',
      manufacturer: 'サントリー',
      category: '炭酸',
      tags: <String>['炭酸', 'エナジー', '甘い'],
      searchKeywords: <String>['デカビタ'],
    ),

    // 伊藤園
    const Product(
      id: 'oi_ocha_green',
      name: 'お〜いお茶 緑茶',
      manufacturer: '伊藤園',
      category: 'お茶',
      tags: <String>['お茶', '無糖'],
      searchKeywords: <String>['おーいお茶', 'おいお茶', '緑茶'],
    ),
    const Product(
      id: 'oi_ocha_dark',
      name: 'お〜いお茶 濃い茶',
      manufacturer: '伊藤園',
      category: 'お茶',
      tags: <String>['お茶', '無糖'],
      searchKeywords: <String>['おーいお茶', '濃い茶'],
    ),
    const Product(
      id: 'mugicha',
      name: '健康ミネラルむぎ茶',
      manufacturer: '伊藤園',
      category: 'お茶',
      tags: <String>['お茶'],
      searchKeywords: <String>['麦茶', 'むぎ茶'],
    ),
    const Product(
      id: 'tullys_black',
      name: 'TULLY\'S COFFEE ブラック',
      manufacturer: '伊藤園',
      category: 'コーヒー',
      tags: <String>['コーヒー', '無糖', 'カフェイン'],
      searchKeywords: <String>['タリーズ', 'ブラック'],
    ),
    const Product(
      id: 'itoen_water',
      name: '磨かれて、澄みきった日本の水',
      manufacturer: '伊藤園',
      category: '水',
      tags: <String>['水'],
      searchKeywords: <String>['水', '天然水'],
    ),

    // キリン
    const Product(
      id: 'namacha',
      name: '生茶',
      manufacturer: 'キリン',
      category: 'お茶',
      tags: <String>['お茶', '無糖'],
      searchKeywords: <String>['なまちゃ'],
    ),
    const Product(
      id: 'gogo_milk',
      name: '午後の紅茶 ミルクティー',
      manufacturer: 'キリン',
      category: '紅茶',
      tags: <String>['紅茶', '甘い'],
      searchKeywords: <String>['午後ティー', 'ミルクティー'],
    ),
    const Product(
      id: 'gogo_straight',
      name: '午後の紅茶 ストレートティー',
      manufacturer: 'キリン',
      category: '紅茶',
      tags: <String>['紅茶', '甘い'],
      searchKeywords: <String>['午後ティー', 'ストレート'],
    ),
    const Product(
      id: 'gogo_unsweet',
      name: '午後の紅茶 おいしい無糖',
      manufacturer: 'キリン',
      category: '紅茶',
      tags: <String>['紅茶', '無糖'],
      searchKeywords: <String>['午後ティー', '無糖'],
    ),
    const Product(
      id: 'fire_black',
      name: 'FIRE ブラック',
      manufacturer: 'キリン',
      category: 'コーヒー',
      tags: <String>['コーヒー', '無糖', 'カフェイン'],
      searchKeywords: <String>['fire', 'ブラック'],
    ),
    const Product(
      id: 'kirin_lemon',
      name: 'キリンレモン',
      manufacturer: 'キリン',
      category: '炭酸',
      tags: <String>['炭酸', 'ジュース', '甘い'],
      searchKeywords: <String>['レモン'],
    ),

    // アサヒ
    const Product(
      id: 'wonda_morning',
      name: 'ワンダ モーニングショット',
      manufacturer: 'アサヒ',
      category: 'コーヒー',
      tags: <String>['コーヒー', '甘い', 'カフェイン'],
      searchKeywords: <String>['ワンダ', 'モーニングショット'],
    ),
    const Product(
      id: 'wonda_black',
      name: 'ワンダ ブラック',
      manufacturer: 'アサヒ',
      category: 'コーヒー',
      tags: <String>['コーヒー', '無糖', 'カフェイン'],
      searchKeywords: <String>['ワンダ', 'ブラック'],
    ),
    const Product(
      id: 'jurokucha',
      name: '十六茶',
      manufacturer: 'アサヒ',
      category: 'お茶',
      tags: <String>['お茶', '無糖'],
      searchKeywords: <String>['じゅうろくちゃ'],
    ),
    const Product(
      id: 'mitsuya_cider',
      name: '三ツ矢サイダー',
      manufacturer: 'アサヒ',
      category: '炭酸',
      tags: <String>['炭酸', '甘い'],
      searchKeywords: <String>['みつや', 'サイダー'],
    ),
    const Product(
      id: 'calpis_water',
      name: 'カルピスウォーター',
      manufacturer: 'アサヒ',
      category: 'ジュース',
      tags: <String>['ジュース', '甘い'],
      searchKeywords: <String>['カルピス'],
    ),
    const Product(
      id: 'dokodemin',
      name: 'ドデカミン',
      manufacturer: 'アサヒ',
      category: '炭酸',
      tags: <String>['炭酸', 'エナジー', '甘い'],
      searchKeywords: <String>['ドデカミン'],
    ),

    // ダイドー
    const Product(
      id: 'dydo_blend',
      name: 'ダイドーブレンド',
      manufacturer: 'ダイドー',
      category: 'コーヒー',
      tags: <String>['コーヒー', '甘い', 'カフェイン'],
      searchKeywords: <String>['ダイドー', 'ブレンド'],
    ),
    const Product(
      id: 'dydo_black',
      name: 'ダイドーブレンド ブラック',
      manufacturer: 'ダイドー',
      category: 'コーヒー',
      tags: <String>['コーヒー', '無糖', 'カフェイン'],
      searchKeywords: <String>['ダイドー', 'ブラック'],
    ),
    const Product(
      id: 'miu',
      name: 'miu',
      manufacturer: 'ダイドー',
      category: '水',
      tags: <String>['水'],
      searchKeywords: <String>['ミウ'],
    ),
    const Product(
      id: 'hanocha',
      name: '葉の茶',
      manufacturer: 'ダイドー',
      category: 'お茶',
      tags: <String>['お茶', '無糖'],
      searchKeywords: <String>['葉の茶'],
    ),

    // 大塚製薬
    const Product(
      id: 'pocari',
      name: 'ポカリスエット',
      manufacturer: '大塚製薬',
      category: 'スポーツドリンク',
      tags: <String>['スポーツ', 'スッキリ'],
      searchKeywords: <String>['ポカリ'],
    ),
    const Product(
      id: 'ion_water',
      name: 'ポカリスエット イオンウォーター',
      manufacturer: '大塚製薬',
      category: 'スポーツドリンク',
      tags: <String>['スポーツ', 'スッキリ'],
      searchKeywords: <String>['イオンウォーター'],
    ),
    const Product(
      id: 'match',
      name: 'MATCH',
      manufacturer: '大塚製薬',
      category: '炭酸',
      tags: <String>['炭酸', '甘い'],
      searchKeywords: <String>['マッチ'],
    ),
    const Product(
      id: 'oronamin_c',
      name: 'オロナミンC',
      manufacturer: '大塚製薬',
      category: '炭酸',
      tags: <String>['炭酸', 'エナジー', '甘い'],
      searchKeywords: <String>['オロナミン'],
    ),

    // AQUO
    const Product(
      id: 'aquo_water',
      name: '天然水',
      manufacturer: 'AQUO',
      category: '水',
      tags: <String>['水'],
      searchKeywords: <String>['天然水'],
    ),
    const Product(
      id: 'aquo_tea',
      name: 'お茶',
      manufacturer: 'AQUO',
      category: 'お茶',
      tags: <String>['お茶'],
      searchKeywords: <String>['緑茶'],
    ),
    const Product(
      id: 'aquo_coffee',
      name: 'コーヒー',
      manufacturer: 'AQUO',
      category: 'コーヒー',
      tags: <String>['コーヒー', 'カフェイン'],
      searchKeywords: <String>['ブラック', '微糖'],
    ),
  ];

  static List<Product> byManufacturer(String manufacturer) {
    if (manufacturer.trim().isEmpty || manufacturer == 'すべて') {
      return List<Product>.from(products);
    }

    return products
        .where((p) => p.manufacturer == manufacturer)
        .toList(growable: false);
  }

  static List<Product> search({
    String query = '',
    String manufacturer = 'すべて',
  }) {
    final base = byManufacturer(manufacturer);
    final normalized = _normalize(query);

    if (normalized.isEmpty) {
      return base;
    }

    return base.where((product) => product.matches(query)).toList(growable: false);
  }

  static Product? findById(String id) {
    final normalizedId = _normalize(id);
    try {
      return products.firstWhere((p) => _normalize(p.id) == normalizedId);
    } catch (_) {
      return null;
    }
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