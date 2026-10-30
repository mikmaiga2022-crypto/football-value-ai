import 'package:flutter/material.dart';

import '../app/theme/app_theme.dart';
import '../app/theme/tokens.dart';

/// Badge de couverture : libellé explicite + couleur, jamais la couleur seule.
class CoverageBadge extends StatelessWidget {
  const CoverageBadge(this.state, {super.key});

  final String state;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final (label, color) = switch (state) {
      'served' => ('SERVIE', surfaces.priorityA),
      'opportunistic' => ('À LA DEMANDE', surfaces.priorityB),
      'disabled' => ('DÉSACTIVÉE', surfaces.noBet),
      _ => ('CATALOGUE', surfaces.priorityD),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Tokens.radiusBadge),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: Tokens.badge.copyWith(color: color)),
    );
  }
}
