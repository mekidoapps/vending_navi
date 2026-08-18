import '../../product_master/domain/value_objects/master_id.dart';
import '../../vending_machine/domain/entities/vending_machine_enums.dart';
import '../../vending_machine/domain/value_objects/geo_coordinate.dart';
import '../../vending_machine/domain/value_objects/vending_machine_id.dart';
import '../domain/models/machine_correction_draft.dart';
import '../domain/models/machine_correction_field.dart';

abstract final class MachineCorrectionDraftBuilder {
  static MachineCorrectionDraft build({
    required VendingMachineId machineId,
    required String currentName,
    required ManufacturerId? currentManufacturerId,
    required GeoCoordinate currentLocation,
    required String? currentPlaceDescription,
    required InstallationType currentInstallationType,
    required String proposedName,
    required ManufacturerId? proposedManufacturerId,
    required GeoCoordinate proposedLocation,
    required String? proposedPlaceDescription,
    required InstallationType proposedInstallationType,
    String? message,
  }) {
    final normalizedCurrentName = currentName.trim();
    final normalizedProposedName = proposedName.trim();

    final normalizedCurrentPlace = _normalizeOptionalText(
      currentPlaceDescription,
    );
    final normalizedProposedPlace = _normalizeOptionalText(
      proposedPlaceDescription,
    );

    final normalizedMessage = _normalizeOptionalText(message);

    return MachineCorrectionDraft(
      machineId: machineId,
      name: normalizedCurrentName == normalizedProposedName
          ? const MachineCorrectionField<String>.unchanged()
          : MachineCorrectionField<String>.changed(normalizedProposedName),
      manufacturerId: currentManufacturerId == proposedManufacturerId
          ? const MachineCorrectionField<ManufacturerId>.unchanged()
          : MachineCorrectionField<ManufacturerId>.changed(
              proposedManufacturerId,
            ),
      location: currentLocation == proposedLocation
          ? const MachineCorrectionField<GeoCoordinate>.unchanged()
          : MachineCorrectionField<GeoCoordinate>.changed(proposedLocation),
      placeDescription: normalizedCurrentPlace == normalizedProposedPlace
          ? const MachineCorrectionField<String>.unchanged()
          : MachineCorrectionField<String>.changed(normalizedProposedPlace),
      installationType: currentInstallationType == proposedInstallationType
          ? const MachineCorrectionField<InstallationType>.unchanged()
          : MachineCorrectionField<InstallationType>.changed(
              proposedInstallationType,
            ),
      message: normalizedMessage,
    );
  }

  static String? _normalizeOptionalText(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
