class SearchTokenUtil {
  static List<String> generate({
    required List<String> products,
    required List<String?> drinkSlots,
  }) {
    final Set<String> tokens = {};

    void add(String text) {
      final t = text.trim();
      if (t.isEmpty) return;

      tokens.add(t);

      /// 簡易カテゴリ分解（最低限）
      if (t.contains('お茶')) tokens.add('お茶');
      if (t.contains('コーヒー')) tokens.add('コーヒー');
      if (t.contains('ブラック')) tokens.add('ブラック');
      if (t.contains('無糖')) tokens.add('無糖');
      if (t.contains('炭酸')) tokens.add('炭酸');
      if (t.contains('水')) tokens.add('水');
    }

    for (final p in products) {
      add(p);
    }

    for (final s in drinkSlots) {
      if (s != null) add(s);
    }

    return tokens.toList();
  }
}