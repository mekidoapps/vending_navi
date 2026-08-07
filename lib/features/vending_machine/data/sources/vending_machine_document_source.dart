import 'vending_machine_document.dart';

abstract interface class VendingMachineDocumentSource {
  Future<List<VendingMachineDocument>> fetchMachineDocuments();

  Future<VendingMachineDocument?> fetchMachineDocument(String machineId);

  Future<List<VendingMachineDocument>> fetchProductDocuments(String machineId);
}

abstract final class VendingMachineCollections {
  static const String vendingMachines = 'vending_machines';
  static const String products = 'products';
}
