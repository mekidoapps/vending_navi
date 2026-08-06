import 'package:flutter/material.dart';

import '../../../app/theme/v2_color_tokens.dart';
import '../../../app/theme/v2_shadows.dart';

class V2MapActionButton extends StatelessWidget {
  const V2MapActionButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.size = 54,
    this.isPrimary = false,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final double size;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);
    final background = isPrimary ? colors.primary : colors.mapActionButton;
    final foreground = isPrimary ? Colors.white : colors.primaryStrong;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: background,
            border: Border.all(
              color: isPrimary ? colors.primary : colors.border,
            ),
            boxShadow: V2Shadows.mapFloating,
          ),
          child: IconButton(
            tooltip: semanticLabel,
            onPressed: onPressed,
            icon: Icon(icon, color: foreground),
          ),
        ),
      ),
    );
  }
}
