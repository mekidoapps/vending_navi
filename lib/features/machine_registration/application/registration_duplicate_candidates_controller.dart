import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import 'machine_registration_controller.dart';
import 'providers/registration_duplicate_candidates_providers.dart';
import 'registration_duplicate_candidates_state.dart';

final registrationDuplicateCandidatesControllerProvider =
    NotifierProvider<
      RegistrationDuplicateCandidatesController,
      RegistrationDuplicateCandidatesState
    >(
      RegistrationDuplicateCandidatesController.new,
      name: 'registrationDuplicateCandidatesControllerProvider',
    );

final class RegistrationDuplicateCandidatesController
    extends Notifier<RegistrationDuplicateCandidatesState> {
  var _requestSerial = 0;

  @override
  RegistrationDuplicateCandidatesState build() {
    return const RegistrationDuplicateCandidatesState();
  }

  Future<void> load() async {
    final location = ref
        .read(machineRegistrationControllerProvider)
        .draft
        .location;
    if (location == null) {
      state = state.copyWith(
        candidates: const [],
        isLoading: false,
        hasLoaded: true,
        failure: const ValidationFailure(field: 'location'),
      );
      return;
    }

    final requestId = ++_requestSerial;
    state = state.copyWith(isLoading: true, clearFailure: true);

    final result = await ref
        .read(registrationDuplicateSearchServiceProvider)
        .search(location);

    if (requestId != _requestSerial) {
      return;
    }

    final failure = result.failureOrNull;
    if (failure != null) {
      state = state.copyWith(
        candidates: const [],
        isLoading: false,
        hasLoaded: true,
        failure: failure,
      );
      return;
    }

    state = state.copyWith(
      candidates: result.valueOrNull ?? const [],
      isLoading: false,
      hasLoaded: true,
      clearFailure: true,
    );
  }

  Future<void> retry() => load();

  void continueWithNewMachine() {
    ref
        .read(machineRegistrationControllerProvider.notifier)
        .continueAfterDuplicateCheck();
  }

  void reset() {
    _requestSerial += 1;
    state = const RegistrationDuplicateCandidatesState();
  }
}
