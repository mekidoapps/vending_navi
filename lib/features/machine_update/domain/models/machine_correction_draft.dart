import '../../../product_master/domain/value_objects/master_id.dart';
import '../../../vending_machine/domain/entities/vending_machine_enums.dart';
import '../../../vending_machine/domain/value_objects/geo_coordinate.dart';
import '../../../vending_machine/domain/value_objects/vending_machine_id.dart';
import 'machine_correction_field.dart';

final class MachineCorrectionDraft {
  const MachineCorrectionDraft({
    required this.machineId,
    this.name = const MachineCorrectionField<String>.unchanged(),
    this.manufacturerId =
        const MachineCorrectionField<ManufacturerId>.unchanged(),
    this.location = const MachineCorrectionField<GeoCoordinate>.unchanged(),
    this.placeDescription = const MachineCorrectionField<String>.unchanged(),
    this.installationType =
        const MachineCorrectionField<InstallationType>.unchanged(),
    this.message,
  });

  final VendingMachineId machineId;

  final MachineCorrectionField<String> name;

  /// `changed(null)` means "メーカー不明へ修正".
  final MachineCorrectionField<ManufacturerId> manufacturerId;

  final MachineCorrectionField<GeoCoordinate> location;

  /// `changed(null)` means "場所メモを削除".
  final MachineCorrectionField<String> placeDescription;

  final MachineCorrectionField<InstallationType> installationType;

  final String? message;

  bool get hasChanges =>
      name.isChanged ||
      manufacturerId.isChanged ||
      location.isChanged ||
      placeDescription.isChanged ||
      installationType.isChanged;
}
