import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';

void main() {
  test('Firestore固定値をDomain enumへ変換できる', () {
    expect(
      ManufacturerStatus.tryParse('recognized_and_confirmed'),
      ManufacturerStatus.recognizedAndConfirmed,
    );
    expect(InstallationType.tryParse('outdoor'), InstallationType.outdoor);
    expect(
      VendingMachineStatus.tryParse('underReview'),
      VendingMachineStatus.underReview,
    );
    expect(
      VendingMachineDataLevel.tryParse('productsConfirmed'),
      VendingMachineDataLevel.productsConfirmed,
    );
    expect(
      ProductEvidenceType.tryParse('manufacturer_inferred'),
      ProductEvidenceType.manufacturerInferred,
    );
    expect(
      ProductAvailability.tryParse('soldOut'),
      ProductAvailability.soldOut,
    );
  });

  test('未知の固定値はnullにして勝手に補正しない', () {
    expect(VendingMachineStatus.tryParse('unknown_status'), isNull);
    expect(ProductEvidenceType.tryParse('ai_guess'), isNull);
  });
}
