import 'models/vending_machine_detail_data.dart';
import '../domain/entities/public_machine_photo.dart';

final class VendingMachineDetailBlockFilter {
  const VendingMachineDetailBlockFilter._();

  static bool isMachineHidden({
    required String machineId,
    required Set<String> blockedMachineIds,
  }) => blockedMachineIds.contains(machineId);

  static List<PublicMachinePhoto> visiblePhotos({
    required Iterable<PublicMachinePhoto> photos,
    required Set<String> blockedPhotoIds,
  }) => List<PublicMachinePhoto>.unmodifiable(
    photos.where((photo) => !blockedPhotoIds.contains(photo.photoId)),
  );

  static List<VendingMachineProductDetailItem> visibleProducts({
    required Iterable<VendingMachineProductDetailItem> products,
    required Set<String> blockedProductIds,
  }) => List<VendingMachineProductDetailItem>.unmodifiable(
    products.where((product) => !blockedProductIds.contains(product.productId.value)),
  );
}
