abstract final class LegacyNameNormalizer {
  static String normalize(String input) {
    var value = input.trim().toLowerCase();
    if (value.isEmpty) {
      return '';
    }

    value = _toKatakana(value);
    value = _replaceWaveVariants(value);
    value = _replaceDashVariants(value);
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    value = value
        .replaceAll(RegExp(r'\s*・\s*'), '・')
        .replaceAll(RegExp(r'\s*/\s*'), '/')
        .replaceAll(RegExp(r'\s*-\s*'), '-');

    return value;
  }

  static String _replaceWaveVariants(String value) {
    return value
        .replaceAll('〜', '～')
        .replaceAll('∼', '～')
        .replaceAll('∾', '～')
        .replaceAll('~', '～');
  }

  static String _replaceDashVariants(String value) {
    return value
        .replaceAll('‐', '-')
        .replaceAll('‒', '-')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('―', '-');
  }

  static String _toKatakana(String input) {
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
