class Product {
  const Product({
    required this.id,
    required this.name,
    required this.manufacturer,
    required this.category,
    this.tags = const <String>[],
    this.searchKeywords = const <String>[],
  });

  final String id;
  final String name;
  final String manufacturer;
  final String category;
  final List<String> tags;
  final List<String> searchKeywords;

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: (map['id'] ?? '').toString().trim(),
      name: (map['name'] ?? '').toString().trim(),
      manufacturer: (map['manufacturer'] ?? '').toString().trim(),
      category: (map['category'] ?? '').toString().trim(),
      tags: _readStringList(map['tags']),
      searchKeywords: _readStringList(map['searchKeywords']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'manufacturer': manufacturer,
      'category': category,
      'tags': tags,
      'searchKeywords': searchKeywords,
    };
  }

  bool matches(String query) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) return true;

    if (_normalize(id).contains(normalizedQuery)) return true;
    if (_normalize(name).contains(normalizedQuery)) return true;
    if (_normalize(manufacturer).contains(normalizedQuery)) return true;
    if (_normalize(category).contains(normalizedQuery)) return true;

    for (final tag in tags) {
      if (_normalize(tag).contains(normalizedQuery)) {
        return true;
      }
    }

    for (final keyword in searchKeywords) {
      if (_normalize(keyword).contains(normalizedQuery)) {
        return true;
      }
    }

    return false;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

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
}