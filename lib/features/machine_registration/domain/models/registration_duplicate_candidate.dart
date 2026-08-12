import '../../../vending_machine/domain/entities/vending_machine.dart';

final class RegistrationDuplicateCandidate {
  const RegistrationDuplicateCandidate({
    required this.machine,
    required this.distanceMeters,
  });

  final VendingMachine machine;
  final double distanceMeters;
}
