class DrinkNameNormalizer {
  DrinkNameNormalizer._();

  static String normalize(String input) {
    var s = input.trim().toLowerCase();

    if (s.isEmpty) return '';

    s = _toZenkakuKatakana(s);
    s = _replaceWaveVariants(s);
    s = _replaceDashVariants(s);
    s = _collapseSpaces(s);
    s = _removeDecorativeSpacesAroundSymbols(s);

    return s;
  }

  static bool equalsLoosely(String a, String b) {
    return normalize(a) == normalize(b);
  }

  static bool containsLoosely(String source, String query) {
    final normalizedSource = normalize(source);
    final normalizedQuery = normalize(query);

    if (normalizedQuery.isEmpty) return true;
    return normalizedSource.contains(normalizedQuery);
  }

  static String _replaceWaveVariants(String s) {
    return s
        .replaceAll('〜', '～')
        .replaceAll('∼', '～')
        .replaceAll('∾', '～')
        .replaceAll('~', '～');
  }

  static String _replaceDashVariants(String s) {
    return s
        .replaceAll('‐', '-')
        .replaceAll('-', '-')
        .replaceAll('‒', '-')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('―', '-');
  }

  static String _collapseSpaces(String s) {
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _removeDecorativeSpacesAroundSymbols(String s) {
    return s
        .replaceAll(RegExp(r'\s*・\s*'), '・')
        .replaceAll(RegExp(r'\s*/\s*'), '/')
        .replaceAll(RegExp(r'\s*-\s*'), '-');
  }

  static String _toZenkakuKatakana(String input) {
    final buffer = StringBuffer();

    for (final rune in input.runes) {
      if (rune >= 0x3041 && rune <= 0x3096) {
        buffer.writeCharCode(rune + 0x60);
      } else {
        buffer.writeCharCode(rune);
      }
    }

    return buffer.toString();
  }
}