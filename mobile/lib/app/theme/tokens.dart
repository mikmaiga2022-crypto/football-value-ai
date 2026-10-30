import 'package:flutter/material.dart';

/// Design tokens — source de vérité : `design/tokens.json`.
/// Toute modification doit être reportée dans les deux fichiers.
abstract final class Tokens {
  // Couleurs — thème sombre (par défaut)
  static const bg = Color(0xFF0B0F14);
  static const surface = Color(0xFF121821);
  static const surfaceAlt = Color(0xFF1A2230);
  static const border = Color(0xFF243044);
  static const text = Color(0xFFEAF0F7);
  static const textMuted = Color(0xFF8A94A6);

  static const primary = Color(0xFF00D68F);
  static const primaryPressed = Color(0xFF00B87A);
  static const accent = Color(0xFF4CD7F6);
  static const warning = Color(0xFFFFB020);
  static const danger = Color(0xFFFF5A5F);
  static const info = Color(0xFF2F80ED);

  static const priorityA = Color(0xFF00D68F);
  static const priorityB = Color(0xFF4CD7F6);
  static const priorityC = Color(0xFFFFB020);
  static const priorityD = Color(0xFF8A94A6);
  static const noBet = Color(0xFF5A6473);
  static const live = Color(0xFFFF4D4F);

  // Couleurs — thème clair
  static const lightBg = Color(0xFFF6F8FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFEEF2F6);
  static const lightBorder = Color(0xFFDDE3EA);
  static const lightText = Color(0xFF111827);
  static const lightTextMuted = Color(0xFF5B6675);
  static const lightPrimary = Color(0xFF00875A);
  static const lightAccent = Color(0xFF0077B6);
  static const lightWarning = Color(0xFFB26A00);
  static const lightDanger = Color(0xFFC62828);
  static const lightInfo = Color(0xFF1565C0);

  // Espacements
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 20.0;
  static const space6 = 24.0;
  static const space8 = 32.0;

  // Rayons
  static const radiusBadge = 8.0;
  static const radiusButton = 12.0;
  static const radiusCard = 16.0;
  static const radiusSheet = 24.0;
  static const radiusPill = 999.0;

  // Layout
  static const screenPadding = 16.0;
  static const minTouchTarget = 48.0;
  static const maxContentWidth = 720.0;

  // Typographie
  static const display = TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 34 / 28);
  static const h1 = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 28 / 22);
  static const h2 = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 24 / 18);
  static const section = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 18 / 13,
    letterSpacing: 1.04,
  );
  static const body = TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 21 / 15);
  static const bodyStrong = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 21 / 15);
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 16 / 12);
  static const badge = TextStyle(fontSize: 12, fontWeight: FontWeight.w800, height: 14 / 12);
  static const number = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 24 / 20,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // Motion
  static const motionFast = Duration(milliseconds: 120);
  static const motionNormal = Duration(milliseconds: 220);
  static const motionSlow = Duration(milliseconds: 320);
  static const easing = Cubic(0.2, 0.0, 0.0, 1.0);
}
