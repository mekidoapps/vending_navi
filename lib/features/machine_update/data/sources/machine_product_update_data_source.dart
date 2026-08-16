abstract interface class MachineProductUpdateDataSource {
  Future<Map<String, Object?>> updateVendingMachineProducts(
    Map<String, Object?> request,
  );
}
