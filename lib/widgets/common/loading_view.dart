import 'package:flutter/material.dart';

class LoadingView extends StatelessWidget {
  final String? message;
  final bool fullScreen;
  final double indicatorSize;
  final EdgeInsetsGeometry padding;

  const LoadingView({
    super.key,
    this.message,
    this.fullScreen = false,
    this.indicatorSize = 28,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    final Widget content = Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: indicatorSize,
              height: indicatorSize,
              child: const CircularProgressIndicator(),
            ),
            if (message != null && message!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );

    if (fullScreen) {
      return Scaffold(
        body: SafeArea(child: content),
      );
    }

    return content;
  }
}