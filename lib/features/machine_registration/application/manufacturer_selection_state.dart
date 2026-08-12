import '../../../core/errors/app_failure.dart';
import '../../product_master/domain/entities/manufacturer.dart';

final class ManufacturerSelectionState {
  const ManufacturerSelectionState({
    this.manufacturers = const <Manufacturer>[],
    this.isLoading = false,
    this.hasLoaded = false,
    this.failure,
  });

  final List<Manufacturer> manufacturers;
  final bool isLoading;
  final bool hasLoaded;
  final AppFailure? failure;

  bool get isEmpty => hasLoaded && !isLoading && manufacturers.isEmpty;

  ManufacturerSelectionState copyWith({
    List<Manufacturer>? manufacturers,
    bool? isLoading,
    bool? hasLoaded,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return ManufacturerSelectionState(
      manufacturers: manufacturers ?? this.manufacturers,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}
