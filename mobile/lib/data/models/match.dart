/// Rencontre et cote observée — données réelles collectées par le backend (Phase 3).
library;

class TeamInfo {
  const TeamInfo({
    required this.id,
    required this.name,
    this.shortName,
    this.countryCode,
    this.logoUrl,
  });

  final String id;
  final String name;
  final String? shortName;
  final String? countryCode;
  final String? logoUrl;

  String get displayName => shortName ?? name;

  factory TeamInfo.fromJson(Map<String, dynamic> json) {
    return TeamInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      shortName: json['short_name'] as String?,
      countryCode: json['country_code'] as String?,
      logoUrl: json['logo_url'] as String?,
    );
  }
}

class MatchItem {
  const MatchItem({
    required this.id,
    required this.competitionCode,
    required this.kickoffUtc,
    required this.status,
    required this.homeTeam,
    required this.awayTeam,
    this.season,
    this.round,
    this.minute,
    this.homeScore,
    this.awayScore,
    this.homeScoreHt,
    this.awayScoreHt,
    this.dataQualityScore = 0.5,
    this.sourceId = '',
    this.lastSyncedAt,
  });

  final String id;
  final String competitionCode;
  final String? season;
  final String? round;
  final DateTime kickoffUtc;
  final String status;
  final int? minute;
  final TeamInfo homeTeam;
  final TeamInfo awayTeam;
  final int? homeScore;
  final int? awayScore;
  final int? homeScoreHt;
  final int? awayScoreHt;
  final double dataQualityScore;
  final String sourceId;
  final DateTime? lastSyncedAt;

  bool get isFinished => status == 'finished';
  bool get isLive => status == 'live' || status == 'halftime';

  String get scoreLabel {
    if (homeScore == null || awayScore == null) return '— : —';
    return '$homeScore : $awayScore';
  }

  factory MatchItem.fromJson(Map<String, dynamic> json) {
    return MatchItem(
      id: json['id'] as String,
      competitionCode: json['competition_code'] as String,
      season: json['season'] as String?,
      round: json['round'] as String?,
      kickoffUtc: DateTime.parse(json['kickoff_utc'] as String).toUtc(),
      status: json['status'] as String? ?? 'scheduled',
      minute: (json['minute'] as num?)?.toInt(),
      homeTeam: TeamInfo.fromJson(Map<String, dynamic>.from(json['home_team'] as Map)),
      awayTeam: TeamInfo.fromJson(Map<String, dynamic>.from(json['away_team'] as Map)),
      homeScore: (json['home_score'] as num?)?.toInt(),
      awayScore: (json['away_score'] as num?)?.toInt(),
      homeScoreHt: (json['home_score_ht'] as num?)?.toInt(),
      awayScoreHt: (json['away_score_ht'] as num?)?.toInt(),
      dataQualityScore: (json['data_quality_score'] as num?)?.toDouble() ?? 0.5,
      sourceId: json['source_id'] as String? ?? '',
      lastSyncedAt: json['last_synced_at'] == null
          ? null
          : DateTime.parse(json['last_synced_at'] as String).toUtc(),
    );
  }
}

class OddsSnapshotItem {
  const OddsSnapshotItem({
    required this.id,
    required this.matchId,
    required this.bookmakerCode,
    required this.marketCode,
    required this.selectionCode,
    required this.decimalOdds,
    required this.isVerified,
    required this.isAvailable,
    required this.observedAt,
    this.line,
    this.sourceId = '',
  });

  final String id;
  final String matchId;
  final String bookmakerCode;
  final String marketCode;
  final String selectionCode;
  final double? line;
  final double decimalOdds;
  final bool isVerified;
  final bool isAvailable;
  final DateTime observedAt;
  final String sourceId;

  factory OddsSnapshotItem.fromJson(Map<String, dynamic> json) {
    return OddsSnapshotItem(
      id: json['id'] as String,
      matchId: json['match_id'] as String,
      bookmakerCode: json['bookmaker_code'] as String,
      marketCode: json['market_code'] as String,
      selectionCode: json['selection_code'] as String,
      line: (json['line'] as num?)?.toDouble(),
      decimalOdds: (json['decimal_odds'] as num).toDouble(),
      isVerified: json['is_verified'] as bool? ?? false,
      isAvailable: json['is_available'] as bool? ?? true,
      observedAt: DateTime.parse(json['observed_at'] as String).toUtc(),
      sourceId: json['source_id'] as String? ?? '',
    );
  }
}
