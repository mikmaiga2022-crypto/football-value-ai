import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Préférence d'apparence. Sombre par défaut (docs/06 §2.1).
///
/// Phase 2 : la préférence vit le temps de la session et n'est pas persistée.
/// La persistance locale arrive avec le cache Drift (Phase 3).
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void select(ThemeMode mode) {
    if (mode == state) return;
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
