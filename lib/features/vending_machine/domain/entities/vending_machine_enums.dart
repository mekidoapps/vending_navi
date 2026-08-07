enum ManufacturerStatus {
  confirmed('confirmed'),
  recognizedAndConfirmed('recognized_and_confirmed'),
  unknown('unknown');

  const ManufacturerStatus(this.wireValue);

  final String wireValue;

  static ManufacturerStatus? tryParse(String value) {
    final normalized = value.trim();
    for (final item in values) {
      if (item.wireValue == normalized) {
        return item;
      }
    }
    return null;
  }
}

enum InstallationType {
  outdoor('outdoor'),
  indoor('indoor'),
  unknown('unknown');

  const InstallationType(this.wireValue);

  final String wireValue;

  static InstallationType? tryParse(String value) {
    final normalized = value.trim();
    for (final item in values) {
      if (item.wireValue == normalized) {
        return item;
      }
    }
    return null;
  }
}

enum VendingMachineStatus {
  active('active'),
  underReview('underReview'),
  hidden('hidden'),
  removed('removed'),
  merged('merged');

  const VendingMachineStatus(this.wireValue);

  final String wireValue;

  static VendingMachineStatus? tryParse(String value) {
    final normalized = value.trim();
    for (final item in values) {
      if (item.wireValue == normalized) {
        return item;
      }
    }
    return null;
  }
}

enum VendingMachineDataLevel {
  locationOnly('locationOnly'),
  manufacturerOnly('manufacturerOnly'),
  productsConfirmed('productsConfirmed');

  const VendingMachineDataLevel(this.wireValue);

  final String wireValue;

  static VendingMachineDataLevel? tryParse(String value) {
    final normalized = value.trim();
    for (final item in values) {
      if (item.wireValue == normalized) {
        return item;
      }
    }
    return null;
  }
}

enum ProductEvidenceType {
  manualConfirmed('manual_confirmed'),
  photoConfirmed('photo_confirmed'),
  manufacturerInferred('manufacturer_inferred');

  const ProductEvidenceType(this.wireValue);

  final String wireValue;

  bool get isConfirmed =>
      this == ProductEvidenceType.manualConfirmed ||
      this == ProductEvidenceType.photoConfirmed;

  bool get isInferred => this == ProductEvidenceType.manufacturerInferred;

  static ProductEvidenceType? tryParse(String value) {
    final normalized = value.trim();
    for (final item in values) {
      if (item.wireValue == normalized) {
        return item;
      }
    }
    return null;
  }
}

enum ProductAvailability {
  available('available'),
  soldOut('soldOut'),
  unknown('unknown');

  const ProductAvailability(this.wireValue);

  final String wireValue;

  static ProductAvailability? tryParse(String value) {
    final normalized = value.trim();
    for (final item in values) {
      if (item.wireValue == normalized) {
        return item;
      }
    }
    return null;
  }
}
