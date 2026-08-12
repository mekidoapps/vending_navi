import '../../../core/errors/app_failure.dart';
import '../domain/models/registration_duplicate_candidate.dart';

final class RegistrationDuplicateCandidatesState {
  const RegistrationDuplicateCandidatesState({
    this.candidates = const <RegistrationDuplicateCandidate>[],
    this.isLoading = false,
    this.hasLoaded = false,
    this.failure,
  });

  final List<RegistrationDuplicateCandidate> candidates;
  final bool isLoading;
  final bool hasLoaded;
  final AppFailure? failure;

  bool get isEmpty => hasLoaded && !isLoading && candidates.isEmpty;

  RegistrationDuplicateCandidatesState copyWith({
    List<RegistrationDuplicateCandidate>? candidates,
    bool? isLoading,
    bool? hasLoaded,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return RegistrationDuplicateCandidatesState(
      candidates: candidates ?? this.candidates,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}
