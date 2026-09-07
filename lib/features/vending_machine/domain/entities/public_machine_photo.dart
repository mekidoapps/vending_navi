import 'package:cloud_firestore/cloud_firestore.dart';

/// Public formal-photo metadata. Attribution and Storage details are never
/// represented here; the deterministic display reference is derived at use.
final class PublicMachinePhoto {
  const PublicMachinePhoto({
    required this.photoId,
    required this.status,
    this.createdAt,
  });

  final String photoId;
  final String status;
  final DateTime? createdAt;

  String displayReferenceFor(String machineId) =>
      'vending_machines/$machineId/$photoId/original.jpg';

  static PublicMachinePhoto? fromDocument(
    String photoId,
    Map<String, dynamic> data,
  ) {
    final status = data['status'];
    if (status is! String || status.trim().isEmpty) return null;
    final createdAt = data['createdAt'];
    return PublicMachinePhoto(
      photoId: photoId,
      status: status.trim(),
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }
}
