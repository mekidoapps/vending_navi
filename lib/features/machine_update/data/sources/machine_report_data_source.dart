abstract interface class MachineReportDataSource {
  Future<Map<String, Object?>> submitMachineReport(
    Map<String, Object?> request,
  );
}
