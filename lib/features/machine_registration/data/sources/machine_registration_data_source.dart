abstract interface class MachineRegistrationDataSource {
  Future<Map<String, Object?>> createVendingMachine(
    Map<String, Object?> request,
  );
}
