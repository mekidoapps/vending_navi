import 'package:freezed_annotation/freezed_annotation.dart';

import '../value_objects/master_id.dart';

part 'manufacturer.freezed.dart';

@freezed
abstract class Manufacturer with _$Manufacturer {
  const Manufacturer._();

  const factory Manufacturer({
    required ManufacturerId id,
    required String name,
    required String displayShortName,
    @Default(<String>[]) List<String> searchKeywords,
    @Default(<ProductId>[]) List<ProductId> presetProductIds,
    @Default(true) bool isActive,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Manufacturer;

  bool get isSelectable {
    return isActive &&
        name.trim().isNotEmpty &&
        displayShortName.trim().isNotEmpty;
  }

  Set<String> get searchTerms {
    return <String>{
      name.trim(),
      displayShortName.trim(),
      for (final keyword in searchKeywords)
        if (keyword.trim().isNotEmpty) keyword.trim(),
    };
  }
}
