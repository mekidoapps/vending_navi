final class CreateVendingMachineResponseDto {
  const CreateVendingMachineResponseDto({
    required this.machineId,
    required this.created,
  });

  factory CreateVendingMachineResponseDto.fromMap(Map<String, Object?> data) {
    final machineId = data['machineId'];
    final created = data['created'];

    if (machineId is! String || machineId.trim().isEmpty) {
      throw const FormatException('machineId is required');
    }
    if (created is! bool) {
      throw const FormatException('created must be bool');
    }

    return CreateVendingMachineResponseDto(
      machineId: machineId.trim(),
      created: created,
    );
  }

  final String machineId;
  final bool created;
}
