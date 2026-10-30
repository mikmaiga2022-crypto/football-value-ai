import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/auth/session.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../data/models/competition.dart';
import '../../data/models/system_status.dart';
import '../../widgets/async_panel.dart';
import '../../widgets/coverage_badge.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/status_dot.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final coverage = ref.watch(coverageProvider);
    final health = ref.watch(healthProvider);
    final config = ref.watch(appConfigProvider);

    final configData = config.asData?.value;
    final name = session.user?.shortName;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => refreshServerData(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              Tokens.screenPadding,
              Tokens.space3,
              Tokens.screenPadding,
              Tokens.space8,
            ),
            children: [
              _Header(
                name: name,
                health: health,
                onRefresh: () => refreshServerData(ref),
              ),
              if (configData?.maintenance ?? false) ...[
                const SizedBox(height: Tokens.space4),
                const InfoBanner(
                  tone: BannerTone.warning,
                  title: 'Maintenance en cours',
                  message:
                      'Le service est en maintenance. Les dernières données connues '
                      'restent affichées, sans garantie de fraîcheur.',
                ),
              ],
              const SizedBox(height: Tokens.space4),
              AsyncPanel<CoveragePlan>(
                value: coverage,
                skeletonCount: 2,
                skeletonHeight: 96,
                onRetry: () => refreshServerData(ref),
                builder: (plan) => _CoverageContent(
                  plan: plan,
                  config: configData,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.health,
    required this.onRefresh,
  });

  final String? name;
  final AsyncValue<HealthStatus> health;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    final healthData = health.asData?.value;

    final (Color color, String label) = switch (health) {
      AsyncLoading() => (surfaces.muted, 'Connexion au serveur…'),
      AsyncError() => (scheme.error, 'Serveur injoignable · données en cache'),
      _ when healthData != null && healthData.isOk => (
          scheme.primary,
          'Serveur OK · API ${healthData.apiVersion}',
        ),
      _ => (surfaces.priorityC, 'Serveur dégradé · base ${healthData?.database ?? '—'}'),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name == null ? 'Bonjour' : 'Bonjour, $name',
                style: Tokens.h1.copyWith(color: scheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: Tokens.space2),
              StatusDot(color: color, label: label),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Actualiser',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

class _CoverageContent extends StatelessWidget {
  const _CoverageContent({required this.plan, this.config});

  final CoveragePlan plan;
  final AppConfig? config;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    final total = plan.served.length +
        plan.opportunistic.length +
        plan.catalog.length +
        plan.disabled.length;
    final zeroBudget = config?.isZeroBudget ?? true;
    final liveEnabled = config?.features.live ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (plan.isDegraded) ...[
          const InfoBanner(
            tone: BannerTone.warning,
            title: 'Cotes automatiques suspendues',
            message:
                'Le quota mensuel est atteint. Le service passe en saisie manuelle '
                'jusqu’au 1er du mois : aucune cote périmée n’est affichée sans son âge.',
          ),
          const SizedBox(height: Tokens.space4),
        ],
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Compétitions servies',
                value: '${plan.served.length}',
                caption: 'sur $total au catalogue',
              ),
            ),
            const SizedBox(width: Tokens.space3),
            Expanded(
              child: StatTile(
                label: 'Crédits restants',
                value: formatCount(plan.quota.remaining),
                caption: 'sur ${formatCount(plan.monthlyBudget)} ce mois',
              ),
            ),
          ],
        ),
        const SizedBox(height: Tokens.space3),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Opportunités',
                value: '—',
                caption: 'dès que les cotes seront vérifiées',
              ),
            ),
            const SizedBox(width: Tokens.space3),
            Expanded(
              child: StatTile(
                label: 'Budget données',
                value: zeroBudget ? '0 €' : '—',
                caption: liveEnabled ? 'live activé' : 'live désactivé',
              ),
            ),
          ],
        ),
        const SizedBox(height: Tokens.space6),
        SectionHeader(
          'Compétitions servies',
          caption: 'Cotes automatiques dans le budget actuel',
          actionLabel: 'Catalogue',
          onAction: () => context.go('/matches'),
        ),
        const SizedBox(height: Tokens.space2),
        if (plan.served.isEmpty)
          const InfoBanner(
            tone: BannerTone.warning,
            message:
                'Aucune compétition n’est servie pour le moment. Le catalogue reste '
                'consultable, sans données inventées.',
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < plan.served.length; i++) ...[
                  if (i > 0) const Divider(),
                  _CoverageRow(entry: plan.served[i]),
                ],
              ],
            ),
          ),
        const SizedBox(height: Tokens.space6),
        const SectionHeader('Opportunités du jour'),
        const SizedBox(height: Tokens.space2),
        EmptyState(
          icon: Icons.query_stats,
          title: 'Aucune opportunité publiée',
          message:
              'Le flux Value s’active uniquement lorsqu’une cote vérifiée et une '
              'probabilité fiable sont disponibles. Le moteur préfère ne rien '
              'recommander plutôt qu’une sélection fragile.',
          footnote:
              'La collecte des rencontres et des cotes n’est pas encore active. '
              'Cet écran restera vide tant que la donnée n’est pas vérifiée.',
          actionLabel: 'Voir le catalogue',
          onAction: () => context.go('/matches'),
        ),
        const SizedBox(height: Tokens.space6),
        const SectionHeader('En direct'),
        const SizedBox(height: Tokens.space2),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Tokens.space4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.sensors_off_outlined, color: surfaces.live),
                const SizedBox(width: Tokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Direct indisponible',
                        style: Tokens.bodyStrong.copyWith(color: scheme.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        liveEnabled
                            ? 'Aucun match en direct suivi pour le moment.'
                            : 'Le mode pilote 0 € ne permet pas de rafraîchir des cotes '
                                'en continu. Aucune recommandation live n’est affichée.',
                        style: Tokens.caption.copyWith(color: surfaces.muted),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => context.go('/live'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(48, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('En savoir plus'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Tokens.space6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.science_outlined, size: 16, color: surfaces.muted),
            const SizedBox(width: Tokens.space2),
            Expanded(
              child: Text(
                'Modèle statistique (dé-vig + Poisson/Elo), pas de modèle ML en v1. '
                'Aucun gain n’est garanti.',
                style: Tokens.caption.copyWith(color: surfaces.muted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CoverageRow extends StatelessWidget {
  const _CoverageRow({required this.entry});

  final CoverageEntry entry;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space4,
        vertical: Tokens.space3,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: Tokens.bodyStrong.copyWith(color: scheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.code} · ${entry.reason}',
                  style: Tokens.caption.copyWith(color: surfaces.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: Tokens.space2),
          const CoverageBadge('served'),
        ],
      ),
    );
  }
}
