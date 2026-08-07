import '../../../vending_machine/data/sources/vending_machine_document.dart';

abstract interface class VendingMachineViewportSource {
  Future<List<VendingMachineDocument>> fetchV2ByGeohashPrefixes(
    Set<String> prefixes,
  );

  /// Temporary compatibility path while legacy documents coexist.
  Future<List<VendingMachineDocument>> fetchLegacyDocuments();
}
