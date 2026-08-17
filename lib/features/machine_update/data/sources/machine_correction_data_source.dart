abstract interface class MachineCorrectionDataSource {
  Future<Map<String, Object?>> submitMachineCorrection(
    Map<String, Object?> request,
  );
}
