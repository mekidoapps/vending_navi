import '../../../product_master/domain/entities/product_genre.dart';
import '../../../product_master/domain/value_objects/master_id.dart';
import '../../../vending_machine/domain/entities/vending_machine_enums.dart';
import '../../../vending_machine/domain/value_objects/geo_coordinate.dart';
import '../../../vending_machine/domain/value_objects/vending_machine_id.dart';

final class MachineProductIndexEntry {
  const MachineProductIndexEntry({
    required this.machineId,
    required this.productId,
    required this.genres,
    required this.location,
    required this.geohash,
    required this.evidenceType,
    required this.availability,
    required this.isActive,
    required this.machineStatus,
    required this.machineUpdatedAt,
    required this.updatedAt,
  });

  final VendingMachineId machineId;
  final ProductId productId;
  final List<ProductGenre> genres;
  final GeoCoordinate location;
  final String geohash;
  final ProductEvidenceType evidenceType;
  final ProductAvailability availability;
  final bool isActive;
  final VendingMachineStatus machineStatus;
  final DateTime machineUpdatedAt;
  final DateTime updatedAt;

  bool get isSearchVisible =>
      isActive && machineStatus == VendingMachineStatus.active;

  bool get isConfirmed => evidenceType.isConfirmed;

  bool get isInferred => evidenceType.isInferred;
}
