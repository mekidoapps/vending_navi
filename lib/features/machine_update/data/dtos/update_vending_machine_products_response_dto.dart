final class UpdateVendingMachineProductsResponseDto {
  const UpdateVendingMachineProductsResponseDto({
    required this.machineId,
    required this.updated,
    required this.changedProductIds,
  });

  factory UpdateVendingMachineProductsResponseDto.fromMap(
    Map<String, Object?> map,
  ) {
    final machineId = map['machineId'];
    final updated = map['updated'];
    final rawChangedProductIds = map['changedProductIds'];

    if (machineId is! String ||
        machineId.trim().isEmpty ||
        updated is! bool ||
        rawChangedProductIds is! List) {
      throw const FormatException(
        'Invalid updateVendingMachineProducts response',
      );
    }

    final changedProductIds = <String>[];

    for (final value in rawChangedProductIds) {
      if (value is! String || value.trim().isEmpty) {
        throw const FormatException('Invalid changedProductIds response');
      }

      changedProductIds.add(value.trim());
    }

    return UpdateVendingMachineProductsResponseDto(
      machineId: machineId.trim(),
      updated: updated,
      changedProductIds: List<String>.unmodifiable(changedProductIds),
    );
  }

  final String machineId;
  final bool updated;
  final List<String> changedProductIds;
}
