import 'package:flutter/material.dart';

/// Keeps the app label and required attribution in one safe, flowing layout.
class V2MapHeader extends StatelessWidget {
  const V2MapHeader({
    super.key,
    required this.title,
    required this.attribution,
  });

  final Widget title;
  final Widget attribution;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.only(left: 12, right: 80),
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[title, const SizedBox(height: 8), attribution],
          ),
        ),
      ),
    );
  }
}
