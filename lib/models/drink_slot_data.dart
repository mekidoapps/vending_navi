class DrinkSlotData {
  final String? name;
  final List<String> tags;
  final bool isSoldOut;

  const DrinkSlotData({
    this.name,
    this.tags = const <String>[],
    this.isSoldOut = false,
  });

  bool get hasName => (name?.trim().isNotEmpty ?? false);

  DrinkSlotData copyWith({
    String? name,
    List<String>? tags,
    bool? isSoldOut,
  }) {
    return DrinkSlotData(
      name: name ?? this.name,
      tags: tags ?? this.tags,
      isSoldOut: isSoldOut ?? this.isSoldOut,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'tags': tags,
      'isSoldOut': isSoldOut,
    };
  }

  factory DrinkSlotData.fromMap(Map<String, dynamic> map) {
    return DrinkSlotData(
      name: map['name']?.toString().trim().isEmpty ?? true
          ? null
          : map['name'].toString().trim(),
      tags: (map['tags'] is List)
          ? (map['tags'] as List)
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : const <String>[],
      isSoldOut: map['isSoldOut'] == true,
    );
  }
}