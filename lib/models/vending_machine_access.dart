import '../core/constants/app_strings.dart';
import '../core/enums/app_enums.dart';

class VendingMachineAccess {
  final String id;
  final String machineId;
  final String productId;
  final String productNameSnapshot;
  final String machineNameSnapshot;
  final int? price;
  final ItemTemperature temperature;
  final StockStatus stockStatus;
  final List<String> itemTags;
  final ConfidenceLevel confidence;
  final DateTime? lastSeenAt;
  final String? lastReportType;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const VendingMachineAccess({
    required this.id,
    required this.machineId,
    required this.productId,
    required this.productNameSnapshot,
    required this.machineNameSnapshot,
    this.price,
    this.temperature = ItemTemperature.unknown,
    this.stockStatus = StockStatus.unknown,
    this.itemTags = const <String>[],
    this.confidence = ConfidenceLevel.medium,
    this.lastSeenAt,
    this.lastReportType,
    this.createdAt,
    this.updatedAt,
  });

  String get priceLabel => price == null ? AppStrings.priceUnknown : '$price円';

  VendingMachineAccess copyWith({
    String? id,
    String? machineId,
    String? productId,
    String? productNameSnapshot,
    String? machineNameSnapshot,
    int? price,
    ItemTemperature? temperature,
    StockStatus? stockStatus,
    List<String>? itemTags,
    ConfidenceLevel? confidence,
    DateTime? lastSeenAt,
    String? lastReportType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VendingMachineAccess(
      id: id ?? this.id,
      machineId: machineId ?? this.machineId,
      productId: productId ?? this.productId,
      productNameSnapshot: productNameSnapshot ?? this.productNameSnapshot,
      machineNameSnapshot: machineNameSnapshot ?? this.machineNameSnapshot,
      price: price ?? this.price,
      temperature: temperature ?? this.temperature,
      stockStatus: stockStatus ?? this.stockStatus,
      itemTags: itemTags ?? this.itemTags,
      confidence: confidence ?? this.confidence,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lastReportType: lastReportType ?? this.lastReportType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'machine_id': machineId,
      'product_id': productId,
      'product_name_snapshot': productNameSnapshot,
      'machine_name_snapshot': machineNameSnapshot,
      'price': price,
      'temperature': _temperatureToFirestore(temperature),
      'stock_status': _stockStatusToFirestore(stockStatus),
      'item_tags': itemTags,
      'confidence': _confidenceToFirestore(confidence),
      'last_seen_at': lastSeenAt,
      'last_report_type': lastReportType,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory VendingMachineAccess.fromMap(String id, Map<String, dynamic> map) {
    return VendingMachineAccess(
      id: id,
      machineId: (map['machine_id'] ?? '') as String,
      productId: (map['product_id'] ?? '') as String,
      productNameSnapshot: (map['product_name_snapshot'] ?? '') as String,
      machineNameSnapshot: (map['machine_name_snapshot'] ?? '') as String,
      price: map['price'] as int?,
      temperature: _temperatureFromFirestore((map['temperature'] ?? 'unknown') as String),
      stockStatus: _stockStatusFromFirestore((map['stock_status'] ?? 'unknown') as String),
      itemTags: List<String>.from(map['item_tags'] ?? const <String>[]),
      confidence: _confidenceFromFirestore((map['confidence'] ?? 'medium') as String),
      lastSeenAt: _toDateTime(map['last_seen_at']),
      lastReportType: map['last_report_type'] as String?,
      createdAt: _toDateTime(map['created_at']),
      updatedAt: _toDateTime(map['updated_at']),
    );
  }

  static ItemTemperature _temperatureFromFirestore(String value) {
    switch (value) {
      case 'cold':
        return ItemTemperature.cold;
      case 'hot':
        return ItemTemperature.hot;
      case 'both':
        return ItemTemperature.both;
      default:
        return ItemTemperature.unknown;
    }
  }

  static String _temperatureToFirestore(ItemTemperature value) {
    switch (value) {
      case ItemTemperature.cold:
        return 'cold';
      case ItemTemperature.hot:
        return 'hot';
      case ItemTemperature.both:
        return 'both';
      case ItemTemperature.unknown:
        return 'unknown';
    }
  }

  static StockStatus _stockStatusFromFirestore(String value) {
    switch (value) {
      case 'seen_recently':
        return StockStatus.seenRecently;
      case 'maybe_available':
        return StockStatus.maybeAvailable;
      case 'sold_out_reported':
        return StockStatus.soldOutReported;
      default:
        return StockStatus.unknown;
    }
  }

  static String _stockStatusToFirestore(StockStatus value) {
    switch (value) {
      case StockStatus.seenRecently:
        return 'seen_recently';
      case StockStatus.maybeAvailable:
        return 'maybe_available';
      case StockStatus.soldOutReported:
        return 'sold_out_reported';
      case StockStatus.unknown:
        return 'unknown';
    }
  }

  static ConfidenceLevel _confidenceFromFirestore(String value) {
    switch (value) {
      case 'high':
        return ConfidenceLevel.high;
      case 'low':
        return ConfidenceLevel.low;
      default:
        return ConfidenceLevel.medium;
    }
  }

  static String _confidenceToFirestore(ConfidenceLevel value) {
    switch (value) {
      case ConfidenceLevel.high:
        return 'high';
      case ConfidenceLevel.medium:
        return 'medium';
      case ConfidenceLevel.low:
        return 'low';
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