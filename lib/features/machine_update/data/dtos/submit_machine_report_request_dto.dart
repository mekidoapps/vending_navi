import '../../domain/models/machine_report_draft.dart';

final class SubmitMachineReportRequestDto {
  const SubmitMachineReportRequestDto({
    required this.requestId,
    required this.draft,
  });

  static final RegExp _photoIdPattern = RegExp(r'^p_[0-9a-f]{30}$');

  final String requestId;
  final MachineReportDraft draft;

  Map<String, Object?> toMap() {
    final normalizedPhotoId = draft.photoId?.trim();

    if (draft.photoId != null &&
        (normalizedPhotoId == null ||
            normalizedPhotoId.isEmpty ||
            !_photoIdPattern.hasMatch(normalizedPhotoId))) {
      throw const FormatException('Invalid machine report photoId');
    }

    final normalizedMessage = draft.message?.trim();

    if (normalizedMessage != null && normalizedMessage.length > 500) {
      throw const FormatException('Machine report message is too long');
    }

    return <String, Object?>{
      'requestId': requestId,
      'machineId': draft.machineId.value,
      'photoId': normalizedPhotoId == null || normalizedPhotoId.isEmpty
          ? null
          : normalizedPhotoId,
      'category': draft.category.wireValue,
      'message': normalizedMessage == null || normalizedMessage.isEmpty
          ? null
          : normalizedMessage,
    };
  }
}
