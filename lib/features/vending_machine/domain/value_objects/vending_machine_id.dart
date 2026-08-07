final class VendingMachineId {
  VendingMachineId._(this.value);

  factory VendingMachineId.parse(String value) {
    final normalized = value.trim();
    if (!_isValid(normalized)) {
      throw FormatException('Invalid VendingMachineId: $value');
    }
    return VendingMachineId._(normalized);
  }

  static VendingMachineId? tryParse(String value) {
    final normalized = value.trim();
    if (!_isValid(normalized)) {
      return null;
    }
    return VendingMachineId._(normalized);
  }

  final String value;

  static bool _isValid(String value) {
    if (value.isEmpty || value.length > 256) {
      return false;
    }
    if (value == '.' || value == '..') {
      return false;
    }
    return !value.contains('/');
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VendingMachineId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
