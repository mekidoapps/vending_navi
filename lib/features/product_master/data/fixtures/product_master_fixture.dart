import '../../domain/entities/manufacturer.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_genre.dart';
import '../../domain/value_objects/master_id.dart';

abstract final class ProductMasterFixture {
  static final DateTime fixtureTimestamp = DateTime.utc(2026, 8, 7);

  static final List<Product> products = List<Product>.unmodifiable(<Product>[
    _product(
      id: 'coca_cola_coca_cola',
      name: 'コカ・コーラ',
      manufacturerId: 'coca_cola',
      keywords: <String>['コカコーラ', 'coca cola', 'coca-cola', 'コーラ'],
      genres: <ProductGenre>[ProductGenre.carbonated],
    ),
    _product(
      id: 'coca_cola_ayataka',
      name: '綾鷹',
      manufacturerId: 'coca_cola',
      keywords: <String>['あやたか', 'ayataka'],
      genres: <ProductGenre>[ProductGenre.tea, ProductGenre.greenTea],
    ),
    _product(
      id: 'coca_cola_irohas',
      name: 'い・ろ・は・す',
      manufacturerId: 'coca_cola',
      keywords: <String>['いろはす', 'irohas', 'i lohas'],
      genres: <ProductGenre>[ProductGenre.water],
    ),
    _product(
      id: 'coca_cola_georgia_black',
      name: 'ジョージア ブラック',
      manufacturerId: 'coca_cola',
      keywords: <String>['georgia black', 'ジョージアブラック'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'coca_cola_fanta_grape',
      name: 'ファンタ グレープ',
      manufacturerId: 'coca_cola',
      keywords: <String>['ファンタグレープ', 'fanta grape'],
      genres: <ProductGenre>[ProductGenre.carbonated, ProductGenre.juice],
    ),
    _product(
      id: 'coca_cola_aquarius',
      name: 'アクエリアス',
      manufacturerId: 'coca_cola',
      keywords: <String>['aquarius'],
      genres: <ProductGenre>[ProductGenre.sportsDrink],
    ),
    _product(
      id: 'suntory_boss_black',
      name: 'BOSS ブラック',
      manufacturerId: 'suntory',
      keywords: <String>['boss black', 'ボス ブラック', 'ボスブラック'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'suntory_iemon',
      name: '伊右衛門',
      manufacturerId: 'suntory',
      keywords: <String>['いえもん', 'iemon'],
      genres: <ProductGenre>[ProductGenre.tea, ProductGenre.greenTea],
    ),
    _product(
      id: 'suntory_cc_lemon',
      name: 'C.C.レモン',
      manufacturerId: 'suntory',
      keywords: <String>['ccレモン', 'c.c. lemon', 'cc lemon'],
      genres: <ProductGenre>[ProductGenre.carbonated, ProductGenre.juice],
    ),
    _product(
      id: 'suntory_tennensui',
      name: 'サントリー天然水',
      manufacturerId: 'suntory',
      keywords: <String>['天然水', 'サントリー 天然水'],
      genres: <ProductGenre>[ProductGenre.water],
    ),
    _product(
      id: 'suntory_green_dakara',
      name: 'GREEN DA・KA・RA',
      manufacturerId: 'suntory',
      keywords: <String>['グリーンダカラ', 'green dakara', 'ダカラ'],
      genres: <ProductGenre>[ProductGenre.sportsDrink],
    ),
    _product(
      id: 'ito_en_oi_ocha_green_tea',
      name: 'お〜いお茶 緑茶',
      manufacturerId: 'ito_en',
      keywords: <String>['おーいお茶', 'お〜いお茶', 'おいお茶', 'oi ocha'],
      genres: <ProductGenre>[ProductGenre.tea, ProductGenre.greenTea],
    ),
    _product(
      id: 'ito_en_kenko_mineral_mugicha',
      name: '健康ミネラルむぎ茶',
      manufacturerId: 'ito_en',
      keywords: <String>['健康ミネラル麦茶', 'むぎ茶', '麦茶'],
      genres: <ProductGenre>[ProductGenre.tea],
    ),
    _product(
      id: 'ito_en_tullys_coffee_black',
      name: "TULLY'S COFFEE ブラック",
      manufacturerId: 'ito_en',
      keywords: <String>[
        'タリーズコーヒー ブラック',
        'tullys coffee black',
        "tully's coffee black",
      ],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'ito_en_japanese_water',
      name: '磨かれて、澄みきった日本の水',
      manufacturerId: 'ito_en',
      keywords: <String>['日本の水', '磨かれて澄みきった日本の水'],
      genres: <ProductGenre>[ProductGenre.water],
    ),
    _product(
      id: 'ito_en_jyujitsu_yasai',
      name: '充実野菜',
      manufacturerId: 'ito_en',
      keywords: <String>['じゅうじつやさい'],
      genres: <ProductGenre>[ProductGenre.juice],
    ),
    _product(
      id: 'kirin_gogo_no_kocha_milk_tea',
      name: '午後の紅茶 ミルクティー',
      manufacturerId: 'kirin',
      keywords: <String>['午後ティー ミルクティー', '午後の紅茶ミルクティー'],
      genres: <ProductGenre>[ProductGenre.tea],
    ),
    _product(
      id: 'kirin_namacha',
      name: '生茶',
      manufacturerId: 'kirin',
      keywords: <String>['なまちゃ', 'namacha'],
      genres: <ProductGenre>[ProductGenre.tea, ProductGenre.greenTea],
    ),
    _product(
      id: 'kirin_fire_black',
      name: 'FIRE ブラック',
      manufacturerId: 'kirin',
      keywords: <String>['fire black', 'ファイア ブラック', 'ファイアブラック'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'kirin_kirin_lemon',
      name: 'キリンレモン',
      manufacturerId: 'kirin',
      keywords: <String>['kirin lemon'],
      genres: <ProductGenre>[ProductGenre.carbonated],
    ),
    _product(
      id: 'kirin_alkali_ion_water',
      name: 'アルカリイオンの水',
      manufacturerId: 'kirin',
      keywords: <String>['アルカリイオン水'],
      genres: <ProductGenre>[ProductGenre.water],
    ),
    _product(
      id: 'asahi_wonda_black',
      name: 'ワンダ ブラック',
      manufacturerId: 'asahi',
      keywords: <String>['wonda black', 'ワンダブラック'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'asahi_jurokucha',
      name: '十六茶',
      manufacturerId: 'asahi',
      keywords: <String>['16茶', 'じゅうろくちゃ'],
      genres: <ProductGenre>[ProductGenre.tea],
    ),
    _product(
      id: 'asahi_mitsuya_cider',
      name: '三ツ矢サイダー',
      manufacturerId: 'asahi',
      keywords: <String>['三ツ矢', 'みつやサイダー', 'mitsuya cider'],
      genres: <ProductGenre>[ProductGenre.carbonated],
    ),
    _product(
      id: 'asahi_calpis',
      name: 'カルピス',
      manufacturerId: 'asahi',
      keywords: <String>['calpis'],
      genres: <ProductGenre>[ProductGenre.juice],
    ),
    _product(
      id: 'asahi_calpis_water',
      name: 'カルピスウォーター',
      manufacturerId: 'asahi',
      keywords: <String>['calpis water', 'カルピス ウォーター'],
      genres: <ProductGenre>[ProductGenre.juice],
    ),
    _product(
      id: 'asahi_oishii_mizu',
      name: 'おいしい水',
      manufacturerId: 'asahi',
      keywords: <String>['おいしい水 天然水', 'アサヒ おいしい水'],
      genres: <ProductGenre>[ProductGenre.water],
    ),
    _product(
      id: 'dydo_dydo_blend',
      name: 'ダイドーブレンド',
      manufacturerId: 'dydo',
      keywords: <String>['ダイドー ブレンド', 'dydo blend'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'dydo_miu',
      name: 'miu',
      manufacturerId: 'dydo',
      keywords: <String>['ミウ', 'ミュー'],
      genres: <ProductGenre>[ProductGenre.water],
    ),
    _product(
      id: 'dydo_ha_no_cha',
      name: '葉の茶',
      manufacturerId: 'dydo',
      keywords: <String>['葉のちゃ', 'はの茶'],
      genres: <ProductGenre>[ProductGenre.tea],
    ),
    _product(
      id: 'otsuka_pocari_sweat',
      name: 'ポカリスエット',
      manufacturerId: 'otsuka',
      keywords: <String>['ポカリ', 'pocari sweat', 'pocari'],
      genres: <ProductGenre>[ProductGenre.sportsDrink],
    ),
    _product(
      id: 'otsuka_match',
      name: 'MATCH',
      manufacturerId: 'otsuka',
      keywords: <String>['マッチ'],
      genres: <ProductGenre>[ProductGenre.sportsDrink, ProductGenre.carbonated],
    ),
    _product(
      id: 'otsuka_oronamin_c',
      name: 'オロナミンC',
      manufacturerId: 'otsuka',
      keywords: <String>['オロナミンc', 'oronamin c'],
      genres: <ProductGenre>[ProductGenre.energyDrink, ProductGenre.carbonated],
    ),
  ]);

  static final List<Manufacturer> manufacturers =
      List<Manufacturer>.unmodifiable(<Manufacturer>[
        _manufacturer(
          id: 'coca_cola',
          name: 'コカ・コーラ',
          shortName: 'コカ・コーラ',
          keywords: <String>['コカコーラ', 'coca cola', 'coca-cola'],
        ),
        _manufacturer(
          id: 'suntory',
          name: 'サントリー',
          shortName: 'サントリー',
          keywords: <String>['suntory'],
        ),
        _manufacturer(
          id: 'ito_en',
          name: '伊藤園',
          shortName: '伊藤園',
          keywords: <String>['ito en', 'itoen'],
        ),
        _manufacturer(
          id: 'kirin',
          name: 'キリン',
          shortName: 'キリン',
          keywords: <String>['キリンビバレッジ', 'kirin'],
        ),
        _manufacturer(
          id: 'asahi',
          name: 'アサヒ',
          shortName: 'アサヒ',
          keywords: <String>['アサヒ飲料', 'asahi'],
        ),
        _manufacturer(
          id: 'dydo',
          name: 'ダイドー',
          shortName: 'ダイドー',
          keywords: <String>['ダイドードリンコ', 'dydo'],
        ),
        _manufacturer(
          id: 'otsuka',
          name: '大塚製薬',
          shortName: '大塚',
          keywords: <String>['大塚', 'otsuka'],
        ),
      ]);

  static Product _product({
    required String id,
    required String name,
    required String manufacturerId,
    required List<String> keywords,
    required List<ProductGenre> genres,
  }) {
    return Product(
      id: ProductId.parse(id),
      name: name,
      manufacturerId: ManufacturerId.parse(manufacturerId),
      searchKeywords: List<String>.unmodifiable(keywords),
      genres: List<ProductGenre>.unmodifiable(genres),
      createdAt: fixtureTimestamp,
      updatedAt: fixtureTimestamp,
    );
  }

  static Manufacturer _manufacturer({
    required String id,
    required String name,
    required String shortName,
    required List<String> keywords,
  }) {
    final manufacturerId = ManufacturerId.parse(id);
    final presetProductIds = products
        .where((product) => product.manufacturerId == manufacturerId)
        .map((product) => product.id)
        .toList(growable: false);

    return Manufacturer(
      id: manufacturerId,
      name: name,
      displayShortName: shortName,
      searchKeywords: List<String>.unmodifiable(keywords),
      presetProductIds: List<ProductId>.unmodifiable(presetProductIds),
      createdAt: fixtureTimestamp,
      updatedAt: fixtureTimestamp,
    );
  }
}
