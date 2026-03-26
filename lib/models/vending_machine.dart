import '../core/enums/app_enums.dart';

class VendingMachine {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String geohash;
  final String? placeNote;
  final List<String> photoUrls;
  final List<String> paymentMethods;
  final List<String> machineTags;
  final MachineStatus status;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastVerifiedAt;

  const VendingMachine({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.geohash = '',
    this.placeNote,
    this.photoUrls = const <String>[],
    this.paymentMethods = const <String>[],
    this.machineTags = const <String>[],
    this.status = MachineStatus.active,
    this.createdBy = '',
    this.createdAt,
    this.updatedAt,
    this.lastVerifiedAt,
  });

  VendingMachine copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    String? geohash,
    String? placeNote,
    List<String>? photoUrls,
    List<String>? paymentMethods,
    List<String>? machineTags,
    MachineStatus? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastVerifiedAt,
  }) {
    return VendingMachine(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      geohash: geohash ?? this.geohash,
      placeNote: placeNote ?? this.placeNote,
      photoUrls: photoUrls ?? this.photoUrls,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      machineTags: machineTags ?? this.machineTags,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'geohash': geohash,
      'place_note': placeNote,
      'photo_urls': photoUrls,
      'payment_methods': paymentMethods,
      'machine_tags': machineTags,
      'status': status.name,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'last_verified_at': lastVerifiedAt,
    };
  }

  factory VendingMachine.fromMap(String id, Map<String, dynamic> map) {
    return VendingMachine(
      id: id,
      name: (map['name'] ?? '') as String,
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      geohash: (map['geohash'] ?? '') as String,
      placeNote: map['place_note'] as String?,
      photoUrls: List<String>.from(map['photo_urls'] ?? const <String>[]),
      paymentMethods: List<String>.from(map['payment_methods'] ?? const <String>[]),
      machineTags: List<String>.from(map['machine_tags'] ?? const <String>[]),
      status: _machineStatusFromString((map['status'] ?? 'active') as String),
      createdBy: (map['created_by'] ?? '') as String,
      createdAt: _toDateTime(map['created_at']),
      updatedAt: _toDateTime(map['updated_at']),
      lastVerifiedAt: _toDateTime(map['last_verified_at']),
    );
  }

  static MachineStatus _machineStatusFromString(String value) {
    switch (value) {
      case 'hidden':
        return MachineStatus.hidden;
      case 'archived':
        return MachineStatus.archived;
      default:
        return MachineStatus.active;
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