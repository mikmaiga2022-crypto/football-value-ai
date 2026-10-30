class PredictionItem {
  const PredictionItem({
    required this.id,
    required this.matchId,
    required this.modelVersionId,
    required this.marketCode,
    required this.selectionCode,
    required this.probability,
    required this.ciLow,
    required this.ciHigh,
    this.line,
    this.dataQualityScore = 0.5,
  });

  final String id;
  final String matchId;
  final String modelVersionId;
  final String marketCode;
  final String selectionCode;
  final double? line;
  final double probability;
  final double ciLow;
  final double ciHigh;
  final double dataQualityScore;

  factory PredictionItem.fromJson(Map<String, dynamic> json) {
    return PredictionItem(
      id: json['id'] as String,
      matchId: json['match_id'] as String,
      modelVersionId: json['model_version_id'] as String,
      marketCode: json['market_code'] as String,
      selectionCode: json['selection_code'] as String,
      line: (json['line'] as num?)?.toDouble(),
      probability: (json['probability'] as num).toDouble(),
      ciLow: (json['ci_low'] as num).toDouble(),
      ciHigh: (json['ci_high'] as num).toDouble(),
      dataQualityScore: (json['data_quality_score'] as num?)?.toDouble() ?? 0.5,
    );
  }
}
