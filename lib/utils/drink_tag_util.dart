class DrinkTagUtil {
  static List<String> getTags(String name) {
    final n = name.toLowerCase();

    final tags = <String>[];

    if (_contains(n, ['茶', 'お茶', '綾鷹', '伊右衛門'])) {
      tags.add('お茶');
    }
    if (_contains(n, ['コーヒー', 'boss', 'ジョージア'])) {
      tags.add('コーヒー');
    }
    if (_contains(n, ['炭酸', 'コーラ', 'サイダー', 'スプライト'])) {
      tags.add('炭酸');
    }
    if (_contains(n, ['水', 'いろはす', '天然水'])) {
      tags.add('水');
    }
    if (_contains(n, ['スポーツ', 'ポカリ', 'アクエリアス'])) {
      tags.add('スポーツ');
    }
    if (_contains(n, ['ジュース', 'オレンジ', 'アップル'])) {
      tags.add('ジュース');
    }

    if (tags.isEmpty) {
      tags.add('その他');
    }

    return tags;
  }

  static bool _contains(String text, List<String> keys) {
    return keys.any((k) => text.contains(k.toLowerCase()));
  }
}