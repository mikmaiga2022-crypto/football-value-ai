import 'package:flutter_test/flutter_test.dart';
import 'package:football_value_ai/core/format.dart';
import 'package:football_value_ai/data/models/app_user.dart';
import 'package:football_value_ai/data/models/competition.dart';
import 'package:football_value_ai/data/models/system_status.dart';

void main() {
  group('CoveragePlan', () {
    test('lit le plan complet et le quota renvoyés par le serveur', () {
      final plan = CoveragePlan.fromJson({
        'served': [
          {
            'code': 'FR1',
            'name': 'Ligue 1',
            'state': 'served',
            'reason': 'dans le budget automatique',
          },
        ],
        'opportunistic': [
          {
            'code': 'CAN',
            'name': 'CAN',
            'state': 'opportunistic',
            'reason': 'à la demande, sous réserve de crédits',
          },
        ],
        'catalog': [
          {
            'code': 'ES1',
            'name': 'La Liga',
            'state': 'catalog',
            'reason': 'catalogue seul : quota de crédits épuisé',
          },
        ],
        'disabled': [
          {
            'code': 'RET',
            'name': 'Compétition retirée',
            'state': 'disabled',
            'reason': 'licence non couverte',
          },
        ],
        'monthly_credits': 240,
        'monthly_budget': 270,
        'headroom': 30,
        'quota': {
          'provider': 'the_odds_api',
          'used_today': 3,
          'used_month': 30,
          'monthly_budget': 270,
          'monthly_limit': 500,
          'remaining': 240,
          'exhausted': false,
          'degraded_reason': null,
        },
        'notes': ['plan nominal'],
      });

      expect(plan.served.single.code, 'FR1');
      expect(plan.served.single.reason, 'dans le budget automatique');
      expect(plan.opportunistic.single.name, 'CAN');
      expect(plan.catalog.single.code, 'ES1');
      expect(plan.disabled.single.code, 'RET');
      expect(plan.monthlyCredits, 240);
      expect(plan.monthlyBudget, 270);
      expect(plan.headroom, 30);
      expect(plan.notes, ['plan nominal']);
      expect(plan.quota.provider, 'the_odds_api');
      expect(plan.quota.remaining, 240);
      expect(plan.quota.monthlyLimit, 500);
      expect(plan.quota.exhausted, isFalse);
      expect(plan.isDegraded, isFalse);
      expect(plan.quota.ratio, closeTo(30 / 270, 1e-9));
    });

    test('tolère un plan vide sans inventer de données', () {
      final plan = CoveragePlan.fromJson(const {});

      expect(plan.served, isEmpty);
      expect(plan.opportunistic, isEmpty);
      expect(plan.catalog, isEmpty);
      expect(plan.disabled, isEmpty);
      expect(plan.monthlyCredits, 0);
      expect(plan.monthlyBudget, 0);
      expect(plan.headroom, 0);
      expect(plan.notes, isEmpty);
      expect(plan.quota.usedMonth, 0);
      // Budget inconnu : la jauge est pleine plutôt que divisée par zéro.
      expect(plan.quota.ratio, 1);
    });

    test('un quota épuisé signale un plan dégradé', () {
      final plan = CoveragePlan.fromJson({
        'served': const [],
        'catalog': [
          {
            'code': 'ES1',
            'name': 'La Liga',
            'reason': 'catalogue seul : quota de crédits épuisé',
          },
        ],
        'monthly_credits': 300,
        'monthly_budget': 270,
        'headroom': -30,
        'quota': {
          'used_month': 540,
          'monthly_budget': 270,
          'exhausted': true,
          'degraded_reason': 'arrêt dur : plafond mensuel atteint',
        },
      });

      expect(plan.isDegraded, isTrue);
      expect(plan.quota.ratio, 1, reason: 'la jauge est plafonnée à 100 %');
      expect(plan.quota.degradedReason, 'arrêt dur : plafond mensuel atteint');
    });
  });

  group('Competition', () {
    test('lit tous les champs de couverture', () {
      final competition = Competition.fromJson({
        'code': 'FR1',
        'name': 'Ligue 1',
        'country_code': 'FR',
        'confederation': 'UEFA',
        'is_international': false,
        'tier': 1,
        'season': '2026/2027',
        'coverage_state': 'served',
        'notes': 'trois compétitions servies en pilote',
      });

      expect(competition.name, 'Ligue 1');
      expect(competition.countryCode, 'FR');
      expect(competition.confederation, 'UEFA');
      expect(competition.tier, 1);
      expect(competition.season, '2026/2027');
      expect(competition.isServed, isTrue);
      expect(competition.isOpportunistic, isFalse);
      expect(competition.notes, 'trois compétitions servies en pilote');
    });

    test('applique des valeurs par défaut prudentes', () {
      final competition = Competition.fromJson(const {
        'code': 'INT',
        'name': 'Tournoi international',
      });

      expect(competition.coverageState, 'catalog');
      expect(competition.isServed, isFalse);
      expect(competition.isInternational, isFalse);
      expect(competition.tier, 3);
      expect(competition.countryCode, isNull);
      expect(competition.season, isNull);
    });
  });

  group('AppUser', () {
    test('utilise le nom affiché et la permission globale', () {
      final user = AppUser.fromJson({
        'id': 'u_1',
        'email': 'alex@exemple.com',
        'role': 'analyst',
        'permissions': ['*'],
        'display_name': 'Alex Martin',
        'locale': 'fr',
        'timezone': 'Europe/Paris',
      });

      expect(user.shortName, 'Alex Martin');
      expect(user.timezone, 'Europe/Paris');
      expect(user.can('matches.read'), isTrue);
      expect(user.can('admin.users'), isTrue);
    });

    test('retombe sur la partie locale de l’e-mail', () {
      final user = AppUser.fromJson(const {
        'id': 'u_2',
        'email': 'sam@exemple.com',
        'permissions': ['matches.read'],
      });

      expect(user.role, 'user');
      expect(user.shortName, 'sam');
      expect(user.locale, 'fr');
      expect(user.can('matches.read'), isTrue);
      expect(user.can('value.read'), isFalse);
    });
  });

  group('Méta-information serveur', () {
    test('HealthStatus expose l’état réel de la base', () {
      final health = HealthStatus.fromJson({
        'status': 'ok',
        'database': 'ok',
        'environment': 'production',
        'api_version': '1.2.0',
        'uptime_seconds': 3600,
      });

      expect(health.isOk, isTrue);
      expect(health.apiVersion, '1.2.0');
      expect(health.uptimeSeconds, 3600);

      final degraded = HealthStatus.fromJson({
        'status': 'ok',
        'database': 'down',
      });
      expect(degraded.isOk, isFalse);
      expect(degraded.apiVersion, '');
    });

    test('AppConfig lit le mode 0 € et les drapeaux de fonctionnalités', () {
      final config = AppConfig.fromJson({
        'min_app_version': '0.1.0',
        'latest_app_version': '0.2.0',
        'data_mode': 'zero_budget',
        'maintenance': false,
        'features': {
          'value_betting': true,
          'live': false,
          'manual_odds': true,
        },
        'legal': {'disclaimer_version': '1.0.0'},
      });

      expect(config.isZeroBudget, isTrue);
      expect(config.features.valueBetting, isTrue);
      expect(config.features.live, isFalse);
      expect(config.features.manualOdds, isTrue);
      expect(config.features.notifications, isFalse);
      expect(config.legal['disclaimer_version'], '1.0.0');

      final minimal = AppConfig.fromJson(const {});
      expect(minimal.dataMode, 'zero_budget');
      expect(minimal.maintenance, isFalse);
      expect(minimal.features.valueBetting, isFalse);
      expect(minimal.legal, isEmpty);
    });

    test('Disclaimer garde le texte du serveur tel quel', () {
      final disclaimer = Disclaimer.fromJson({
        'version': '2.0.0',
        'updated_at': '2026-10-30T00:00:00Z',
        'text': 'Texte juridique serveur.',
      });

      expect(disclaimer.version, '2.0.0');
      expect(disclaimer.updatedAt, '2026-10-30T00:00:00Z');
      expect(disclaimer.text, 'Texte juridique serveur.');
      expect(Disclaimer.fromJson(const {}).text, '');
    });
  });

  group('Formatage français', () {
    test('sépare les milliers et arrondit les pourcentages', () {
      expect(formatCount(30), '30');
      // intl peut utiliser une espace fine insécable selon la version.
      final grouped = formatCount(1250)
          .replaceAll('\u202F', ' ')
          .replaceAll('\u00A0', ' ');
      expect(grouped, '1 250');
      expect(formatPercent(1 / 3), '33,3 %');
      expect(formatPercent(0.131), '13,1 %');
    });
  });
}
