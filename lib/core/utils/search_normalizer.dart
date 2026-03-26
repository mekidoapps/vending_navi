class SearchNormalizer {
  SearchNormalizer._();

  static String normalize(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll('　', ' ')
        .replaceAll('〜', 'ー')
        .replaceAll('～', 'ー')
        .replaceAll('―', 'ー')
        .replaceAll('‐', '-')
        .replaceAll('－', '-')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool containsNormalized({
    required String source,
    required String query,
  }) {
    final String normalizedSource = normalize(source);
    final String normalizedQuery = normalize(query);

    if (normalizedQuery.isEmpty) {
      return true;
    }

    return normalizedSource.contains(normalizedQuery);
  }
}