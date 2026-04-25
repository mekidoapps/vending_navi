import 'dart:async';

import 'package:flutter/material.dart';

class TitleUnlockOverlay {
  TitleUnlockOverlay._();

  static Future<void> show(
      BuildContext context, {
        required List<String> titles,
      }) async {
    if (titles.isEmpty) return;
    if (!context.mounted) return;

    final OverlayState? overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;

    final OverlayEntry entry = OverlayEntry(
      builder: (_) => _TitleUnlockOverlayWidget(
        titles: titles,
      ),
    );

    overlay.insert(entry);

    await Future<void>.delayed(const Duration(milliseconds: 2400));
    entry.remove();
  }
}

class _TitleUnlockOverlayWidget extends StatefulWidget {
  const _TitleUnlockOverlayWidget({
    required this.titles,
  });

  final List<String> titles;

  @override
  State<_TitleUnlockOverlayWidget> createState() =>
      _TitleUnlockOverlayWidgetState();
}

class _TitleUnlockOverlayWidgetState extends State<_TitleUnlockOverlayWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _reverseTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 220),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _controller.forward();

    _reverseTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _reverseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String titleText = widget.titles.length == 1
        ? widget.titles.first
        : '${widget.titles.first} ほか ${widget.titles.length}件';

    return IgnorePointer(
      ignoring: true,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _offsetAnimation,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF334148),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 14,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF64B5F6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '称号獲得！',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFBEE3FF),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                titleText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}