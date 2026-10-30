import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';

/// Écran d'attente pendant la restauration de la session (Keystore → API).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surfaces = context.surfaces;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(Tokens.radiusCard),
                border: Border.all(color: scheme.primary.withValues(alpha: 0.45)),
              ),
              child: Text(
                'FV',
                style: Tokens.h1.copyWith(color: scheme.primary, letterSpacing: 1),
              ),
            ),
            const SizedBox(height: Tokens.space4),
            Text(
              'FOOTBALL VALUE AI',
              style: Tokens.caption.copyWith(
                color: surfaces.muted,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: Tokens.space6),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: Tokens.space3),
            Text(
              'Restauration de la session…',
              style: Tokens.caption.copyWith(color: surfaces.muted),
            ),
          ],
        ),
      ),
    );
  }
}
