import 'package:flutter/material.dart';

@immutable
class V2ColorTokens extends ThemeExtension<V2ColorTokens> {
  const V2ColorTokens({
    required this.primary,
    required this.primarySoft,
    required this.primaryStrong,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceTint,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.mapActionButton,
    required this.confirmed,
    required this.inferred,
    required this.stale,
    required this.warning,
    required this.error,
  });

  static const V2ColorTokens skyBlue = V2ColorTokens(
    primary: Color(0xFF5CAFE0),
    primarySoft: Color(0xFFDDF2FF),
    primaryStrong: Color(0xFF2F7EAE),
    surface: Color(0xFFF5FBFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceTint: Color(0xFFEAF7FF),
    textPrimary: Color(0xFF263B47),
    textSecondary: Color(0xFF5D7480),
    border: Color(0xFFD9E8F0),
    mapActionButton: Color(0xFFFFFFFF),
    confirmed: Color(0xFF3C8FC1),
    inferred: Color(0xFF87BEDB),
    stale: Color(0xFF7F98A5),
    warning: Color(0xFFC98A2E),
    error: Color(0xFFC75A61),
  );

  final Color primary;
  final Color primarySoft;
  final Color primaryStrong;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceTint;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color mapActionButton;
  final Color confirmed;
  final Color inferred;
  final Color stale;
  final Color warning;
  final Color error;

  static V2ColorTokens of(BuildContext context) {
    return Theme.of(context).extension<V2ColorTokens>() ?? skyBlue;
  }

  @override
  V2ColorTokens copyWith({
    Color? primary,
    Color? primarySoft,
    Color? primaryStrong,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceTint,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? mapActionButton,
    Color? confirmed,
    Color? inferred,
    Color? stale,
    Color? warning,
    Color? error,
  }) {
    return V2ColorTokens(
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      primaryStrong: primaryStrong ?? this.primaryStrong,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceTint: surfaceTint ?? this.surfaceTint,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      mapActionButton: mapActionButton ?? this.mapActionButton,
      confirmed: confirmed ?? this.confirmed,
      inferred: inferred ?? this.inferred,
      stale: stale ?? this.stale,
      warning: warning ?? this.warning,
      error: error ?? this.error,
    );
  }

  @override
  V2ColorTokens lerp(covariant V2ColorTokens? other, double t) {
    if (other == null) {
      return this;
    }
    return V2ColorTokens(
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      primaryStrong: Color.lerp(primaryStrong, other.primaryStrong, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceTint: Color.lerp(surfaceTint, other.surfaceTint, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      mapActionButton: Color.lerp(mapActionButton, other.mapActionButton, t)!,
      confirmed: Color.lerp(confirmed, other.confirmed, t)!,
      inferred: Color.lerp(inferred, other.inferred, t)!,
      stale: Color.lerp(stale, other.stale, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}
