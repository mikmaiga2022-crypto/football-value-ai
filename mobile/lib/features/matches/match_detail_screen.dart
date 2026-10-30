import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/providers.dart';
import '../../data/models/match.dart';
import '../../data/models/prediction.dart';
import '../../widgets/async_panel.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/section_header.dart';

class MatchDetailScreen extends ConsumerWidget {
  const MatchDetailScreen({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final match = ref.watch(matchDetailProvider(matchId));
    final odds = ref.watch(matchOddsProvider(matchId));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Fiche rencontre')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(matchDetailProvider(matchId));
          ref.invalidate(matchOddsProvider(matchId));
          await Future<void>.delayed(Duration.zero);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            Tokens.screenPadding,
            0,
            Tokens.screenPadding,
            Tokens.space8,
          ),
          children: [
            AsyncPanel<MatchItem>(
              value: match,
              skeletonCount: 1,
              skeletonHeight: 120,
              onRetry: () async {
                ref.invalidate(matchDetailProvider(matchId));
              },
              builder: (data) => _MatchHeader(match: data),
            ),
            const SizedBox(height: Tokens.space6),
            const SectionHeader('Probabilités (modèle statistique)'),
            const SizedBox(height: Tokens.space2),
            AsyncPanel<List<PredictionItem>>(
              value: ref.watch(matchPredictionsProvider(matchId)),
              skeletonCount: 3,
              skeletonHeight: 56,
              onRetry: () async => ref.invalidate(matchPredictionsProvider(matchId)),
              builder: (predictions) {
                if (predictions.isEmpty) {
                  return const EmptyState(
                    icon: Icons.insights_outlined,
                    title: 'Aucune prédiction',
                    message:
                        'Les probabilités apparaîtront ici dès que le moteur sera '
                        'exécuté sur cette rencontre.',
                  );
                }
                return Column(
                  children: [
                    for (final prediction in predictions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Tokens.space2),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(Tokens.space4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${prediction.marketCode} · ${prediction.selectionCode}'
                                    '${prediction.line == null ? '' : ' ${prediction.line}'}',
                                    style: Tokens.body.copyWith(color: scheme.onSurface),
                                  ),
                                ),
                                Text(
                                  '${(prediction.probability * 100).toStringAsFixed(1)} %',
                                  style: Tokens.number.copyWith(color: scheme.onSurface),
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
            const SectionHeader('Cotes observées'),
            const SizedBox(height: Tokens.space2),
            AsyncPanel<List<OddsSnapshotItem>>(
              value: odds,
              skeletonCount: 3,
              skeletonHeight: 64,
              onRetry: () async => ref.invalidate(matchOddsProvider(matchId)),
              builder: (snapshots) {
                if (snapshots.isEmpty) {
                  return const EmptyState(
                    icon: Icons.query_stats,
                    title: 'Aucune cote récente',
                    message:
                        'Les cotes apparaîtront ici dès que la collecte sera active '
                        'et dans la limite de fraîcheur. Aucune cote n’est inventée.',
                  );
                }
                return Column(
                  children: [
                    for (final snapshot in snapshots)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Tokens.space2),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(Tokens.space4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${snapshot.bookmakerCode} · '
                                    '${snapshot.marketCode} · ${snapshot.selectionCode}'
                                    '${snapshot.line == null ? '' : ' ${snapshot.line}'}',
                                    style: Tokens.body.copyWith(color: scheme.onSurface),
                                  ),
                                ),
                                Text(
                                  snapshot.decimalOdds.toStringAsFixed(2),
                                  style: Tokens.number.copyWith(color: scheme.onSurface),
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
            const SizedBox(height: Tokens.space4),
            const InfoBanner(
              tone: BannerTone.info,
              message:
                  'Cotes datées : vérifiez leur disponibilité dans votre pays avant '
                  'toute décision. Aucun gain n’est garanti.',
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchHeader extends StatelessWidget {
  const _MatchHeader({required this.match});

  final MatchItem match;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;
    final kickoff = match.kickoffUtc.toLocal();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${match.homeTeam.displayName} vs ${match.awayTeam.displayName}',
              style: Tokens.h2.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: Tokens.space2),
            Text(
              '${match.competitionCode} · ${match.status}',
              style: Tokens.caption.copyWith(color: surfaces.muted),
            ),
            const SizedBox(height: Tokens.space2),
            Text(
              'Coup d’envoi : ${kickoff.day.toString().padLeft(2, '0')}/'
              '${kickoff.month.toString().padLeft(2, '0')} '
              '${kickoff.hour.toString().padLeft(2, '0')}:'
              '${kickoff.minute.toString().padLeft(2, '0')}',
              style: Tokens.body.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: Tokens.space2),
            Text(
              'Score : ${match.scoreLabel}',
              style: Tokens.bodyStrong.copyWith(color: scheme.onSurface),
            ),
            if (match.lastSyncedAt != null) ...[
              const SizedBox(height: Tokens.space2),
              Text(
                'Dernière synchro : ${match.lastSyncedAt!.toLocal()}',
                style: Tokens.caption.copyWith(color: surfaces.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
