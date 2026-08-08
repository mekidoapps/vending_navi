import '../../product_master/domain/entities/product_genre.dart';
import '../../product_search/application/genre_machine_search_state.dart';
import '../../product_search/application/genre_search_map_filter.dart';
import '../../vending_machine/domain/entities/vending_machine.dart';
import '../../vending_machine/domain/value_objects/vending_machine_id.dart';
import 'vending_machine_marker_kind.dart';

abstract final class GenreSearchMarkerKindResolver {
  static VendingMachineMarkerKind resolve({
    required VendingMachine machine,
    required VendingMachineId? selectedMachineId,
    required ProductGenre? selectedGenre,
    required GenreMachineSearchState searchState,
  }) {
    if (machine.id == selectedMachineId) {
      return VendingMachineMarkerKind.selected;
    }

    if (selectedGenre == null) {
      return VendingMachineMarkerKindResolver.resolve(
        machine: machine,
        selectedMachineId: selectedMachineId,
      );
    }

    final evidence = GenreSearchMapFilter.evidenceForMachine(
      machine: machine,
      searchState: searchState,
    );

    if (evidence?.isConfirmed ?? false) {
      return VendingMachineMarkerKind.confirmedProducts;
    }

    if (evidence?.isInferred ?? false) {
      return VendingMachineMarkerKind.inferredProducts;
    }

    return VendingMachineMarkerKind.locationOnly;
  }
}
