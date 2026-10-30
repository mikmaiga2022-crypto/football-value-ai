import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/providers.dart';
import '../../data/models/value_bet.dart';
import '../../widgets/async_panel.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/section_header.dart';

class ValueScreen extends ConsumerWidget {
  const ValueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverage = ref.watch(coverageProvider).asData?.value;
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Value Betting'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () {
              ref.invalidate(coverageProvider);
              ref.invalidate(competitionsProvider);
            },
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
            const InfoBanner(
              tone: BannerTone.info,
              message:
                  'Les cotes affichées sont celles d’opérateurs identifiés. Vérifiez '
                  'leur disponibilité dans votre pays avant toute décision.',
            ),
            const SizedBox(height: Tokens.space4),
            Wrap(
              spacing: Tokens.space2,
              runSpacing: Tokens.space2,
              children: [
                _Pill(
                  icon: Icons.hub_outlined,
                  label: coverage == null
                      ? 'Compétitions servies : —'
                      : 'Compétitions servies : ${coverage.served.length}',
                ),
                const _Pill(icon: Icons.swap_horiz, label: '1X2 · O/U 2,5'),
                const _Pill(icon: Icons.schedule, label: 'Batch 3×/jour'),
                const _Pill(icon: Icons.sensors_off_outlined, label: 'Live désactivé'),
              ],
            ),
            const SizedBox(height: Tokens.space4),
            AsyncPanel<List<ValueBetItem>>(
              value: ref.watch(valueBetsProvider),
              skeletonCount: 3,
              skeletonHeight: 80,
              onRetry: () => refreshServerData(ref),
              builder: (valueBets) {
                if (valueBets.isEmpty) {
                  return EmptyState(
                    icon: Icons.insights_outlined,
                    title: 'Aucune opportunité à afficher',
                    message:
                        'Le moteur ne publie une sélection que si la cote est vérifiée, '
                        'fraîche, et si l’espérance reste positive après incertitude. '
                        'Quand ce n’est pas le cas, il recommande de ne pas parier.',
                    footnote:
                        'Aucune cote, aucun match et aucune probabilité ne sont simulés '
                        'pour remplir cet écran.',
                    actionLabel: 'Voir le catalogue',
                    onAction: () => context.go('/matches'),
                  );
                }
                return Column(
                  children: [
                    for (final bet in valueBets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Tokens.space3),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(Tokens.space4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${bet.marketCode} · ${bet.selectionCode}'
                                    '${bet.line == null ? '' : ' ${bet.line}'}',
                                    style: Tokens.bodyStrong.copyWith(color: scheme.onSurface),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Prio ${bet.priority}',
                                      style: Tokens.caption.copyWith(color: scheme.primary),
                                    ),
                                    Text(
                                      'EV ${(bet.ev * 100).toStringAsFixed(1)} %',
                                      style: Tokens.number.copyWith(color: scheme.onSurface),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: Tokens.space6),
            const SectionHeader('Ce que le moteur exige'),
            const SizedBox(height: Tokens.space2),
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < _rules.length; i++) ...[
                    if (i > 0) const Divider(),
                    _RuleRow(rule: _rules[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Tokens.space6),
            const SectionHeader('Périmètre actuel'),
            const SizedBox(height: Tokens.space2),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Tokens.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ScopeRow(
                      label: 'Compétitions',
                      value: 'Servies dans le budget de crédits, sans dépassement',
                    ),
                    const SizedBox(height: Tokens.space3),
                    const _ScopeRow(
                      label: 'Marchés',
                      value: '1X2 et Over/Under 2,5 buts uniquement',
                    ),
                    const SizedBox(height: Tokens.space3),
                    const _ScopeRow(
                      label: 'Fraîcheur',
                      value: 'L’âge de chaque cote est affiché ; une cote trop ancienne est écartée',
                    ),
                    const SizedBox(height: Tokens.space3),
                    const _ScopeRow(
                      label: 'Modèle',
                      value: 'Statistique (dé-vig + Poisson/Elo), pas de ML en v1',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Tokens.space6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 16, color: surfaces.muted),
                const SizedBox(width: Tokens.space2),
                Expanded(
                  child: Text(
                    'Espérance positive sur le long terme ne signifie pas gain sur ce '
                    'match. Aucun gain n’est garanti, les pertes sont possibles.',
                    style: Tokens.caption.copyWith(color: surfaces.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space2),
            Text(
              'Priorités : A · B · C · D · NO BET',
              style: Tokens.caption.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rule {
  const _Rule(this.icon, this.title, this.description);

  final IconData icon;
  final String title;
  final String description;
}

const _rules = [
  _Rule(
    Icons.verified_outlined,
    'Cote vérifiée',
    'Une cote non vérifiée est plafonnée et ne peut jamais atteindre la priorité A. '
        'Une cote trop ancienne est écartée, pas « rafraîchie » artificiellement.',
  ),
  _Rule(
    Icons.calculate_outlined,
    'Marge retirée',
    'La probabilité implicite du marché est corrigée du vig avant toute comparaison.',
  ),
  _Rule(
    Icons.straighten,
    'EV et borne basse',
    'L’EV est publiée avec sa borne basse (EV⁻). Une borne négative interdit la '
        'priorité A, même si l’EV centrale est flatteuse.',
  ),
  _Rule(
    Icons.sort,
    'Priorité puis score',
    'Le tri suit la priorité puis le score, jamais l’EV brute : une grosse EV '
        'sur une donnée fragile n’est pas une bonne sélection.',
  ),
  _Rule(
    Icons.block,
    'NO BET assumé',
    'Si un garde-fou échoue, aucune sélection n’est publiée. Un écran vide est un '
        'résultat acceptable, pas un défaut.',
  ),
  _Rule(
    Icons.history,
    'Traçabilité',
    'Chaque sélection porte sa version de modèle, l’âge de la cote et la qualité '
        'des données. L’historique est immuable.',
  ),
];

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.rule});

  final _Rule rule;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(Tokens.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(rule.icon, size: 20, color: scheme.secondary),
          const SizedBox(width: Tokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.title,
                  style: Tokens.bodyStrong.copyWith(color: scheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  rule.description,
                  style: Tokens.caption.copyWith(color: surfaces.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeRow extends StatelessWidget {
  const _ScopeRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Tokens.section.copyWith(color: surfaces.muted, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Tokens.caption.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: surfaces.surfaceAlt,
        borderRadius: BorderRadius.circular(Tokens.radiusPill),
        border: Border.all(color: surfaces.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: surfaces.muted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Tokens.caption.copyWith(color: surfaces.muted),
            ),
          ),
        ],
      ),
    );
  }
}
