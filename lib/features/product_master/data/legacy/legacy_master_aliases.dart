import '../../domain/value_objects/master_id.dart';

abstract final class LegacyMasterAliases {
  static final Map<String, ManufacturerId> manufacturerAliases =
      Map<String, ManufacturerId>.unmodifiable(<String, ManufacturerId>{
        'コカコーラ': ManufacturerId.parse('coca_cola'),
        'Coca-Cola': ManufacturerId.parse('coca_cola'),
        'Coca Cola': ManufacturerId.parse('coca_cola'),
        'サントリー': ManufacturerId.parse('suntory'),
        'Suntory': ManufacturerId.parse('suntory'),
        '伊藤園': ManufacturerId.parse('ito_en'),
        'ITO EN': ManufacturerId.parse('ito_en'),
        'キリン': ManufacturerId.parse('kirin'),
        'キリンビバレッジ': ManufacturerId.parse('kirin'),
        'アサヒ': ManufacturerId.parse('asahi'),
        'アサヒ飲料': ManufacturerId.parse('asahi'),
        'ダイドー': ManufacturerId.parse('dydo'),
        'ダイドードリンコ': ManufacturerId.parse('dydo'),
        'DyDo': ManufacturerId.parse('dydo'),
        '大塚': ManufacturerId.parse('otsuka'),
        '大塚製薬': ManufacturerId.parse('otsuka'),
      });

  static final Map<String, ProductId> productAliases =
      Map<String, ProductId>.unmodifiable(<String, ProductId>{
        'コカコーラ': ProductId.parse('coca_cola_coca_cola'),
        'いろはす': ProductId.parse('coca_cola_irohas'),
        'ジョージアブラック': ProductId.parse('coca_cola_georgia_black'),
        'ファンタグレープ': ProductId.parse('coca_cola_fanta_grape'),
        'ボス ブラック': ProductId.parse('suntory_boss_black'),
        'ボスブラック': ProductId.parse('suntory_boss_black'),
        'サントリー|天然水': ProductId.parse('suntory_tennensui'),
        'グリーンダカラ': ProductId.parse('suntory_green_dakara'),
        'おーいお茶': ProductId.parse('ito_en_oi_ocha_green_tea'),
        'お〜いお茶': ProductId.parse('ito_en_oi_ocha_green_tea'),
        '健康ミネラル麦茶': ProductId.parse('ito_en_kenko_mineral_mugicha'),
        'タリーズコーヒー ブラック': ProductId.parse('ito_en_tullys_coffee_black'),
        '午後の紅茶ミルクティー': ProductId.parse('kirin_gogo_no_kocha_milk_tea'),
        'ファイア ブラック': ProductId.parse('kirin_fire_black'),
        'ファイアブラック': ProductId.parse('kirin_fire_black'),
        'アルカリイオン水': ProductId.parse('kirin_alkali_ion_water'),
        'ワンダブラック': ProductId.parse('asahi_wonda_black'),
        '三ツ矢': ProductId.parse('asahi_mitsuya_cider'),
        'おいしい水 天然水': ProductId.parse('asahi_oishii_mizu'),
        'カルピス ウォーター': ProductId.parse('asahi_calpis_water'),
        'ダイドー ブレンド': ProductId.parse('dydo_dydo_blend'),
        'ポカリ': ProductId.parse('otsuka_pocari_sweat'),
        'オロナミンc': ProductId.parse('otsuka_oronamin_c'),
      });
}
