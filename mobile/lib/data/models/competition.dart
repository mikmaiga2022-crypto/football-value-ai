/// Compétition du catalogue, avec son état de couverture réel.
class Competition {
  const Competition({
    required this.code,
    required this.name,
    required this.coverageState,
    this.countryCode,
    this.confederation,
    this.isInternational = false,
    this.tier = 3,
    this.season,
    this.notes,
  });

  final String code;
  final String name;
  final String coverageState;
  final String? countryCode;
  final String? confederation;
  final bool isInternational;
  final int tier;
  final String? season;
  final String? notes;

  bool get isServed => coverageState == 'served';
  bool get isOpportunistic => coverageState == 'opportunistic';

  factory Competition.fromJson(Map<String, dynamic> json) {
    return Competition(
      code: json['code'] as String,
      name: json['name'] as String,
      coverageState: json['coverage_state'] as String? ?? 'catalog',
      countryCode: json['country_code'] as String?,
      confederation: json['confederation'] as String?,
      isInternational: json['is_international'] as bool? ?? false,
      tier: (json['tier'] as num?)?.toInt() ?? 3,
      season: json['season'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

/// État du quota de crédits cotes (voir docs/09 §3.3).
class QuotaState {
  const QuotaState({
    required this.provider,
    required this.usedToday,
    required this.usedMonth,
    required this.monthlyBudget,
    required this.monthlyLimit,
    required this.remaining,
    required this.exhausted,
    this.degradedReason,
  });

  final String provider;
  final int usedToday;
  final int usedMonth;
  final int monthlyBudget;
  final int monthlyLimit;
  final int remaining;
  final bool exhausted;
  final String? degradedReason;

  double get ratio => monthlyBudget == 0 ? 1 : (usedMonth / monthlyBudget).clamp(0, 1);

  factory QuotaState.fromJson(Map<String, dynamic> json) {
    return QuotaState(
      provider: json['provider'] as String? ?? 'the_odds_api',
      usedToday: (json['used_today'] as num?)?.toInt() ?? 0,
      usedMonth: (json['used_month'] as num?)?.toInt() ?? 0,
      monthlyBudget: (json['monthly_budget'] as num?)?.toInt() ?? 0,
      monthlyLimit: (json['monthly_limit'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
      exhausted: json['exhausted'] as bool? ?? false,
      degradedReason: json['degraded_reason'] as String?,
    );
  }
}

class CoverageEntry {
  const CoverageEntry({required this.code, required this.name, required this.reason});

  final String code;
  final String name;
  final String reason;
}

/// Plan de couverture effectif : ce qui est servi automatiquement, et ce qui ne l'est pas.
class CoveragePlan {
  const CoveragePlan({
    required this.served,
    required this.opportunistic,
    required this.catalog,
    required this.disabled,
    required this.monthlyCredits,
    required this.monthlyBudget,
    required this.headroom,
    required this.quota,
    this.notes = const [],
  });

  final List<CoverageEntry> served;
  final List<CoverageEntry> opportunistic;
  final List<CoverageEntry> catalog;
  final List<CoverageEntry> disabled;
  final int monthlyCredits;
  final int monthlyBudget;
  final int headroom;
  final QuotaState quota;
  final List<String> notes;

  bool get isDegraded => quota.exhausted;

  factory CoveragePlan.fromJson(Map<String, dynamic> json) {
    List<CoverageEntry> parse(String key) {
      return (json[key] as List<dynamic>? ?? const [])
          .map(
            (raw) => CoverageEntry(
              code: (raw as Map)['code'] as String,
              name: raw['name'] as String,
              reason: raw['reason'] as String? ?? '',
            ),
          )
          .toList(growable: false);
    }

    return CoveragePlan(
      served: parse('served'),
      opportunistic: parse('opportunistic'),
      catalog: parse('catalog'),
      disabled: parse('disabled'),
      monthlyCredits: (json['monthly_credits'] as num?)?.toInt() ?? 0,
      monthlyBudget: (json['monthly_budget'] as num?)?.toInt() ?? 0,
      headroom: (json['headroom'] as num?)?.toInt() ?? 0,
      quota: QuotaState.fromJson(
        Map<String, dynamic>.from(json['quota'] as Map? ?? const {}),
      ),
      notes: (json['notes'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
    );
  }
}
