import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_value_ai/app/app.dart';
import 'package:football_value_ai/app/theme/app_theme.dart';
import 'package:football_value_ai/core/auth/session.dart';
import 'package:football_value_ai/core/providers.dart';
import 'package:football_value_ai/data/models/app_user.dart';
import 'package:football_value_ai/data/models/competition.dart';
import 'package:football_value_ai/data/models/match.dart';
import 'package:football_value_ai/data/models/system_status.dart';
import 'package:football_value_ai/data/models/value_bet.dart';

const testUser = AppUser(
  id: 'u_test_1',
  email: 'alex@exemple.com',
  role: 'user',
  permissions: ['matches.read', 'value.read'],
  displayName: 'Alex',
);

const testHealth = HealthStatus(
  status: 'ok',
  database: 'ok',
  environment: 'test',
  apiVersion: '1.0.0',
  uptimeSeconds: 42,
);

const testConfig = AppConfig(
  minAppVersion: '0.1.0',
  latestAppVersion: '0.1.0',
  dataMode: 'zero_budget',
  features: FeatureFlags(
    valueBetting: true,
    manualOdds: true,
  ),
);

const testDisclaimer = Disclaimer(
  version: '1.0.0',
  updatedAt: '2026-10-30T00:00:00Z',
  text: 'Texte juridique renvoyé par le serveur.',
);

const testQuota = QuotaState(
  provider: 'the_odds_api',
  usedToday: 3,
  usedMonth: 30,
  monthlyBudget: 270,
  monthlyLimit: 500,
  remaining: 240,
  exhausted: false,
);

const testCoverage = CoveragePlan(
  served: [
    CoverageEntry(code: 'FR1', name: 'Ligue 1', reason: 'dans le budget automatique'),
    CoverageEntry(code: 'EPL', name: 'Premier League', reason: 'dans le budget automatique'),
    CoverageEntry(code: 'CAN', name: 'CAN', reason: 'dans le budget automatique'),
  ],
  opportunistic: [],
  catalog: [
    CoverageEntry(
      code: 'ES1',
      name: 'La Liga',
      reason: 'catalogue seul : quota de crédits épuisé',
    ),
  ],
  disabled: [],
  monthlyCredits: 270,
  monthlyBudget: 270,
  headroom: 0,
  quota: testQuota,
);

const testCompetitions = [
  Competition(
    code: 'FR1',
    name: 'Ligue 1',
    coverageState: 'served',
    countryCode: 'FR',
    confederation: 'UEFA',
    tier: 1,
    season: '2026/2027',
  ),
  Competition(
    code: 'EPL',
    name: 'Premier League',
    coverageState: 'served',
    countryCode: 'GB',
    confederation: 'UEFA',
    tier: 1,
    season: '2026/2027',
  ),
  Competition(
    code: 'ES1',
    name: 'La Liga',
    coverageState: 'catalog',
    countryCode: 'ES',
    confederation: 'UEFA',
    tier: 1,
  ),
];

/// Session authentifiée sans restauration réseau ni Keystore.
class AuthenticatedTestSession extends SessionController {
  @override
  SessionState build() =>
      const SessionState(status: SessionStatus.authenticated, user: testUser);
}

/// Session déconnectée sans appel réseau.
class LoggedOutTestSession extends SessionController {
  @override
  SessionState build() => const SessionState(status: SessionStatus.unauthenticated);
}

/// Application complète avec données serveur figées : aucun appel HTTP.
Widget buildTestApp({SessionController Function()? session}) {
  return ProviderScope(
    overrides: [
      sessionProvider.overrideWith(session ?? AuthenticatedTestSession.new),
      coverageProvider.overrideWith((ref) async => testCoverage),
      competitionsProvider.overrideWith((ref) async => testCompetitions),
      matchesProvider.overrideWith((ref) async => const <MatchItem>[]),
      valueBetsProvider.overrideWith((ref) async => const <ValueBetItem>[]),
      healthProvider.overrideWith((ref) async => testHealth),
      appConfigProvider.overrideWith((ref) async => testConfig),
      disclaimerProvider.overrideWith((ref) async => testDisclaimer),
    ],
    child: const FootballValueAiApp(),
  );
}

/// Écran isolé (auth) avec la même session de test.
Widget buildIsolatedScreen({
  required Widget child,
  SessionController Function()? session,
}) {
  return ProviderScope(
    overrides: [
      sessionProvider.overrideWith(session ?? LoggedOutTestSession.new),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: child,
    ),
  );
}

/// Surface de test 360 × 800 dp, proche d'un Android d'entrée de gamme.
Future<void> pumpApp(
  WidgetTester tester,
  Widget app, {
  Size size = const Size(1080, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}
