import 'master_document.dart';

abstract interface class MasterDocumentSource {
  Future<List<MasterDocument>> fetchCollection(String collectionPath);

  Future<MasterDocument?> fetchDocument(
    String collectionPath,
    String documentId,
  );
}

abstract final class MasterCollections {
  static const String products = 'products';
  static const String manufacturers = 'manufacturers';
}
