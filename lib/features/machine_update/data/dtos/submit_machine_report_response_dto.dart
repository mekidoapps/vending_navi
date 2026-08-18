final class SubmitMachineReportResponseDto {
  const SubmitMachineReportResponseDto({
    required this.machineId,
    required this.reportId,
  });

  static final RegExp _reportIdPattern = RegExp(r'^r_[0-9a-f]{30}$');

  factory SubmitMachineReportResponseDto.fromMap(Map<String, Object?> map) {
    final machineId = map['machineId'];
    final reportId = map['reportId'];
    final submitted = map['submitted'];

    if (machineId is! String ||
        machineId.trim().isEmpty ||
        reportId is! String ||
        !_reportIdPattern.hasMatch(reportId.trim()) ||
        submitted != true) {
      throw const FormatException('Invalid submitMachineReport response');
    }

    return SubmitMachineReportResponseDto(
      machineId: machineId.trim(),
      reportId: reportId.trim(),
    );
  }

  final String machineId;
  final String reportId;
}
