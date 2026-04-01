import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  StorageService({
    FirebaseStorage? storage,
  }) : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadMachinePhoto({
    required File file,
    required String fileName,
  }) async {
    final ref = _storage.ref().child('vending_machines/photos/$fileName');

    final metadata = SettableMetadata(
      contentType: _detectContentType(file.path),
    );

    final uploadTask = ref.putFile(file, metadata);
    final snapshot = await uploadTask;
    return snapshot.ref.getDownloadURL();
  }

  Future<List<String>> uploadMachinePhotos({
    required List<File> files,
    required String machineKey,
  }) async {
    final List<String> urls = <String>[];

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final extension = _extensionFromPath(file.path);
      final fileName =
          '${machineKey}_${DateTime.now().millisecondsSinceEpoch}_$i$extension';

      final url = await uploadMachinePhoto(
        file: file,
        fileName: fileName,
      );
      urls.add(url);
    }

    return urls;
  }

  String _extensionFromPath(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1) return '.jpg';
    return path.substring(dotIndex).toLowerCase();
  }

  String _detectContentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}