import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';

/// Gabarit commun aux écrans d'identité : une seule action dominante.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.footer,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.screenPadding,
              vertical: Tokens.space6,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(Tokens.radiusButton),
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          'FV',
                          style: Tokens.bodyStrong.copyWith(
                            color: scheme.primary,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(width: Tokens.space3),
                      Expanded(
                        child: Text(
                          'FOOTBALL VALUE AI',
                          style: Tokens.caption.copyWith(
                            color: surfaces.muted,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Tokens.space8),
                  Text(title, style: Tokens.display.copyWith(color: scheme.onSurface)),
                  const SizedBox(height: Tokens.space2),
                  Text(subtitle, style: Tokens.body.copyWith(color: surfaces.muted)),
                  const SizedBox(height: Tokens.space6),
                  ...children,
                  if (footer != null) ...[
                    const SizedBox(height: Tokens.space6),
                    footer!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
