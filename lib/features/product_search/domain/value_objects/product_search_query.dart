final class ProductSearchQuery {
  ProductSearchQuery(this.rawText)
    : trimmedText = rawText.trim(),
      normalizedText = ProductSearchNormalizer.normalize(rawText);

  final String rawText;
  final String trimmedText;
  final String normalizedText;

  bool get isEmpty => normalizedText.isEmpty;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ProductSearchQuery &&
            other.trimmedText == trimmedText &&
            other.normalizedText == normalizedText;
  }

  @override
  int get hashCode => Object.hash(trimmedText, normalizedText);

  @override
  String toString() => 'ProductSearchQuery(length: ${trimmedText.length})';
}

abstract final class ProductSearchNormalizer {
  static final RegExp _separatorPattern = RegExp(
    r'''[\s\u3000・･._\-‐-‒–—―/'"“”]+''',
  );

  static String normalize(String value) {
    if (value.trim().isEmpty) {
      return '';
    }

    var normalized = _normalizeWidth(value);
    normalized = _toKatakana(normalized);
    normalized = _normalizeWave(normalized);
    normalized = normalized.toLowerCase();
    normalized = normalized.replaceAll(_separatorPattern, '');

    return normalized;
  }

  /// 全角ASCII（ＡＢＣ１２３等）を半角へ変換する。
  ///
  /// 日本語文字そのものは変更しない。
  static String _normalizeWidth(String input) {
    final buffer = StringBuffer();

    for (final rune in input.runes) {
      if (rune == 0x3000) {
        buffer.write(' ');
      } else if (rune >= 0xFF01 && rune <= 0xFF5E) {
        buffer.writeCharCode(rune - 0xFEE0);
      } else {
        buffer.writeCharCode(rune);
      }
    }

    return buffer.toString();
  }

  /// 検索時はひらがな・カタカナを同一視する。
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

  /// 「お〜い」「お～い」「おーい」を同じ検索文字列として扱う。
  static String _normalizeWave(String input) {
    return input
        .replaceAll('〜', 'ー')
        .replaceAll('～', 'ー')
        .replaceAll('∼', 'ー')
        .replaceAll('∾', 'ー')
        .replaceAll('~', 'ー');
  }
}
