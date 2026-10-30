import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/providers.dart';
import '../../data/models/competition.dart';
import '../../data/models/match.dart';
import '../../widgets/async_panel.dart';
import '../../widgets/coverage_badge.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/section_header.dart';

enum _CoverageFilter {
  all(null, 'Tout'),
  served('served', 'Servies'),
  opportunistic('opportunistic', 'À la demande'),
  catalog('catalog', 'Catalogue'),
  disabled('disabled', 'Désactivées');

  const _CoverageFilter(this.state, this.label);

  final String? state;
  final String label;
}

class MatchesScreen extends ConsumerStatefulWidget {
  const MatchesScreen({super.key});

  @override
  ConsumerState<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends ConsumerState<MatchesScreen> {
  final _search = TextEditingController();
  _CoverageFilter _filter = _CoverageFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _search.clear();
      _filter = _CoverageFilter.all;
    });
  }

  @override
  Widget build(BuildContext context) {
    final competitions = ref.watch(competitionsProvider);
    final coverage = ref.watch(coverageProvider).asData?.value;
    final surfaces = context.surfaces;

    final reasons = {
      for (final entry in [
        ...?coverage?.served,
        ...?coverage?.opportunistic,
        ...?coverage?.catalog,
        ...?coverage?.disabled,
      ])
        entry.code: entry.reason,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matchs'),
        actions: [
          IconButton(
            tooltip: 'Actualiser le catalogue',
            onPressed: () {
              ref.invalidate(competitionsProvider);
              ref.invalidate(coverageProvider);
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
                  'Le catalogue des compétitions est réel. Une rencontre n’apparaît '
                  'que lorsque sa collecte et ses cotes sont vérifiées : aucune affiche '
                  'n’est inventée pour remplir l’écran.',
            ),
            const SizedBox(height: Tokens.space4),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Rechercher une compétition',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Effacer la recherche',
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: Tokens.space3),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final filter in _CoverageFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: Tokens.space2),
                      child: ChoiceChip(
                        label: Text(filter.label),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                        labelStyle: Tokens.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _filter == filter
                              ? Theme.of(context).colorScheme.onSurface
                              : surfaces.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Tokens.space4),
            SectionHeader(
              'Catalogue',
              caption: 'États de couverture mis à jour par le serveur',
            ),
            const SizedBox(height: Tokens.space2),
            AsyncPanel<List<Competition>>(
              value: competitions,
              skeletonCount: 4,
              skeletonHeight: 76,
              onRetry: () => refreshServerData(ref),
              builder: (all) {
                final query = _search.text.trim().toLowerCase();
                final filtered = all.where((competition) {
                  final matchesState = _filter.state == null ||
                      competition.coverageState == _filter.state;
                  final matchesQuery = query.isEmpty ||
                      competition.name.toLowerCase().contains(query) ||
                      competition.code.toLowerCase().contains(query);
                  return matchesState && matchesQuery;
                }).toList(growable: false);

                if (all.isEmpty) {
                  return const EmptyState(
                    icon: Icons.public_off,
                    title: 'Catalogue vide',
                    message:
                        'Aucune compétition n’est encore enregistrée. Le catalogue sera '
                        'alimenté par la collecte, jamais par des données inventées.',
                  );
                }

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    title: 'Aucun résultat',
                    message: query.isEmpty
                        ? 'Aucune compétition ne correspond à ce filtre.'
                        : 'Aucune compétition ne correspond à « ${_search.text.trim()} ».',
                    actionLabel: 'Effacer les filtres',
                    onAction: _clearFilters,
                  );
                }

                return Column(
                  children: [
                    for (final competition in filtered)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Tokens.space3),
                        child: _CompetitionCard(
                          competition: competition,
                          reason: reasons[competition.code],
                          onTap: () => _showCompetition(
                            context,
                            competition,
                            reasons[competition.code],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: Tokens.space6),
            SectionHeader(
              'Rencontres collectées',
              caption: 'Données réelles uniquement, avec source et horodatage',
            ),
            const SizedBox(height: Tokens.space2),
            AsyncPanel<List<MatchItem>>(
              value: ref.watch(matchesProvider),
              skeletonCount: 3,
              skeletonHeight: 88,
              onRetry: () => refreshServerData(ref),
              builder: (matches) {
                if (matches.isEmpty) {
                  return const EmptyState(
                    icon: Icons.sports_soccer_outlined,
                    title: 'Aucune rencontre collectée',
                    message:
                        'Les rencontres apparaîtront ici dès que la collecte sera active '
                        'et contrôlée. Aucune affiche n’est inventée.',
                  );
                }
                return Column(
                  children: [
                    for (final match in matches)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Tokens.space3),
                        child: _MatchCard(match: match),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: Tokens.space4),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Tokens.space4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.event_busy_outlined, color: surfaces.muted),
                    const SizedBox(width: Tokens.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rencontres et cotes à venir',
                            style: Tokens.bodyStrong.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Les fiches match, statistiques et marchés seront publiés '
                            'quand la collecte sera active et contrôlée. Le catalogue '
                            'ci-dessus est la seule donnée métier disponible aujourd’hui.',
                            style: Tokens.caption.copyWith(color: surfaces.muted),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => context.go('/value'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(48, 36),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Comprendre le flux Value'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCompetition(
    BuildContext context,
    Competition competition,
    String? reason,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final surfaces = sheetContext.surfaces;
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Tokens.screenPadding,
              0,
              Tokens.screenPadding,
              Tokens.space6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        competition.name,
                        style: Tokens.h1.copyWith(color: scheme.onSurface),
                      ),
                    ),
                    const SizedBox(width: Tokens.space2),
                    CoverageBadge(competition.coverageState),
                  ],
                ),
                const SizedBox(height: Tokens.space2),
                Text(
                  [
                    competition.code,
                    if (competition.isInternational) 'International',
                    if (competition.countryCode != null) competition.countryCode!,
                    if (competition.confederation != null) competition.confederation!,
                    if (competition.season != null) competition.season!,
                    'Tier ${competition.tier}',
                  ].join(' · '),
                  style: Tokens.caption.copyWith(color: surfaces.muted),
                ),
                const SizedBox(height: Tokens.space4),
                const Divider(),
                const SizedBox(height: Tokens.space4),
                _SheetRow(
                  label: 'Couverture',
                  value: reason ?? 'État fourni par le serveur.',
                ),
                if (competition.notes != null && competition.notes!.isNotEmpty) ...[
                  const SizedBox(height: Tokens.space3),
                  _SheetRow(label: 'Note', value: competition.notes!),
                ],
                const SizedBox(height: Tokens.space4),
                const InfoBanner(
                  tone: BannerTone.info,
                  message:
                      'Aucune rencontre n’est publiée pour cette compétition tant que '
                      'la collecte et la vérification des cotes ne sont pas actives.',
                ),
                const SizedBox(height: Tokens.space4),
                Text(
                  'Les probabilités sont des estimations. Aucun gain n’est garanti.',
                  style: Tokens.caption.copyWith(color: surfaces.muted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});

  final MatchItem match;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    final kickoff = match.kickoffUtc.toLocal();
    final dateLabel =
        '${kickoff.day.toString().padLeft(2, '0')}/'
        '${kickoff.month.toString().padLeft(2, '0')} '
        '${kickoff.hour.toString().padLeft(2, '0')}:'
        '${kickoff.minute.toString().padLeft(2, '0')}';

    return Card(
      child: InkWell(
        onTap: () => context.push('/matches/${match.id}'),
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${match.homeTeam.displayName} vs ${match.awayTeam.displayName}',
                      style: Tokens.bodyStrong.copyWith(color: scheme.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: Tokens.space2),
                  Text(
                    match.scoreLabel,
                    style: Tokens.number.copyWith(color: scheme.onSurface),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${match.competitionCode} · $dateLabel · ${match.status}',
                style: Tokens.caption.copyWith(color: surfaces.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompetitionCard extends StatelessWidget {
  const _CompetitionCard({
    required this.competition,
    this.reason,
    this.onTap,
  });

  final Competition competition;
  final String? reason;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;

    final subtitle = [
      competition.code,
      if (competition.countryCode != null) competition.countryCode!,
      if (competition.season != null) competition.season!,
    ].join(' · ');

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: surfaces.surfaceAlt,
                  borderRadius: BorderRadius.circular(Tokens.radiusButton),
                  border: Border.all(color: surfaces.border),
                ),
                child: Icon(
                  competition.isInternational ? Icons.public : Icons.flag_outlined,
                  size: 20,
                  color: surfaces.muted,
                ),
              ),
              const SizedBox(width: Tokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      competition.name,
                      style: Tokens.bodyStrong.copyWith(
                        fontSize: 16,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Tokens.caption.copyWith(color: surfaces.muted),
                    ),
                    if (reason != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        reason!,
                        style: Tokens.caption.copyWith(color: surfaces.muted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Tokens.space2),
              CoverageBadge(competition.coverageState),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.label, required this.value});

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
          style: Tokens.body.copyWith(color: Theme.of(context).colorScheme.onSurface),
        ),
      ],
    );
  }
}
