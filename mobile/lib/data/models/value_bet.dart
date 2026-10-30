class ValueBetItem {
  const ValueBetItem({
    required this.id,
    required this.matchId,
    required this.marketCode,
    required this.selectionCode,
    required this.priority,
    required this.score,
    required this.ev,
    required this.evLower,
    required this.fairOdds,
    this.line,
    this.status = 'active',
  });

  final String id;
  final String matchId;
  final String marketCode;
  final String selectionCode;
  final double? line;
  final double fairOdds;
  final double ev;
  final double evLower;
  final double score;
  final String priority;
  final String status;

  factory ValueBetItem.fromJson(Map<String, dynamic> json) {
    return ValueBetItem(
      id: json['id'] as String,
      matchId: json['match_id'] as String,
      marketCode: json['market_code'] as String,
      selectionCode: json['selection_code'] as String,
      line: (json['line'] as num?)?.toDouble(),
      fairOdds: (json['fair_odds'] as num).toDouble(),
      ev: (json['ev'] as num).toDouble(),
      evLower: (json['ev_lower'] as num).toDouble(),
      score: (json['score'] as num).toDouble(),
      priority: json['priority'] as String,
      status: json['status'] as String? ?? 'active',
    );
  }
}
