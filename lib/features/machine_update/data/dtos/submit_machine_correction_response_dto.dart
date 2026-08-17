final class SubmitMachineCorrectionResponseDto {
  const SubmitMachineCorrectionResponseDto({
    required this.machineId,
    required this.correctionId,
  });

  factory SubmitMachineCorrectionResponseDto.fromMap(Map<String, Object?> map) {
    final machineId = map['machineId'];
    final correctionId = map['correctionId'];
    final submitted = map['submitted'];

    if (machineId is! String ||
        machineId.trim().isEmpty ||
        correctionId is! String ||
        correctionId.trim().isEmpty ||
        submitted != true) {
      throw const FormatException('Invalid submitMachineCorrection response');
    }

    return SubmitMachineCorrectionResponseDto(
      machineId: machineId.trim(),
      correctionId: correctionId.trim(),
    );
  }

  final String machineId;
  final String correctionId;
}
