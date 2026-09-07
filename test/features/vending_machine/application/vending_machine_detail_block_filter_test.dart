import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/vending_machine/application/models/vending_machine_detail_data.dart';
import 'package:vending_app/features/vending_machine/application/vending_machine_detail_block_filter.dart';
import 'package:vending_app/features/vending_machine/domain/entities/public_machine_photo.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';

void main() {
  final products = <VendingMachineProductDetailItem>[
    VendingMachineProductDetailItem(productId: ProductId.parse('product_a'), productName: 'A', evidenceType: ProductEvidenceType.manualConfirmed, availability: ProductAvailability.available),
    VendingMachineProductDetailItem(productId: ProductId.parse('product_b'), productName: 'B', evidenceType: ProductEvidenceType.manualConfirmed, availability: ProductAvailability.available),
  ];
  const photos = <PublicMachinePhoto>[
    PublicMachinePhoto(photoId: 'p_a', status: 'active'),
    PublicMachinePhoto(photoId: 'p_b', status: 'active'),
  ];

  test('machine block hides the full detail before partial filters', () {
    expect(VendingMachineDetailBlockFilter.isMachineHidden(machineId: 'machine_a', blockedMachineIds: <String>{'machine_a'}), isTrue);
    expect(VendingMachineDetailBlockFilter.isMachineHidden(machineId: 'machine_a', blockedMachineIds: const <String>{}), isFalse);
  });

  test('photo block removes only matching photos and safely handles empty visibility', () {
    expect(VendingMachineDetailBlockFilter.visiblePhotos(photos: photos, blockedPhotoIds: <String>{'p_a'}).map((photo) => photo.photoId), <String>['p_b']);
    expect(VendingMachineDetailBlockFilter.visiblePhotos(photos: photos, blockedPhotoIds: <String>{'p_a', 'p_b'}), isEmpty);
    expect(VendingMachineDetailBlockFilter.visiblePhotos(photos: const <PublicMachinePhoto>[], blockedPhotoIds: <String>{'p_a'}), isEmpty);
  });

  test('product block leaves the machine and photos independent', () {
    expect(VendingMachineDetailBlockFilter.visibleProducts(products: products, blockedProductIds: <String>{'product_a'}).map((product) => product.productId.value), <String>['product_b']);
    expect(VendingMachineDetailBlockFilter.visiblePhotos(photos: photos, blockedPhotoIds: const <String>{}).map((photo) => photo.photoId), <String>['p_a', 'p_b']);
  });

  test('combined filtering hides matching photo and product while machine remains visible', () {
    expect(VendingMachineDetailBlockFilter.isMachineHidden(machineId: 'machine_a', blockedMachineIds: const <String>{}), isFalse);
    expect(VendingMachineDetailBlockFilter.visiblePhotos(photos: photos, blockedPhotoIds: <String>{'p_b'}).map((photo) => photo.photoId), <String>['p_a']);
    expect(VendingMachineDetailBlockFilter.visibleProducts(products: products, blockedProductIds: <String>{'product_b'}).map((product) => product.productId.value), <String>['product_a']);
  });
}
