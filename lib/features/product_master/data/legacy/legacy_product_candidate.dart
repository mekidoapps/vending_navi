enum LegacyProductSource { products, drinkSlots, slots, drinks }

final class LegacyProductCandidate {
  const LegacyProductCandidate({
    required this.rawName,
    required this.source,
    this.explicitProductId,
    this.tags = const <String>[],
    this.isSoldOut = false,
  });

  final String rawName;
  final String? explicitProductId;
  final List<String> tags;
  final bool isSoldOut;
  final LegacyProductSource source;
}
