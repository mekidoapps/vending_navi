import 'package:flutter/material.dart';

class TagChipList extends StatelessWidget {
  final List<String> tags;
  final EdgeInsetsGeometry padding;
  final double spacing;
  final double runSpacing;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const TagChipList({
    super.key,
    required this.tags,
    this.padding = EdgeInsets.zero,
    this.spacing = 8,
    this.runSpacing = 8,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: padding,
      child: Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        children: tags.map((String tag) {
          return Chip(
            label: Text(tag),
            backgroundColor:
            backgroundColor ?? colorScheme.surfaceContainerHighest,
            labelStyle: TextStyle(
              color: foregroundColor ?? colorScheme.onSurface,
            ),
            side: BorderSide.none,
            visualDensity: VisualDensity.compact,
          );
        }).toList(),
      ),
    );
  }
}