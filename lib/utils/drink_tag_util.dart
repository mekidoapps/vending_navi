class DrinkTagUtil {
  const DrinkTagUtil._();

  static List<String> guessTags(String name) {
    final value = _normalize(name);
    final tags = <String>{};

    if (_isTea(value)) tags.add('お茶');
    if (_isCoffee(value)) tags.add('コーヒー');
    if (_isCarbonated(value)) tags.add('炭酸');
    if (_isWater(value)) tags.add('水');
    if (_isJuice(value)) tags.add('ジュース');
    if (_isHotDrink(value)) tags.add('ホット');
    if (_isFunctionalDrink(value)) tags.add('機能性');

    if (_isTea(value) || _isWater(value) || _isHydrationDrink(value)) {
      tags.add('スッキリ');
    }

    if (_isJuice(value) || _isCarbonated(value) || _isSweetDrink(value)) {
      tags.add('甘い');
    }

    if (_isCoffee(value)) {
      tags.add('眠気覚まし');
      tags.add('カフェイン');
    }

    if (_isCaffeinatedEnergyLike(value)) {
      tags.add('眠気覚まし');
      tags.add('カフェイン');
    }

    if (_isHotDrink(value)) {
      tags.add('あたたまりたい');
    }

    if (value.contains('無糖')) tags.add('無糖');
    if (value.contains('微糖')) tags.add('微糖');
    if (value.contains('加糖') || _looksSugary(value)) tags.add('加糖');

    final result = tags.toList()..sort();
    return result;
  }

  static String normalize(String input) => _normalize(input);

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

  static bool _isTea(String value) {
    return value.contains('茶') ||
        value.contains('綾鷹') ||
        value.contains('伊右衛門') ||
        value.contains('おーいお茶') ||
        value.contains('お〜いお茶') ||
        value.contains('生茶') ||
        value.contains('爽健美茶') ||
        value.contains('十六茶') ||
        value.contains('むぎ茶') ||
        value.contains('ジャスミン') ||
        value.contains('葉の茶');
  }

  static bool _isCoffee(String value) {
    return value.contains('boss') ||
        value.contains('coffee') ||
        value.contains('コーヒー') ||
        value.contains('ジョージア') ||
        value.contains('georgia') ||
        value.contains('wonda') ||
        value.contains('ワンダ') ||
        value.contains('fire') ||
        value.contains('ダイドーブレンド') ||
        value.contains('デミタス') ||
        value.contains('tully') ||
        value.contains('ブラック');
  }

  static bool _isCarbonated(String value) {
    return value.contains('コーラ') ||
        value.contains('cola') ||
        value.contains('サイダー') ||
        value.contains('ペプシ') ||
        value.contains('炭酸') ||
        value.contains('ファンタ') ||
        value.contains('キリンレモン') ||
        value.contains('スカッシュ') ||
        value.contains('オロナミンc') ||
        value.contains('match');
  }

  static bool _isWater(String value) {
    return value.contains('天然水') ||
        value.contains('いろはす') ||
        value.contains('water') ||
        value == '水' ||
        value.contains('ミネラルウォーター') ||
        value.contains('evian') ||
        value.contains('miu') ||
        value.contains('イオンウォーター');
  }

  static bool _isJuice(String value) {
    return value.contains('ジュース') ||
        value.contains('なっちゃん') ||
        value.contains('カルピス') ||
        value.contains('オレンジ') ||
        value.contains('アップル') ||
        value.contains('りんご') ||
        value.contains('ぶどう') ||
        value.contains('グレープ') ||
        value.contains('qoo') ||
        value.contains('バヤリース') ||
        value.contains('小岩井');
  }

  static bool _isHotDrink(String value) {
    return value.contains('ホット') ||
        value.contains('hot') ||
        value.contains('温');
  }

  static bool _isFunctionalDrink(String value) {
    return value.contains('ポカリ') ||
        value.contains('イオンウォーター') ||
        value.contains('ボディメンテ') ||
        value.contains('エネルゲン') ||
        value.contains('オロナミンc') ||
        value.contains('match');
  }

  static bool _isHydrationDrink(String value) {
    return value.contains('ポカリ') ||
        value.contains('イオンウォーター') ||
        value.contains('アクエリアス') ||
        value.contains('ボディメンテ') ||
        value.contains('エネルゲン');
  }

  static bool _isSweetDrink(String value) {
    return value.contains('オロナミンc') ||
        value.contains('match') ||
        value.contains('カルピス') ||
        value.contains('なっちゃん');
  }

  static bool _isCaffeinatedEnergyLike(String value) {
    return value.contains('match');
  }

  static bool _looksSugary(String value) {
    return value.contains('ラテ') ||
        value.contains('カフェオレ') ||
        value.contains('オレ') ||
        value.contains('ミルク') ||
        value.contains('甘');
  }
}