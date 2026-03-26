import '../core/enums/app_enums.dart';

class Checkin {
  final String id;
  final String userId;
  final String machineId;
  final String? productId;
  final CheckinActionType actionType;
  final int? reportedPrice;
  final String? comment;
  final List<String> photoUrls;
  final DateTime? createdAt;
  final double? latitude;
  final double? longitude;

  const Checkin({
    required this.id,
    required this.userId,
    required this.machineId,
    this.productId,
    required this.actionType,
    this.reportedPrice,
    this.comment,
    this.photoUrls = const <String>[],
    this.createdAt,
    this.latitude,
    this.longitude,
  });

  Checkin copyWith({
    String? id,
    String? userId,
    String? machineId,
    String? productId,
    CheckinActionType? actionType,
    int? reportedPrice,
    String? comment,
    List<String>? photoUrls,
    DateTime? createdAt,
    double? latitude,
    double? longitude,
  }) {
    return Checkin(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      machineId: machineId ?? this.machineId,
      productId: productId ?? this.productId,
      actionType: actionType ?? this.actionType,
      reportedPrice: reportedPrice ?? this.reportedPrice,
      comment: comment ?? this.comment,
      photoUrls: photoUrls ?? this.photoUrls,
      createdAt: createdAt ?? this.createdAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'user_id': userId,
      'machine_id': machineId,
      'product_id': productId,
      'action_type': _actionTypeToFirestore(actionType),
      'reported_price': reportedPrice,
      'comment': comment,
      'photo_urls': photoUrls,
      'created_at': createdAt,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory Checkin.fromMap(String id, Map<String, dynamic> map) {
    return Checkin(
      id: id,
      userId: (map['user_id'] ?? '') as String,
      machineId: (map['machine_id'] ?? '') as String,
      productId: map['product_id'] as String?,
      actionType: _actionTypeFromFirestore((map['action_type'] ?? 'visit') as String),
      reportedPrice: map['reported_price'] as int?,
      comment: map['comment'] as String?,
      photoUrls: List<String>.from(map['photo_urls'] ?? const <String>[]),
      createdAt: _toDateTime(map['created_at']),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  static CheckinActionType _actionTypeFromFirestore(String value) {
    switch (value) {
      case 'found':
        return CheckinActionType.found;
      case 'sold_out':
        return CheckinActionType.soldOut;
      case 'price_update':
        return CheckinActionType.priceUpdate;
      case 'photo_update':
        return CheckinActionType.photoUpdate;
      case 'machine_create':
        return CheckinActionType.machineCreate;
      default:
        return CheckinActionType.visit;
    }
  }

  static String _actionTypeToFirestore(CheckinActionType value) {
    switch (value) {
      case CheckinActionType.visit:
        return 'visit';
      case CheckinActionType.found:
        return 'found';
      case CheckinActionType.soldOut:
        return 'sold_out';
      case CheckinActionType.priceUpdate:
        return 'price_update';
      case CheckinActionType.photoUpdate:
        return 'photo_update';
      case CheckinActionType.machineCreate:
        return 'machine_create';
    }
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