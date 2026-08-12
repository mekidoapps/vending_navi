enum MachineRegistrationMethod {
  photo('photo'),
  manufacturer('manufacturer'),
  locationOnly('locationOnly');

  const MachineRegistrationMethod(this.wireValue);

  final String wireValue;

  static MachineRegistrationMethod? tryParse(String value) {
    final normalized = value.trim();
    for (final item in values) {
      if (item.wireValue == normalized) {
        return item;
      }
    }
    return null;
  }
}
