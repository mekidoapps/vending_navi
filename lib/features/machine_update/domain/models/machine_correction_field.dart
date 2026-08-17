final class MachineCorrectionField<T> {
  const MachineCorrectionField.unchanged() : isChanged = false, value = null;

  const MachineCorrectionField.changed(this.value) : isChanged = true;

  final bool isChanged;

  /// `null` while changed has an explicit meaning for nullable correction
  /// fields such as manufacturerId and placeDescription.
  final T? value;
}
