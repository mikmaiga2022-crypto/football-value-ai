import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';
import '../app/theme/tokens.dart';

/// État vide assumé : le moteur préfère ne rien afficher plutôt qu'inventer.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.footnote,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Tokens.radiusButton),
              ),
              child: Icon(icon, size: 22, color: scheme.secondary),
            ),
            const SizedBox(height: Tokens.space3),
            Text(title, style: Tokens.h2.copyWith(color: scheme.onSurface)),
            const SizedBox(height: Tokens.space2),
            Text(
              message,
              style: Tokens.body.copyWith(color: surfaces.muted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Tokens.space3),
              OutlinedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
            if (footnote != null) ...[
              const SizedBox(height: Tokens.space3),
              Text(
                footnote!,
                style: Tokens.caption.copyWith(color: surfaces.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
