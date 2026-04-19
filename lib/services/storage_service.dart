import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  static const String _recentKey = 'recent_drinks';

  static Future<void> saveRecentDrinks(List<String> drinks) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_recentKey) ?? <String>[];

    final List<String> merged = <String>[
      ...drinks.map((e) => e.trim()).where((e) => e.isNotEmpty),
      ...current.map((e) => e.trim()).where((e) => e.isNotEmpty),
    ];

    final List<String> unique = <String>[];
    for (final String item in merged) {
      if (!unique.contains(item)) {
        unique.add(item);
      }
    }

    await prefs.setStringList(_recentKey, unique.take(20).toList());
  }

  static Future<List<String>> getRecentDrinks() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentKey) ?? <String>[];
  }

  Future<String> uploadMachinePhoto({
    required File file,
    required String fileName,
  }) async {
    final Reference ref = _storage.ref().child('machine_photos').child(fileName);

    final SettableMetadata metadata = SettableMetadata(
      contentType: _detectContentType(file.path),
    );

    await ref.putFile(file, metadata);
    return ref.getDownloadURL();
  }

  Future<List<String>> uploadMachinePhotos({
    required List<File> files,
    required String machineKey,
  }) async {
    final List<String> urls = <String>[];

    for (int i = 0; i < files.length; i++) {
      final File file = files[i];
      final String extension = _extensionFromPath(file.path);
      final String fileName =
          '${machineKey}_${DateTime.now().millisecondsSinceEpoch}_$i$extension';

      final String url = await uploadMachinePhoto(
        file: file,
        fileName: fileName,
      );
      urls.add(url);
    }

    return urls;
  }

  String _extensionFromPath(String path) {
    final int dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1) return '.jpg';
    return path.substring(dotIndex).toLowerCase();
  }

  String _detectContentType(String path) {
    final String lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return 'application/octet-stream';
  }
}
