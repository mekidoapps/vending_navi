import 'package:flutter/foundation.dart';

enum DrinkShelfMode {
  create,
  checkin,
  view,
}

@immutable
class DrinkSlot {
  const DrinkSlot({
    required this.id,
    required this.page,
    required this.indexInPage,
    this.manufacturer,
    this.category,
    this.name,
    this.isSoldOut = false,
  });

  final String id;
  final int page;
  final int indexInPage;
  final String? manufacturer;
  final String? category;
  final String? name;
  final bool isSoldOut;

  bool get isEmpty =>
      (manufacturer == null || manufacturer!.trim().isEmpty) &&
          (category == null || category!.trim().isEmpty) &&
          (name == null || name!.trim().isEmpty);

  DrinkSlot copyWith({
    String? id,
    int? page,
    int? indexInPage,
    String? manufacturer,
    String? category,
    String? name,
    bool? isSoldOut,
    bool clearManufacturer = false,
    bool clearCategory = false,
    bool clearName = false,
  }) {
    return DrinkSlot(
      id: id ?? this.id,
      page: page ?? this.page,
      indexInPage: indexInPage ?? this.indexInPage,
      manufacturer:
      clearManufacturer ? null : (manufacturer ?? this.manufacturer),
      category: clearCategory ? null : (category ?? this.category),
      name: clearName ? null : (name ?? this.name),
      isSoldOut: isSoldOut ?? this.isSoldOut,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'page': page,
      'indexInPage': indexInPage,
      'manufacturer': manufacturer,
      'category': category,
      'name': name,
      'isSoldOut': isSoldOut,
    };
  }

  factory DrinkSlot.fromMap(Map<String, dynamic> map) {
    return DrinkSlot(
      id: map['id'] as String? ?? '',
      page: map['page'] as int? ?? 0,
      indexInPage: map['indexInPage'] as int? ?? 0,
      manufacturer: map['manufacturer'] as String?,
      category: map['category'] as String?,
      name: map['name'] as String?,
      isSoldOut: map['isSoldOut'] as bool? ?? false,
    );
  }

  static List<DrinkSlot> createInitialPage({int page = 0}) {
    return List<DrinkSlot>.generate(
      12,
          (index) => DrinkSlot(
        id: 'p${page}_$index',
        page: page,
        indexInPage: index,
      ),
    );
  }
}