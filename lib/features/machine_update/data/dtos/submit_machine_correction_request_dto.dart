import '../../domain/models/machine_correction_draft.dart';

final class SubmitMachineCorrectionRequestDto {
  const SubmitMachineCorrectionRequestDto({
    required this.requestId,
    required this.draft,
  });

  final String requestId;
  final MachineCorrectionDraft draft;

  Map<String, Object?> toMap() {
    final changes = <String, Object?>{};

    if (draft.name.isChanged) {
      final value = draft.name.value?.trim();

      if (value == null || value.isEmpty) {
        throw const FormatException(
          'Changed correction name must not be empty',
        );
      }

      changes['name'] = value;
    }

    if (draft.manufacturerId.isChanged) {
      changes['manufacturerId'] = draft.manufacturerId.value?.value;
    }

    if (draft.location.isChanged) {
      final value = draft.location.value;

      if (value == null) {
        throw const FormatException(
          'Changed correction location must not be null',
        );
      }

      changes['location'] = <String, Object?>{
        'latitude': value.latitude,
        'longitude': value.longitude,
      };
    }

    if (draft.placeDescription.isChanged) {
      final value = draft.placeDescription.value?.trim();

      changes['placeDescription'] = value == null || value.isEmpty
          ? null
          : value;
    }

    if (draft.installationType.isChanged) {
      final value = draft.installationType.value;

      if (value == null) {
        throw const FormatException(
          'Changed correction installationType must not be null',
        );
      }

      changes['installationType'] = value.wireValue;
    }

    if (changes.isEmpty) {
      throw const FormatException('At least one correction change is required');
    }

    final normalizedMessage = draft.message?.trim();

    return <String, Object?>{
      'requestId': requestId,
      'machineId': draft.machineId.value,
      'changes': changes,
      'message': normalizedMessage == null || normalizedMessage.isEmpty
          ? null
          : normalizedMessage,
    };
  }
}
