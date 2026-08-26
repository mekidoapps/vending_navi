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
    // -----------------------------------------------------------------
    // Phase 11 production master expansion - batch A
    // Current major products verified against manufacturer lineups.
    // -----------------------------------------------------------------

    // Coca-Cola
    _product(
      id: 'coca_cola_coca_cola_zero',
      name: 'コカ・コーラ ゼロ',
      manufacturerId: 'coca_cola',
      keywords: <String>[
        'コカコーラゼロ',
        'コークゼロ',
        'coca cola zero',
        'coca-cola zero',
        'coke zero',
      ],
      genres: <ProductGenre>[ProductGenre.carbonated],
    ),
    _product(
      id: 'coca_cola_coca_cola_zero_caffeine',
      name: 'コカ・コーラ ゼロカフェイン',
      manufacturerId: 'coca_cola',
      keywords: <String>[
        'コカコーラゼロカフェイン',
        'ゼロカフェイン',
        'coca cola zero caffeine',
        'coke zero caffeine',
      ],
      genres: <ProductGenre>[ProductGenre.carbonated],
    ),
    _product(
      id: 'coca_cola_coca_cola_plus',
      name: 'コカ・コーラ プラス',
      manufacturerId: 'coca_cola',
      keywords: <String>['コカコーラプラス', 'coca cola plus', 'coke plus'],
      genres: <ProductGenre>[ProductGenre.carbonated],
    ),
    _product(
      id: 'coca_cola_ayataka_mineral_green_tea',
      name: '綾鷹 ミネラル緑茶',
      manufacturerId: 'coca_cola',
      keywords: <String>[
        'あやたか ミネラル緑茶',
        'アヤタカ ミネラル緑茶',
        'ayataka mineral',
        'ミネラル緑茶',
      ],
      genres: <ProductGenre>[ProductGenre.tea, ProductGenre.greenTea],
    ),
    _product(
      id: 'coca_cola_ayataka_koi_hojicha',
      name: '綾鷹 濃いほうじ茶',
      manufacturerId: 'coca_cola',
      keywords: <String>['あやたか 濃いほうじ茶', 'アヤタカ 濃いほうじ茶', '綾鷹ほうじ茶', 'ほうじ茶'],
      genres: <ProductGenre>[ProductGenre.tea],
    ),
    _product(
      id: 'coca_cola_georgia_cafe_latte',
      name: 'ジョージア カフェラテ',
      manufacturerId: 'coca_cola',
      keywords: <String>['georgia cafe latte', 'ジョージアカフェラテ', 'カフェラテ'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'coca_cola_georgia_dark_roast_unsweetened_latte',
      name: 'ジョージア 深煎りラテ無糖',
      manufacturerId: 'coca_cola',
      keywords: <String>[
        'ジョージア深煎りラテ無糖',
        '深煎りラテ',
        '無糖ラテ',
        'georgia unsweetened latte',
      ],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'coca_cola_georgia_dark_roast_presso',
      name: 'ジョージア 深煎りプレッソ',
      manufacturerId: 'coca_cola',
      keywords: <String>['ジョージア深煎りプレッソ', '深煎りプレッソ', 'georgia presso'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'coca_cola_georgia_kaoru_bitou',
      name: 'ジョージア 香る微糖',
      manufacturerId: 'coca_cola',
      keywords: <String>['ジョージア香る微糖', '香る微糖', 'georgia bitou'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'coca_cola_georgia_zeitaku_milk_coffee',
      name: 'ジョージア 贅沢ミルクコーヒー',
      manufacturerId: 'coca_cola',
      keywords: <String>['ジョージア贅沢ミルクコーヒー', '贅沢ミルクコーヒー', 'georgia milk coffee'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'coca_cola_georgia_original',
      name: 'ジョージア オリジナル',
      manufacturerId: 'coca_cola',
      keywords: <String>['ジョージアオリジナル', 'georgia original'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'coca_cola_aquarius_the_zero',
      name: 'アクエリアス THE 0',
      manufacturerId: 'coca_cola',
      keywords: <String>[
        'アクエリアス ザ ゼロ',
        'アクエリアスゼロ',
        'aquarius the 0',
        'aquarius zero',
      ],
      genres: <ProductGenre>[ProductGenre.sportsDrink],
    ),
    _product(
      id: 'coca_cola_aquarius_vitamin',
      name: 'アクエリアス ビタミン',
      manufacturerId: 'coca_cola',
      keywords: <String>['アクエリアスビタミン', 'aquarius vitamin'],
      genres: <ProductGenre>[ProductGenre.sportsDrink],
    ),
    _product(
      id: 'coca_cola_aquarius_sparkling',
      name: 'アクエリアス スパークリング',
      manufacturerId: 'coca_cola',
      keywords: <String>['アクエリアススパークリング', 'aquarius sparkling'],
      genres: <ProductGenre>[ProductGenre.sportsDrink, ProductGenre.carbonated],
    ),
    _product(
      id: 'coca_cola_aquarius_newater',
      name: 'アクエリアス NEWATER',
      manufacturerId: 'coca_cola',
      keywords: <String>['アクエリアス ニューウォーター', 'ニューウォーター', 'aquarius newater'],
      genres: <ProductGenre>[ProductGenre.sportsDrink],
    ),

    // Suntory
    _product(
      id: 'suntory_boss_rainbow_mountain_blend',
      name: 'BOSS レインボーマウンテンブレンド',
      manufacturerId: 'suntory',
      keywords: <String>[
        'ボス レインボーマウンテンブレンド',
        'ボスレインボー',
        'rainbow mountain blend',
      ],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'suntory_boss_cafe_au_lait',
      name: 'BOSS カフェオレ',
      manufacturerId: 'suntory',
      keywords: <String>['ボス カフェオレ', 'ボスカフェオレ', 'boss cafe au lait'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'suntory_boss_silky_black',
      name: 'BOSS シルキーブラック',
      manufacturerId: 'suntory',
      keywords: <String>['ボス シルキーブラック', 'ボスシルキーブラック', 'boss silky black'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'suntory_boss_torokeru_cafe_au_lait',
      name: 'BOSS とろけるカフェオレ',
      manufacturerId: 'suntory',
      keywords: <String>['ボス とろけるカフェオレ', 'とろけるカフェオレ', 'boss torokeru'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'suntory_iemon_koi_aji',
      name: '伊右衛門 濃い味',
      manufacturerId: 'suntory',
      keywords: <String>['いえもん 濃い味', 'イエモン 濃い味', '伊右衛門濃い味', '濃い緑茶'],
      genres: <ProductGenre>[ProductGenre.tea, ProductGenre.greenTea],
    ),
    _product(
      id: 'suntory_iemon_tokucha',
      name: '伊右衛門 特茶',
      manufacturerId: 'suntory',
      keywords: <String>['いえもん 特茶', 'イエモン 特茶', '特茶', 'tokucha'],
      genres: <ProductGenre>[ProductGenre.tea, ProductGenre.greenTea],
    ),
    _product(
      id: 'suntory_iemon_hojicha',
      name: '伊右衛門 焙じ茶',
      manufacturerId: 'suntory',
      keywords: <String>['いえもん ほうじ茶', 'イエモン ほうじ茶', '伊右衛門ほうじ茶', '焙じ茶'],
      genres: <ProductGenre>[ProductGenre.tea],
    ),
    _product(
      id: 'suntory_iemon_genmaicha',
      name: '伊右衛門 玄米茶',
      manufacturerId: 'suntory',
      keywords: <String>['いえもん 玄米茶', 'イエモン 玄米茶', '伊右衛門玄米茶'],
      genres: <ProductGenre>[ProductGenre.tea],
    ),
    _product(
      id: 'suntory_iemon_kyoto_blend',
      name: '伊右衛門 京都ブレンド',
      manufacturerId: 'suntory',
      keywords: <String>['いえもん 京都ブレンド', 'イエモン 京都ブレンド', '京都ブレンド'],
      genres: <ProductGenre>[ProductGenre.tea],
    ),
    _product(
      id: 'suntory_pepsi_nama_big_zero',
      name: 'ペプシ〈生〉 BIG ZERO',
      manufacturerId: 'suntory',
      keywords: <String>['ペプシ 生 ゼロ', 'ペプシゼロ', 'pepsi nama zero', 'pepsi zero'],
      genres: <ProductGenre>[ProductGenre.carbonated],
    ),
    _product(
      id: 'suntory_dekavita_c',
      name: 'デカビタC',
      manufacturerId: 'suntory',
      keywords: <String>['デカビタ', 'dekavita c', 'dekavita'],
      genres: <ProductGenre>[ProductGenre.energyDrink, ProductGenre.carbonated],
    ),

    // ITO EN
    _product(
      id: 'ito_en_oi_ocha_koi_cha',
      name: 'お〜いお茶 濃い茶',
      manufacturerId: 'ito_en',
      keywords: <String>['おーいお茶 濃い茶', 'おいお茶 濃い茶', '濃い茶', 'oi ocha strong'],
      genres: <ProductGenre>[ProductGenre.tea, ProductGenre.greenTea],
    ),
    _product(
      id: 'ito_en_oi_ocha_koi_cha_premium_strong',
      name: 'お〜いお茶 濃い茶 PREMIUM STRONG',
      manufacturerId: 'ito_en',
      keywords: <String>[
        'おーいお茶 プレミアムストロング',
        '濃い茶 premium strong',
        '濃い茶 プレミアムストロング',
      ],
      genres: <ProductGenre>[ProductGenre.tea, ProductGenre.greenTea],
    ),
    _product(
      id: 'ito_en_oi_ocha_hojicha',
      name: 'お〜いお茶 ほうじ茶',
      manufacturerId: 'ito_en',
      keywords: <String>['おーいお茶 ほうじ茶', 'おいお茶 ほうじ茶', 'oi ocha hojicha'],
      genres: <ProductGenre>[ProductGenre.tea],
    ),
    _product(
      id: 'ito_en_oi_ocha_genmaicha',
      name: 'お〜いお茶 玄米茶',
      manufacturerId: 'ito_en',
      keywords: <String>['おーいお茶 玄米茶', 'おいお茶 玄米茶', 'oi ocha genmaicha'],
      genres: <ProductGenre>[ProductGenre.tea],
    ),
    _product(
      id: 'ito_en_oi_ocha_lemon_green',
      name: 'お〜いお茶 LEMON GREEN',
      manufacturerId: 'ito_en',
      keywords: <String>['おーいお茶 レモングリーン', 'レモングリーン', 'oi ocha lemon green'],
      genres: <ProductGenre>[ProductGenre.tea, ProductGenre.greenTea],
    ),
    _product(
      id: 'ito_en_oi_ocha_cold_brew_lemon_green',
      name: 'お〜いお茶 COLD BREW LEMON GREEN',
      manufacturerId: 'ito_en',
      keywords: <String>[
        'おーいお茶 コールドブリュー レモングリーン',
        'cold brew lemon green',
        'コールドブリューレモングリーン',
      ],
      genres: <ProductGenre>[ProductGenre.tea, ProductGenre.greenTea],
    ),
    _product(
      id: 'ito_en_tullys_baristas_black_kilimanjaro',
      name: "TULLY'S COFFEE BARISTA'S BLACK キリマンジャロ",
      manufacturerId: 'ito_en',
      keywords: <String>[
        'タリーズ ブラック キリマンジャロ',
        'タリーズコーヒー キリマンジャロ',
        'tullys black kilimanjaro',
      ],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'ito_en_tullys_unsweetened_latte',
      name: "TULLY'S COFFEE BARISTA'S 無糖LATTE",
      manufacturerId: 'ito_en',
      keywords: <String>[
        'タリーズ 無糖ラテ',
        'タリーズコーヒー 無糖ラテ',
        'tullys unsweetened latte',
      ],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),

    // Kirin
    _product(
      id: 'kirin_gogo_no_kocha_straight_tea',
      name: '午後の紅茶 ストレートティー',
      manufacturerId: 'kirin',
      keywords: <String>[
        '午後ティー ストレート',
        '午後の紅茶ストレートティー',
        'gogo no kocha straight tea',
      ],
      genres: <ProductGenre>[ProductGenre.tea],
    ),
    _product(
      id: 'kirin_gogo_no_kocha_lemon_tea',
      name: '午後の紅茶 レモンティー',
      manufacturerId: 'kirin',
      keywords: <String>['午後ティー レモン', '午後の紅茶レモンティー', 'gogo no kocha lemon tea'],
      genres: <ProductGenre>[ProductGenre.tea],
    ),
    _product(
      id: 'kirin_gogo_no_kocha_oishii_muto',
      name: '午後の紅茶 おいしい無糖',
      manufacturerId: 'kirin',
      keywords: <String>[
        '午後ティー 無糖',
        '午後の紅茶無糖',
        'おいしい無糖',
        'gogo no kocha unsweetened',
      ],
      genres: <ProductGenre>[ProductGenre.tea],
    ),
    _product(
      id: 'kirin_gogo_no_kocha_oishii_muto_lemon',
      name: '午後の紅茶 おいしい無糖 香るレモン',
      manufacturerId: 'kirin',
      keywords: <String>['午後ティー 無糖 レモン', 'おいしい無糖 レモン', '無糖 香るレモン'],
      genres: <ProductGenre>[ProductGenre.tea],
    ),
    _product(
      id: 'kirin_gogo_no_kocha_oishii_muto_milk',
      name: '午後の紅茶 おいしい無糖 ミルクティー',
      manufacturerId: 'kirin',
      keywords: <String>['午後ティー 無糖 ミルク', 'おいしい無糖 ミルクティー', '無糖ミルクティー'],
      genres: <ProductGenre>[ProductGenre.tea],
    ),
    // -----------------------------------------------------------------
    // Phase 11 production master expansion - batch B
    // Asahi / DyDo / Otsuka
    // -----------------------------------------------------------------

    // Asahi
    _product(
      id: 'asahi_mitsuya_cider_zero',
      name: '三ツ矢サイダーZERO',
      manufacturerId: 'asahi',
      keywords: <String>['三ツ矢サイダーゼロ', 'みつやサイダーゼロ', 'mitsuya cider zero'],
      genres: <ProductGenre>[ProductGenre.carbonated],
    ),
    _product(
      id: 'asahi_wonda_morning_shot',
      name: 'ワンダ モーニングショット',
      manufacturerId: 'asahi',
      keywords: <String>['ワンダモーニングショット', 'モーニングショット', 'wonda morning shot'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'asahi_wonda_black_the_aroma',
      name: 'ワンダ ブラック ザ アロマ',
      manufacturerId: 'asahi',
      keywords: <String>['ワンダブラックザアロマ', 'ブラックザアロマ', 'wonda black the aroma'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'asahi_wonda_kin_no_bitou',
      name: 'ワンダ 金の微糖',
      manufacturerId: 'asahi',
      keywords: <String>['ワンダ金の微糖', '金の微糖', 'wonda kin no bitou'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'asahi_wonda_tokusei_cafe_au_lait',
      name: 'ワンダ 特製カフェオレ',
      manufacturerId: 'asahi',
      keywords: <String>['ワンダ特製カフェオレ', '特製カフェオレ', 'wonda cafe au lait'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'asahi_wonda_koku_no_bitou',
      name: 'ワンダ コクの微糖',
      manufacturerId: 'asahi',
      keywords: <String>['ワンダコクの微糖', 'コクの微糖', 'wonda koku no bitou'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'asahi_wonda_koku_no_black',
      name: 'ワンダ コクのブラック',
      manufacturerId: 'asahi',
      keywords: <String>['ワンダコクのブラック', 'コクのブラック', 'wonda koku no black'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'asahi_jurokucha_mugicha',
      name: 'アサヒ 十六茶麦茶',
      manufacturerId: 'asahi',
      keywords: <String>['十六茶麦茶', 'じゅうろくちゃむぎちゃ', '16茶麦茶'],
      genres: <ProductGenre>[ProductGenre.tea],
    ),
    _product(
      id: 'asahi_wilkinson_tansan',
      name: 'ウィルキンソン タンサン',
      manufacturerId: 'asahi',
      keywords: <String>[
        'ウィルキンソン炭酸',
        'ウィルキンソン',
        'wilkinson tansan',
        'wilkinson',
      ],
      genres: <ProductGenre>[ProductGenre.carbonated],
    ),
    _product(
      id: 'asahi_dodekamin',
      name: 'アサヒ ドデカミン',
      manufacturerId: 'asahi',
      keywords: <String>['ドデカミン', 'dodekamin'],
      genres: <ProductGenre>[ProductGenre.energyDrink, ProductGenre.carbonated],
    ),

    // DyDo
    _product(
      id: 'dydo_blend_zeppin_black',
      name: 'ダイドーブレンド 絶品ブラック',
      manufacturerId: 'dydo',
      keywords: <String>['ダイドー絶品ブラック', '絶品ブラック', 'dydo zeppin black'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'dydo_blend_zeppin_bitou',
      name: 'ダイドーブレンド 絶品微糖',
      manufacturerId: 'dydo',
      keywords: <String>['ダイドー絶品微糖', '絶品微糖', 'dydo zeppin bitou'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'dydo_blend_zeppin_cafe_au_lait',
      name: 'ダイドーブレンド 絶品カフェオレ',
      manufacturerId: 'dydo',
      keywords: <String>['ダイドー絶品カフェオレ', '絶品カフェオレ', 'dydo zeppin cafe au lait'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'dydo_blend_demitasse_aroma_bitou',
      name: 'ダイドーブレンド デミタスアロマ微糖',
      manufacturerId: 'dydo',
      keywords: <String>['デミタスアロマ微糖', 'ダイドーデミタス', 'demitasse aroma'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'dydo_cafe_labo_black',
      name: 'ダイドーカフェラボ ブラック',
      manufacturerId: 'dydo',
      keywords: <String>['カフェラボブラック', 'ダイドーカフェラボ', 'dydo cafe labo black'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'dydo_cafe_labo_bitou',
      name: 'ダイドーカフェラボ 微糖',
      manufacturerId: 'dydo',
      keywords: <String>['カフェラボ微糖', 'dydo cafe labo bitou'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'dydo_cafe_labo_latte',
      name: 'ダイドーカフェラボ ラテ',
      manufacturerId: 'dydo',
      keywords: <String>['カフェラボラテ', 'dydo cafe labo latte'],
      genres: <ProductGenre>[ProductGenre.coffee],
    ),
    _product(
      id: 'dydo_miu_sports_charge',
      name: 'ミウ スポーツチャージ',
      manufacturerId: 'dydo',
      keywords: <String>['miu スポーツチャージ', 'ミウスポーツチャージ', 'miu sports charge'],
      genres: <ProductGenre>[ProductGenre.sportsDrink],
    ),
    _product(
      id: 'dydo_the_cola',
      name: 'ダイドー THE コーラ',
      manufacturerId: 'dydo',
      keywords: <String>['ダイドーザコーラ', 'ダイドーコーラ', 'dydo the cola', 'the cola'],
      genres: <ProductGenre>[ProductGenre.carbonated],
    ),
    _product(
      id: 'dydo_mistio_melon_squash',
      name: 'ミスティオ メロンスカッシュ',
      manufacturerId: 'dydo',
      keywords: <String>['ミスティオメロンスカッシュ', 'メロンスカッシュ', 'mistio melon squash'],
      genres: <ProductGenre>[ProductGenre.carbonated, ProductGenre.juice],
    ),
    _product(
      id: 'dydo_japan_delicious_natural_water',
      name: 'ダイドー 日本のおいしい天然水',
      manufacturerId: 'dydo',
      keywords: <String>['日本のおいしい天然水', 'ダイドー天然水', 'dydo natural water'],
      genres: <ProductGenre>[ProductGenre.water],
    ),

    // Otsuka
    _product(
      id: 'otsuka_pocari_sweat_ion_water',
      name: 'ポカリスエット イオンウォーター',
      manufacturerId: 'otsuka',
      keywords: <String>[
        'ポカリ イオンウォーター',
        'ポカリイオン',
        'pocari sweat ion water',
        'ion water',
      ],
      genres: <ProductGenre>[ProductGenre.sportsDrink],
    ),
    _product(
      id: 'otsuka_match_vitamin_mikan',
      name: 'MATCH ビタミンみかん',
      manufacturerId: 'otsuka',
      keywords: <String>['マッチ ビタミンみかん', 'マッチみかん', 'match vitamin mikan'],
      genres: <ProductGenre>[ProductGenre.sportsDrink, ProductGenre.carbonated],
    ),
    _product(
      id: 'otsuka_oronamin_c_royalpolis',
      name: 'オロナミンC ROYALPOLIS',
      manufacturerId: 'otsuka',
      keywords: <String>[
        'オロナミンc ロイヤルポリス',
        'オロナミンシー ロイヤルポリス',
        'ロイヤルポリス',
        'oronamin c royalpolis',
      ],
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
          presetProductIds: <String>[
            'coca_cola_coca_cola',
            'coca_cola_ayataka',
            'coca_cola_irohas',
            'coca_cola_georgia_black',
            'coca_cola_fanta_grape',
            'coca_cola_aquarius',
          ],
        ),
        _manufacturer(
          id: 'suntory',
          name: 'サントリー',
          shortName: 'サントリー',
          keywords: <String>['suntory'],
          presetProductIds: <String>[
            'suntory_boss_black',
            'suntory_iemon',
            'suntory_cc_lemon',
            'suntory_tennensui',
            'suntory_green_dakara',
          ],
        ),
        _manufacturer(
          id: 'ito_en',
          name: '伊藤園',
          shortName: '伊藤園',
          keywords: <String>['ito en', 'itoen'],
          presetProductIds: <String>[
            'ito_en_oi_ocha_green_tea',
            'ito_en_kenko_mineral_mugicha',
            'ito_en_tullys_coffee_black',
            'ito_en_japanese_water',
            'ito_en_jyujitsu_yasai',
          ],
        ),
        _manufacturer(
          id: 'kirin',
          name: 'キリン',
          shortName: 'キリン',
          keywords: <String>['キリンビバレッジ', 'kirin'],
          presetProductIds: <String>[
            'kirin_gogo_no_kocha_milk_tea',
            'kirin_namacha',
            'kirin_fire_black',
            'kirin_kirin_lemon',
            'kirin_alkali_ion_water',
          ],
        ),
        _manufacturer(
          id: 'asahi',
          name: 'アサヒ',
          shortName: 'アサヒ',
          keywords: <String>['アサヒ飲料', 'asahi'],
          presetProductIds: <String>[
            'asahi_wonda_black',
            'asahi_jurokucha',
            'asahi_mitsuya_cider',
            'asahi_calpis',
            'asahi_calpis_water',
            'asahi_oishii_mizu',
          ],
        ),
        _manufacturer(
          id: 'dydo',
          name: 'ダイドー',
          shortName: 'ダイドー',
          keywords: <String>['ダイドードリンコ', 'dydo'],
          presetProductIds: <String>[
            'dydo_dydo_blend',
            'dydo_miu',
            'dydo_ha_no_cha',
          ],
        ),
        _manufacturer(
          id: 'otsuka',
          name: '大塚製薬',
          shortName: '大塚',
          keywords: <String>['大塚', 'otsuka'],
          presetProductIds: <String>[
            'otsuka_pocari_sweat',
            'otsuka_match',
            'otsuka_oronamin_c',
          ],
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
    required List<String> presetProductIds,
  }) {
    final manufacturerId = ManufacturerId.parse(id);
    final resolvedPresetIds = <ProductId>[];
    final seen = <ProductId>{};

    for (final rawProductId in presetProductIds) {
      final productId = ProductId.parse(rawProductId);

      final matchingProducts = products
          .where((product) => product.id == productId)
          .toList(growable: false);

      if (matchingProducts.length != 1) {
        throw StateError(
          'Preset product must exist exactly once: $rawProductId',
        );
      }

      if (matchingProducts.single.manufacturerId != manufacturerId) {
        throw StateError('Preset product manufacturer mismatch: $rawProductId');
      }

      if (!seen.add(productId)) {
        throw StateError('Duplicate preset product: $rawProductId');
      }

      resolvedPresetIds.add(productId);
    }

    return Manufacturer(
      id: manufacturerId,
      name: name,
      displayShortName: shortName,
      searchKeywords: List<String>.unmodifiable(keywords),
      presetProductIds: List<ProductId>.unmodifiable(resolvedPresetIds),
      createdAt: fixtureTimestamp,
      updatedAt: fixtureTimestamp,
    );
  }
}
