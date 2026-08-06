import 'package:flutter/material.dart';

abstract final class V2Radius {
  static const double chipValue = 12;
  static const double controlValue = 16;
  static const double cardValue = 20;
  static const double popupValue = 24;

  static const BorderRadius chip = BorderRadius.all(Radius.circular(chipValue));
  static const BorderRadius control = BorderRadius.all(
    Radius.circular(controlValue),
  );
  static const BorderRadius card = BorderRadius.all(Radius.circular(cardValue));
  static const BorderRadius popup = BorderRadius.all(
    Radius.circular(popupValue),
  );
}
