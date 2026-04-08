import 'package:flutter/material.dart';

class AppBottomInfoCard extends StatelessWidget {
  const AppBottomInfoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
    this.margin = const EdgeInsets.fromLTRB(12, 8, 12, 12),
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFF1F5F9),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}