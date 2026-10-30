/// Méta-information serveur : santé, configuration et avertissement légal.
///
/// Ces modèles ne contiennent aucune donnée métier calculée : ils reflètent
/// uniquement ce que l'API expose (docs/04 §3.10).
library;

class HealthStatus {
  const HealthStatus({
    required this.status,
    required this.database,
    required this.environment,
    required this.apiVersion,
    required this.uptimeSeconds,
  });

  final String status;
  final String database;
  final String environment;
  final String apiVersion;
  final int uptimeSeconds;

  bool get isOk => status == 'ok' && database == 'ok';

  factory HealthStatus.fromJson(Map<String, dynamic> json) {
    return HealthStatus(
      status: json['status'] as String? ?? 'unknown',
      database: json['database'] as String? ?? 'unknown',
      environment: json['environment'] as String? ?? '',
      apiVersion: json['api_version'] as String? ?? '',
      uptimeSeconds: (json['uptime_seconds'] as num?)?.toInt() ?? 0,
    );
  }
}

class FeatureFlags {
  const FeatureFlags({
    this.valueBetting = false,
    this.live = false,
    this.manualOdds = false,
    this.simulation = false,
    this.notifications = false,
  });

  final bool valueBetting;
  final bool live;
  final bool manualOdds;
  final bool simulation;
  final bool notifications;

  factory FeatureFlags.fromJson(Map<String, dynamic> json) {
    return FeatureFlags(
      valueBetting: json['value_betting'] as bool? ?? false,
      live: json['live'] as bool? ?? false,
      manualOdds: json['manual_odds'] as bool? ?? false,
      simulation: json['simulation'] as bool? ?? false,
      notifications: json['notifications'] as bool? ?? false,
    );
  }
}

class AppConfig {
  const AppConfig({
    required this.minAppVersion,
    required this.latestAppVersion,
    required this.dataMode,
    this.maintenance = false,
    this.features = const FeatureFlags(),
    this.legal = const {},
  });

  final String minAppVersion;
  final String latestAppVersion;
  final String dataMode;
  final bool maintenance;
  final FeatureFlags features;
  final Map<String, String> legal;

  bool get isZeroBudget => dataMode == 'zero_budget';

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      minAppVersion: json['min_app_version'] as String? ?? '',
      latestAppVersion: json['latest_app_version'] as String? ?? '',
      dataMode: json['data_mode'] as String? ?? 'zero_budget',
      maintenance: json['maintenance'] as bool? ?? false,
      features: FeatureFlags.fromJson(
        Map<String, dynamic>.from(json['features'] as Map? ?? const {}),
      ),
      legal: Map<String, String>.from(json['legal'] as Map? ?? const {}),
    );
  }
}

class Disclaimer {
  const Disclaimer({
    required this.version,
    required this.updatedAt,
    required this.text,
  });

  final String version;
  final String updatedAt;
  final String text;

  factory Disclaimer.fromJson(Map<String, dynamic> json) {
    return Disclaimer(
      version: json['version'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }
}
