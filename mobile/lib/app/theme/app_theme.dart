import 'package:flutter/material.dart';

import 'tokens.dart';

/// Thème Material 3 construit sur les design tokens.
/// Sombre par défaut (docs/06), clair disponible via le sélecteur du profil.
abstract final class AppTheme {
  static const _fontFamily = 'Inter';

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? Tokens.primary : Tokens.lightPrimary,
      onPrimary: isDark ? Tokens.bg : Colors.white,
      secondary: isDark ? Tokens.accent : Tokens.lightAccent,
      onSecondary: isDark ? Tokens.bg : Colors.white,
      error: isDark ? Tokens.danger : Tokens.lightDanger,
      onError: Colors.white,
      surface: isDark ? Tokens.surface : Tokens.lightSurface,
      onSurface: isDark ? Tokens.text : Tokens.lightText,
    );

    final bg = isDark ? Tokens.bg : Tokens.lightBg;
    final surfaceAlt = isDark ? Tokens.surfaceAlt : Tokens.lightSurfaceAlt;
    final border = isDark ? Tokens.border : Tokens.lightBorder;
    final muted = isDark ? Tokens.textMuted : Tokens.lightTextMuted;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      fontFamily: _fontFamily,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      textTheme: const TextTheme(
        displaySmall: Tokens.display,
        headlineSmall: Tokens.h1,
        titleMedium: Tokens.h2,
        bodyMedium: Tokens.body,
        bodyLarge: Tokens.bodyStrong,
        labelSmall: Tokens.caption,
        labelLarge: Tokens.badge,
      ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: Tokens.h2.copyWith(color: scheme.onSurface),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: isDark ? Tokens.surface : Tokens.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusCard),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? Tokens.surface : Tokens.lightSurface,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        height: 64,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => Tokens.caption.copyWith(
            color: states.contains(WidgetState.selected) ? scheme.primary : muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected) ? scheme.primary : muted,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusButton),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusButton),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusButton),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusButton),
          borderSide: BorderSide(color: scheme.error),
        ),
        labelStyle: Tokens.body.copyWith(color: muted),
        helperStyle: Tokens.caption.copyWith(color: muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(Tokens.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tokens.radiusButton),
          ),
          textStyle: Tokens.bodyStrong,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceAlt,
        contentTextStyle: Tokens.body.copyWith(color: scheme.onSurface),
        behavior: SnackBarBehavior.floating,
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppSurfaces(
          border: border,
          muted: muted,
          surfaceAlt: surfaceAlt,
          priorityA: isDark ? Tokens.priorityA : Tokens.lightPrimary,
          priorityB: isDark ? Tokens.priorityB : Tokens.lightAccent,
          priorityC: isDark ? Tokens.priorityC : Tokens.lightWarning,
          priorityD: isDark ? Tokens.priorityD : Tokens.lightTextMuted,
          noBet: Tokens.noBet,
          live: isDark ? Tokens.live : Tokens.lightDanger,
        ),
      ],
    );
  }
}

/// Couleurs secondaires non couvertes par `ColorScheme`.
@immutable
class AppSurfaces extends ThemeExtension<AppSurfaces> {
  const AppSurfaces({
    required this.border,
    required this.muted,
    required this.surfaceAlt,
    required this.priorityA,
    required this.priorityB,
    required this.priorityC,
    required this.priorityD,
    required this.noBet,
    required this.live,
  });

  final Color border;
  final Color muted;
  final Color surfaceAlt;
  final Color priorityA;
  final Color priorityB;
  final Color priorityC;
  final Color priorityD;
  final Color noBet;
  final Color live;

  @override
  AppSurfaces copyWith({
    Color? border,
    Color? muted,
    Color? surfaceAlt,
    Color? priorityA,
    Color? priorityB,
    Color? priorityC,
    Color? priorityD,
    Color? noBet,
    Color? live,
  }) {
    return AppSurfaces(
      border: border ?? this.border,
      muted: muted ?? this.muted,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      priorityA: priorityA ?? this.priorityA,
      priorityB: priorityB ?? this.priorityB,
      priorityC: priorityC ?? this.priorityC,
      priorityD: priorityD ?? this.priorityD,
      noBet: noBet ?? this.noBet,
      live: live ?? this.live,
    );
  }

  @override
  AppSurfaces lerp(ThemeExtension<AppSurfaces>? other, double t) {
    if (other is! AppSurfaces) return this;
    return AppSurfaces(
      border: Color.lerp(border, other.border, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      priorityA: Color.lerp(priorityA, other.priorityA, t)!,
      priorityB: Color.lerp(priorityB, other.priorityB, t)!,
      priorityC: Color.lerp(priorityC, other.priorityC, t)!,
      priorityD: Color.lerp(priorityD, other.priorityD, t)!,
      noBet: Color.lerp(noBet, other.noBet, t)!,
      live: Color.lerp(live, other.live, t)!,
    );
  }
}

extension AppSurfacesX on BuildContext {
  AppSurfaces get surfaces => Theme.of(this).extension<AppSurfaces>()!;
}
