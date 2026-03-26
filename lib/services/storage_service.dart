import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  StorageService._internal();

  static final StorageService _instance = StorageService._internal();

  factory StorageService() => _instance;

  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadFile({
    required File file,
    required String path,
    SettableMetadata? metadata,
  }) async {
    final Reference ref = _storage.ref().child(path);
    final UploadTask uploadTask = ref.putFile(file, metadata);

    final TaskSnapshot snapshot = await uploadTask;
    return snapshot.ref.getDownloadURL();
  }

  Future<List<String>> uploadFiles({
    required List<File> files,
    required String directoryPath,
  }) async {
    final List<String> urls = <String>[];

    for (int i = 0; i < files.length; i++) {
      final File file = files[i];
      final String filePath =
          '$directoryPath/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

      final String url = await uploadFile(
        file: file,
        path: filePath,
      );
      urls.add(url);
    }

    return urls;
  }

  Future<void> deleteByUrl(String fileUrl) async {
    final Reference ref = _storage.refFromURL(fileUrl);
    await ref.delete();
  }
}