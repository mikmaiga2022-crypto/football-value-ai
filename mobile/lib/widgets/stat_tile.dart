import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';
import '../app/theme/tokens.dart';

/// Compteur factuel. `value` vaut « — » quand la donnée est indisponible :
/// jamais 0 à la place d'une absence (docs/06 §5).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.onTap,
  });

  final String label;
  final String value;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;

    final content = Padding(
      padding: const EdgeInsets.all(Tokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: Tokens.section.copyWith(
              color: surfaces.muted,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: Tokens.space2),
          Text(value, style: Tokens.number.copyWith(color: scheme.onSurface)),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!, style: Tokens.caption.copyWith(color: surfaces.muted)),
          ],
        ],
      ),
    );

    final card = Card(child: content);
    if (onTap == null) return card;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
        child: card,
      ),
    );
  }
}
