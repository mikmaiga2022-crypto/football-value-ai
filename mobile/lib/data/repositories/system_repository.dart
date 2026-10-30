import '../../core/api/api_client.dart';
import '../models/system_status.dart';

/// Routes de méta-information (`/health`, `/meta/config`, `/meta/disclaimer`).
class SystemRepository {
  const SystemRepository(this._client);

  final ApiClient _client;

  Future<HealthStatus> health() async {
    final envelope = await _client.getEnvelope<HealthStatus>(
      '/v1/health',
      parse: HealthStatus.fromJson,
    );
    return envelope.data;
  }

  Future<AppConfig> config() async {
    final envelope = await _client.getEnvelope<AppConfig>(
      '/v1/meta/config',
      parse: AppConfig.fromJson,
    );
    return envelope.data;
  }

  Future<Disclaimer> disclaimer() async {
    final envelope = await _client.getEnvelope<Disclaimer>(
      '/v1/meta/disclaimer',
      parse: Disclaimer.fromJson,
    );
    return envelope.data;
  }
}
