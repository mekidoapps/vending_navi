import 'package:flutter/material.dart';

class MachineFreshnessBadge extends StatelessWidget {
  const MachineFreshnessBadge({
    super.key,
    required this.updatedAt,
    this.compact = false,
  });

  final DateTime? updatedAt;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final state = _resolveState(updatedAt);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: state.backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: state.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            state.icon,
            size: compact ? 13 : 14,
            color: state.textColor,
          ),
          const SizedBox(width: 4),
          Text(
            state.label,
            style: TextStyle(
              fontFamily: 'Noto Sans JP',
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: state.textColor,
            ),
          ),
        ],
      ),
    );
  }

  _FreshnessState _resolveState(DateTime? updatedAt) {
    if (updatedAt == null) {
      return const _FreshnessState(
        label: '未確認寄り',
        icon: Icons.help_outline_rounded,
        textColor: Color(0xFF7A5A00),
        backgroundColor: Color(0xFFFFF6DB),
        borderColor: Color(0xFFFFE08A),
      );
    }

    final now = DateTime.now();
    final diff = now.difference(updatedAt).inDays;

    if (diff <= 7) {
      return const _FreshnessState(
        label: '最近確認',
        icon: Icons.verified_rounded,
        textColor: Color(0xFF1E7A46),
        backgroundColor: Color(0xFFE8F7EE),
        borderColor: Color(0xFF9ED8B4),
      );
    }

    if (diff <= 30) {
      return const _FreshnessState(
        label: 'やや古い',
        icon: Icons.schedule_rounded,
        textColor: Color(0xFF7A5A00),
        backgroundColor: Color(0xFFFFF6DB),
        borderColor: Color(0xFFFFE08A),
      );
    }

    return const _FreshnessState(
      label: '未確認寄り',
      icon: Icons.error_outline_rounded,
      textColor: Color(0xFF8A3B2E),
      backgroundColor: Color(0xFFFDECEA),
      borderColor: Color(0xFFF3B7AF),
    );
  }
}

class _FreshnessState {
  const _FreshnessState({
    required this.label,
    required this.icon,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final String label;
  final IconData icon;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;
}