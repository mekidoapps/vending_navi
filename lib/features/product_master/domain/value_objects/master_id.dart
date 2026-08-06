abstract base class MasterId {
  MasterId._(this.value) {
    if (!MasterIdRules.isValid(value)) {
      throw FormatException('Invalid ${runtimeType.toString()}: $value');
    }
  }

  final String value;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other.runtimeType == runtimeType &&
            other is MasterId &&
            other.value == value;
  }

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => value;
}

final class ProductId extends MasterId {
  ProductId._(String value) : super._(value);

  factory ProductId.parse(String value) => ProductId._(value);

  static ProductId? tryParse(String value) {
    if (!MasterIdRules.isValid(value)) {
      return null;
    }
    return ProductId._(value);
  }
}

final class ManufacturerId extends MasterId {
  ManufacturerId._(String value) : super._(value);

  factory ManufacturerId.parse(String value) => ManufacturerId._(value);

  static ManufacturerId? tryParse(String value) {
    if (!MasterIdRules.isValid(value)) {
      return null;
    }
    return ManufacturerId._(value);
  }
}

abstract final class MasterIdRules {
  static const int minLength = 2;
  static const int maxLength = 80;

  static final RegExp _pattern = RegExp(r'^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$');

  static bool isValid(String value) {
    if (value.length < minLength || value.length > maxLength) {
      return false;
    }
    return _pattern.hasMatch(value);
  }
}
