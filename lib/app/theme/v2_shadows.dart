import 'package:flutter/material.dart';

abstract final class V2Shadows {
  static const List<BoxShadow> subtle = <BoxShadow>[
    BoxShadow(color: Color(0x120F3850), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> mapFloating = <BoxShadow>[
    BoxShadow(color: Color(0x1F0F3850), blurRadius: 18, offset: Offset(0, 7)),
  ];
}
