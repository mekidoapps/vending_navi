List<String> normalizeMasterStrings(Iterable<String> values) {
  final seen = <String>{};
  final normalized = <String>[];

  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty && seen.add(trimmed)) {
      normalized.add(trimmed);
    }
  }

  return List<String>.unmodifiable(normalized);
}

String? normalizeOptionalMasterString(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}
