import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/session.dart';
import '../data/models/competition.dart';
import '../data/models/match.dart';
import '../data/models/prediction.dart';
import '../data/models/system_status.dart';
import '../data/models/value_bet.dart';
import '../data/repositories/matches_repository.dart';
import '../data/repositories/predictions_repository.dart';
import '../data/repositories/system_repository.dart';
import '../data/repositories/value_bets_repository.dart';

/// Données serveur lisibles par l'interface. Aucun calcul métier ici :
/// l'app affiche ce que l'API renvoie, ou un état vide explicite.

final systemRepositoryProvider = Provider<SystemRepository>(
  (ref) => SystemRepository(ref.watch(apiClientProvider)),
);

/// Plan de couverture effectif + quota fournisseur (docs/09 §3).
final coverageProvider = FutureProvider<CoveragePlan>(
  (ref) => ref.watch(catalogRepositoryProvider).coverage(),
);

/// Catalogue complet des compétitions connues (50 = plafond de l'API v1).
final competitionsProvider = FutureProvider<List<Competition>>(
  (ref) => ref.watch(catalogRepositoryProvider).competitions(limit: 50),
);

final healthProvider = FutureProvider<HealthStatus>(
  (ref) => ref.watch(systemRepositoryProvider).health(),
);

final appConfigProvider = FutureProvider<AppConfig>(
  (ref) => ref.watch(systemRepositoryProvider).config(),
);

final disclaimerProvider = FutureProvider<Disclaimer>(
  (ref) => ref.watch(systemRepositoryProvider).disclaimer(),
);

final matchesRepositoryProvider = Provider<MatchesRepository>(
  (ref) => MatchesRepository(ref.watch(apiClientProvider)),
);

/// Rencontres réellement collectées (Phase 3). Vide tant que la collecte n'est pas active.
final matchesProvider = FutureProvider<List<MatchItem>>(
  (ref) => ref.watch(matchesRepositoryProvider).list(limit: 50),
);

final matchDetailProvider = FutureProvider.family<MatchItem, String>(
  (ref, id) => ref.watch(matchesRepositoryProvider).get(id),
);

final matchOddsProvider = FutureProvider.family<List<OddsSnapshotItem>, String>(
  (ref, id) => ref.watch(matchesRepositoryProvider).latestOdds(id),
);
/// le bandeau de chaque section les affiche déjà.
final predictionsRepositoryProvider = Provider<PredictionsRepository>(
  (ref) => PredictionsRepository(ref.watch(apiClientProvider)),
);

final matchPredictionsProvider = FutureProvider.family<List<PredictionItem>, String>(
  (ref, matchId) => ref.watch(predictionsRepositoryProvider).forMatch(matchId),
);

final valueBetsRepositoryProvider = Provider<ValueBetsRepository>(
  (ref) => ValueBetsRepository(ref.watch(apiClientProvider)),
);

final valueBetsProvider = FutureProvider<List<ValueBetItem>>(
  (ref) => ref.watch(valueBetsRepositoryProvider).list(limit: 50),
);

Future<void> refreshServerData(WidgetRef ref) async {
  ref.invalidate(coverageProvider);
  ref.invalidate(competitionsProvider);
  ref.invalidate(matchesProvider);
  ref.invalidate(valueBetsProvider);
  ref.invalidate(healthProvider);
  ref.invalidate(appConfigProvider);
  ref.invalidate(disclaimerProvider);

  Future<void> guard(Future<Object?> future) async {
    try {
      await future;
    } on Exception {
      // L'état d'erreur est rendu par AsyncPanel/AsyncValue.
    }
  }

  await Future.wait([
    guard(ref.read(coverageProvider.future)),
    guard(ref.read(competitionsProvider.future)),
    guard(ref.read(healthProvider.future)),
    guard(ref.read(appConfigProvider.future)),
  ]);
}
