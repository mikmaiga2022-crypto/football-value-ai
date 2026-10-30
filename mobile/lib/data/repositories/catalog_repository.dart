import '../../core/api/api_client.dart';
import '../models/competition.dart';

/// Catalogue et couverture : seules données métier disponibles en Phase 2.
class CatalogRepository {
  const CatalogRepository(this._client);

  final ApiClient _client;

  Future<List<Competition>> competitions({String? state, int limit = 50}) async {
    final page = await _client.getPaginated(
      '/v1/competitions',
      query: {
        'limit': limit,
        'state': ?state,
      },
    );
    return page.data
        .map((raw) => Competition.fromJson(raw))
        .toList(growable: false);
  }

  Future<CoveragePlan> coverage() async {
    final envelope = await _client.getEnvelope<CoveragePlan>(
      '/v1/system/coverage',
      parse: CoveragePlan.fromJson,
    );
    return envelope.data;
  }
}
