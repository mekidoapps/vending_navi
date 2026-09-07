import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/vending_machine/data/repositories/machine_photo_repository_impl.dart';
import 'package:vending_app/features/vending_machine/data/sources/vending_machine_document.dart';

void main() {
  test('public photo mapper keeps active documents and document IDs only', () {
    final photos = mapActivePublicMachinePhotos(<VendingMachineDocument>[
      const VendingMachineDocument(id: 'p_active_1', data: <String, dynamic>{'status': 'active', 'uploadedBy': 'private', 'storagePath': 'private/path'}),
      const VendingMachineDocument(id: 'p_inactive', data: <String, dynamic>{'status': 'inactive'}),
      const VendingMachineDocument(id: 'p_invalid', data: <String, dynamic>{}),
      const VendingMachineDocument(id: 'p_active_2', data: <String, dynamic>{'status': 'active', 'recognitionProvider': 'private'}),
    ]);

    expect(photos.map((photo) => photo.photoId), <String>['p_active_1', 'p_active_2']);
    expect(photos.every((photo) => photo.status == 'active'), isTrue);
  });

  test('public photo mapper handles empty and invalid input without private mapping', () {
    expect(mapActivePublicMachinePhotos(const <VendingMachineDocument>[]), isEmpty);
    expect(mapActivePublicMachinePhotos(const <VendingMachineDocument>[
      VendingMachineDocument(id: 'p_invalid', data: <String, dynamic>{'status': '  '}),
    ]), isEmpty);
  });
}
