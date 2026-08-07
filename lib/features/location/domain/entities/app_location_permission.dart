enum AppLocationPermission {
  denied,
  deniedForever,
  whileInUse,
  always,
  unableToDetermine;

  bool get canAccessLocation =>
      this == AppLocationPermission.whileInUse ||
      this == AppLocationPermission.always;
}
