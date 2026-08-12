import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../product_master/domain/value_objects/master_id.dart';
import '../../vending_machine/domain/entities/vending_machine_enums.dart';
import '../../vending_machine/domain/value_objects/geo_coordinate.dart';
import '../domain/entities/machine_registration_draft.dart';
import '../domain/entities/machine_registration_method.dart';
import 'machine_registration_state.dart';
import 'providers/machine_registration_providers.dart';

final machineRegistrationControllerProvider =
    NotifierProvider<MachineRegistrationController, MachineRegistrationState>(
      MachineRegistrationController.new,
      name: 'machineRegistrationControllerProvider',
    );

final class MachineRegistrationController
    extends Notifier<MachineRegistrationState> {
  @override
  MachineRegistrationState build() {
    return _initialState();
  }

  MachineRegistrationState _initialState() {
    final requestId = ref
        .read(registrationRequestIdGeneratorProvider)
        .generate();
    return MachineRegistrationState(
      draft: MachineRegistrationDraft(requestId: requestId),
    );
  }

  void setLocation(GeoCoordinate location) {
    state = state.copyWith(
      draft: state.draft.copyWith(location: location),
      clearFailure: true,
      clearCreatedMachineId: true,
    );
  }

  bool continueFromPosition() {
    if (state.draft.location == null) {
      state = state.copyWith(
        failure: const ValidationFailure(field: 'location'),
      );
      return false;
    }

    state = state.copyWith(
      step: MachineRegistrationStep.duplicateCheck,
      clearFailure: true,
    );
    return true;
  }

  void continueAfterDuplicateCheck() {
    state = state.copyWith(
      step: MachineRegistrationStep.method,
      clearFailure: true,
    );
  }

  void chooseManufacturerMethod() {
    state = state.copyWith(
      draft: state.draft.copyWith(
        registrationMethod: MachineRegistrationMethod.manufacturer,
        clearManufacturerId: true,
        confirmedProductIds: const <ProductId>[],
        clearTemporaryPhotoUploadId: true,
      ),
      step: MachineRegistrationStep.manufacturer,
      clearFailure: true,
    );
  }

  void chooseLocationOnly() {
    state = state.copyWith(
      draft: state.draft.copyWith(
        registrationMethod: MachineRegistrationMethod.locationOnly,
        clearManufacturerId: true,
        confirmedProductIds: const <ProductId>[],
        clearTemporaryPhotoUploadId: true,
      ),
      step: MachineRegistrationStep.confirm,
      clearFailure: true,
    );
  }

  void selectManufacturer(ManufacturerId manufacturerId) {
    state = state.copyWith(
      draft: state.draft.copyWith(
        registrationMethod: MachineRegistrationMethod.manufacturer,
        manufacturerId: manufacturerId,
        clearTemporaryPhotoUploadId: true,
      ),
      step: MachineRegistrationStep.confirm,
      clearFailure: true,
    );
  }

  void setConfirmedProducts(List<ProductId> productIds) {
    state = state.copyWith(
      draft: state.draft.copyWith(
        confirmedProductIds: List<ProductId>.unmodifiable(productIds),
      ),
      clearFailure: true,
    );
  }

  void setName(String? value) {
    final normalized = _normalizeOptionalText(value);
    state = state.copyWith(
      draft: normalized == null
          ? state.draft.copyWith(clearName: true)
          : state.draft.copyWith(name: normalized),
      clearFailure: true,
    );
  }

  void setPlaceDescription(String? value) {
    final normalized = _normalizeOptionalText(value);
    state = state.copyWith(
      draft: normalized == null
          ? state.draft.copyWith(clearPlaceDescription: true)
          : state.draft.copyWith(placeDescription: normalized),
      clearFailure: true,
    );
  }

  void setInstallationType(InstallationType value) {
    state = state.copyWith(
      draft: state.draft.copyWith(installationType: value),
      clearFailure: true,
    );
  }

  void backToMethodSelection() {
    state = state.copyWith(
      step: MachineRegistrationStep.method,
      clearFailure: true,
    );
  }

  Future<bool> submit() async {
    if (state.isSubmitting) {
      return false;
    }

    if (!state.draft.isReadyForPhase6Submission) {
      state = state.copyWith(
        failure: const ValidationFailure(field: 'registrationDraft'),
      );
      return false;
    }

    state = state.copyWith(
      step: MachineRegistrationStep.submitting,
      clearFailure: true,
    );

    final result = await ref
        .read(machineRegistrationRepositoryProvider)
        .createVendingMachine(state.draft);

    final failure = result.failureOrNull;
    if (failure != null) {
      state = state.copyWith(
        step: MachineRegistrationStep.confirm,
        failure: failure,
      );
      return false;
    }

    final value = result.valueOrNull;
    if (value == null) {
      state = state.copyWith(
        step: MachineRegistrationStep.confirm,
        failure: const UnknownFailure(),
      );
      return false;
    }

    state = state.copyWith(
      step: MachineRegistrationStep.completed,
      createdMachineId: value.machineId,
      clearFailure: true,
    );
    return true;
  }

  void reset() {
    state = _initialState();
  }

  static String? _normalizeOptionalText(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
