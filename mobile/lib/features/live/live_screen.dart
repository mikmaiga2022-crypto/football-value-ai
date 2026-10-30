import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_dot.dart';

class LiveScreen extends ConsumerWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider).asData?.value;
    final liveEnabled = config?.features.live ?? false;
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Direct'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(appConfigProvider),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: Tokens.space2),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => refreshServerData(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            Tokens.screenPadding,
            0,
            Tokens.screenPadding,
            Tokens.space8,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: StatusDot(
                    color: liveEnabled ? scheme.primary : surfaces.muted,
                    label: liveEnabled
                        ? 'Temps réel activé · 0 match suivi'
                        : 'Temps réel indisponible',
                    textStyle: Tokens.bodyStrong,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space4),
            EmptyState(
              icon: Icons.sensors_off_outlined,
              title: liveEnabled ? 'Aucun match en direct' : 'Le direct est désactivé',
              message: liveEnabled
                  ? 'Aucun match n’est suivi en direct pour le moment. Aucune '
                      'recommandation n’est affichée sans données live vérifiées.'
                  : 'Le mode pilote 0 € ne permet pas de rafraîchir plusieurs marchés '
                      'en continu. Aucune cote live ne sera affichée tant que le budget '
                      'ne le permet pas.',
              footnote:
                  'L’onglet reste visible pour ne pas laisser croire à une fonction absente. '
                  'Le pré-match reste la priorité du service.',
              actionLabel: 'Voir le flux Value',
              onAction: () => context.go('/value'),
            ),
            const SizedBox(height: Tokens.space6),
            const SectionHeader('Pourquoi cette limite ?'),
            const SizedBox(height: Tokens.space2),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Tokens.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Le plan gratuit de cotes offre 500 crédits par mois. Un appel '
                      'coûte le nombre de régions multiplié par le nombre de marchés.',
                      style: Tokens.body.copyWith(color: scheme.onSurface),
                    ),
                    const SizedBox(height: Tokens.space3),
                    Text(
                      'Rafraîchir 3 régions × 3 marchés toutes les 60 secondes coûte '
                      '9 crédits par minute : environ 55 minutes de direct par mois, '
                      'pas un service continu.',
                      style: Tokens.body.copyWith(color: scheme.onSurface),
                    ),
                    const SizedBox(height: Tokens.space3),
                    Text(
                      'Plutôt que d’afficher des cotes périmées, le direct est coupé. '
                      'C’est une limite de budget, pas une panne.',
                      style: Tokens.caption.copyWith(color: surfaces.muted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Tokens.space6),
            const SectionHeader('Ce qui reste disponible'),
            const SizedBox(height: Tokens.space2),
            Card(
              child: Column(
                children: const [
                  _AvailabilityRow(
                    icon: Icons.check_circle_outline,
                    available: true,
                    label: 'Opportunités pré-match (quand les cotes sont vérifiées)',
                  ),
                  Divider(),
                  _AvailabilityRow(
                    icon: Icons.remove_circle_outline,
                    available: false,
                    label: 'Recommandations et cotes live',
                  ),
                  Divider(),
                  _AvailabilityRow(
                    icon: Icons.remove_circle_outline,
                    available: false,
                    label: 'Scores et statistiques en temps réel',
                  ),
                ],
              ),
            ),
            const SizedBox(height: Tokens.space6),
            Text(
              'Les probabilités sont des estimations. Aucun gain n’est garanti. '
              'L’application ne place aucun pari.',
              style: Tokens.caption.copyWith(color: surfaces.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityRow extends StatelessWidget {
  const _AvailabilityRow({
    required this.icon,
    required this.available,
    required this.label,
  });

  final IconData icon;
  final bool available;
  final String label;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(Tokens.space4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: available ? scheme.primary : surfaces.noBet),
          const SizedBox(width: Tokens.space3),
          Expanded(
            child: Text(
              label,
              style: Tokens.body.copyWith(
                color: available ? scheme.onSurface : surfaces.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
