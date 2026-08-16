import '../../../product_master/domain/value_objects/master_id.dart';
import '../../domain/entities/photo_recognition_result.dart';

final class PhotoRecognitionResponseDto {
  const PhotoRecognitionResponseDto({
    required this.manufacturerCandidateIds,
    required this.productCandidateIds,
    required this.unresolvedLabels,
    required this.status,
  });

  factory PhotoRecognitionResponseDto.fromMap(Map<String, Object?> map) {
    _expectOnlyKeys(map, const <String>{
      'manufacturerCandidates',
      'productCandidates',
      'unresolvedLabels',
      'recognitionStatus',
    });

    final manufacturerCandidateIds = _parseCandidateIds<ManufacturerId>(
      map['manufacturerCandidates'],
      key: 'manufacturerId',
      parse: ManufacturerId.tryParse,
      field: 'manufacturerCandidates',
    );
    final productCandidateIds = _parseCandidateIds<ProductId>(
      map['productCandidates'],
      key: 'productId',
      parse: ProductId.tryParse,
      field: 'productCandidates',
    );
    final unresolvedLabels = _parseStringList(
      map['unresolvedLabels'],
      'unresolvedLabels',
    );

    final rawStatus = map['recognitionStatus'];
    if (rawStatus is! String) {
      throw const FormatException('recognitionStatus must be a string');
    }
    final status = PhotoRecognitionStatus.tryParse(rawStatus);
    if (status == null) {
      throw const FormatException('recognitionStatus is invalid');
    }

    return PhotoRecognitionResponseDto(
      manufacturerCandidateIds: manufacturerCandidateIds,
      productCandidateIds: productCandidateIds,
      unresolvedLabels: unresolvedLabels,
      status: status,
    );
  }

  final List<ManufacturerId> manufacturerCandidateIds;
  final List<ProductId> productCandidateIds;
  final List<String> unresolvedLabels;
  final PhotoRecognitionStatus status;

  PhotoRecognitionResult toDomain() {
    return PhotoRecognitionResult(
      manufacturerCandidateIds: List<ManufacturerId>.unmodifiable(
        manufacturerCandidateIds,
      ),
      productCandidateIds: List<ProductId>.unmodifiable(productCandidateIds),
      unresolvedLabels: List<String>.unmodifiable(unresolvedLabels),
      status: status,
    );
  }

  static List<T> _parseCandidateIds<T>(
    Object? raw, {
    required String key,
    required T? Function(String value) parse,
    required String field,
  }) {
    if (raw is! List) {
      throw FormatException('$field must be a list');
    }

    final values = <T>[];
    final seen = <String>{};

    for (final item in raw) {
      if (item is! Map) {
        throw FormatException('$field item must be a map');
      }

      final mapped = item.map<String, Object?>(
        (candidateKey, candidateValue) =>
            MapEntry(candidateKey.toString(), candidateValue),
      );

      if (mapped.length != 1 || !mapped.containsKey(key)) {
        throw FormatException('$field item has invalid fields');
      }

      final rawId = mapped[key];
      if (rawId is! String) {
        throw FormatException('$field.$key must be a string');
      }

      final normalized = rawId.trim();
      final parsed = parse(normalized);
      if (parsed == null) {
        throw FormatException('$field.$key is invalid');
      }

      if (seen.add(normalized)) {
        values.add(parsed);
      }
    }

    return List<T>.unmodifiable(values);
  }

  static List<String> _parseStringList(Object? raw, String field) {
    if (raw is! List) {
      throw FormatException('$field must be a list');
    }

    final values = <String>[];
    final seen = <String>{};

    for (final item in raw) {
      if (item is! String) {
        throw FormatException('$field item must be a string');
      }

      final normalized = item.trim();
      if (normalized.isNotEmpty && seen.add(normalized)) {
        values.add(normalized);
      }
    }

    return List<String>.unmodifiable(values);
  }

  static void _expectOnlyKeys(Map<String, Object?> map, Set<String> expected) {
    for (final key in map.keys) {
      if (!expected.contains(key)) {
        throw FormatException('unexpected recognition field: $key');
      }
    }

    for (final key in expected) {
      if (!map.containsKey(key)) {
        throw FormatException('missing recognition field: $key');
      }
    }
  }
}
