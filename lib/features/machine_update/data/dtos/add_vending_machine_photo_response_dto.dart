final class AddVendingMachinePhotoResponseDto {
  const AddVendingMachinePhotoResponseDto({
    required this.machineId,
    required this.photoId,
    required this.added,
    required this.primaryPhotoChanged,
  });

  factory AddVendingMachinePhotoResponseDto.fromMap(Map<String, Object?> map) {
    final machineId = map['machineId'];
    final photoId = map['photoId'];
    final added = map['added'];
    final primaryPhotoChanged = map['primaryPhotoChanged'];

    if (machineId is! String ||
        machineId.trim().isEmpty ||
        photoId is! String ||
        photoId.trim().isEmpty ||
        added is! bool ||
        primaryPhotoChanged is! bool) {
      throw const FormatException('Invalid addVendingMachinePhoto response');
    }

    return AddVendingMachinePhotoResponseDto(
      machineId: machineId.trim(),
      photoId: photoId.trim(),
      added: added,
      primaryPhotoChanged: primaryPhotoChanged,
    );
  }

  final String machineId;
  final String photoId;
  final bool added;
  final bool primaryPhotoChanged;
}
