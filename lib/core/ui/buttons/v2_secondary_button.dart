import 'package:flutter/material.dart';

class V2SecondaryButton extends StatelessWidget {
  const V2SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.edit_rounded),
      label: Text(label),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
