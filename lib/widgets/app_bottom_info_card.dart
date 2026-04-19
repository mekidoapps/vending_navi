import 'package:flutter/material.dart';

class AppBottomInfoCard extends StatelessWidget {
  const AppBottomInfoCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
    this.margin = const EdgeInsets.fromLTRB(12, 8, 12, 12),
    this.showSafeArea = true,
    this.accentColor,
    this.showAccentBar = false,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final bool showSafeArea;

  /// メーカー色などを上部アクセントに使う
  final Color? accentColor;
  final bool showAccentBar;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((title ?? '').trim().isNotEmpty || trailing != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if ((title ?? '').trim().isNotEmpty)
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334148),
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE3E7EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showAccentBar)
              Container(
                height: 5,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: accentColor ?? const Color(0xFFD5E8F5),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
              ),
            showSafeArea
                ? SafeArea(
              top: false,
              child: content,
            )
                : content,
          ],
        ),
      ),
    );
  }
}