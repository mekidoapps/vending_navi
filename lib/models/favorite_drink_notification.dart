class FavoriteDrinkNotification {
  final String id;
  final String userId;
  final String productId;
  final String productName;
  final String machineId;
  final String machineName;
  final String? placeNote;
  final DateTime? detectedAt;
  final bool isRead;

  const FavoriteDrinkNotification({
    required this.id,
    required this.userId,
    required this.productId,
    required this.productName,
    required this.machineId,
    required this.machineName,
    this.placeNote,
    this.detectedAt,
    this.isRead = false,
  });

  FavoriteDrinkNotification copyWith({
    String? id,
    String? userId,
    String? productId,
    String? productName,
    String? machineId,
    String? machineName,
    String? placeNote,
    DateTime? detectedAt,
    bool? isRead,
  }) {
    return FavoriteDrinkNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      machineId: machineId ?? this.machineId,
      machineName: machineName ?? this.machineName,
      placeNote: placeNote ?? this.placeNote,
      detectedAt: detectedAt ?? this.detectedAt,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'user_id': userId,
      'product_id': productId,
      'product_name': productName,
      'machine_id': machineId,
      'machine_name': machineName,
      'place_note': placeNote,
      'detected_at': detectedAt,
      'is_read': isRead,
    };
  }

  factory FavoriteDrinkNotification.fromMap(String id, Map<String, dynamic> map) {
    return FavoriteDrinkNotification(
      id: id,
      userId: (map['user_id'] ?? '') as String,
      productId: (map['product_id'] ?? '') as String,
      productName: (map['product_name'] ?? '') as String,
      machineId: (map['machine_id'] ?? '') as String,
      machineName: (map['machine_name'] ?? '') as String,
      placeNote: map['place_note'] as String?,
      detectedAt: _toDateTime(map['detected_at']),
      isRead: (map['is_read'] ?? false) as bool,
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    try {
      return value.toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }
}