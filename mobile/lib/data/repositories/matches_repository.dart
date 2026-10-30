import '../../core/api/api_client.dart';
import '../models/match.dart';

class MatchesRepository {
  const MatchesRepository(this._client);

  final ApiClient _client;

  Future<List<MatchItem>> list({
    String? competition,
    String? status,
    int limit = 50,
  }) async {
    final envelope = await _client.getListEnvelope<MatchItem>(
      '/v1/matches',
      query: {
        'limit': limit,
        'competition': ?competition,
        'status': ?status,
      },
      parseItem: MatchItem.fromJson,
    );
    return envelope.data;
  }

  Future<MatchItem> get(String id) async {
    final envelope = await _client.getEnvelope<MatchItem>(
      '/v1/matches/$id',
      parse: MatchItem.fromJson,
    );
    return envelope.data;
  }

  Future<List<OddsSnapshotItem>> latestOdds(
    String matchId, {
    String? market,
    int maxAgeSeconds = 3600,
  }) async {
    final envelope = await _client.getEnvelope<Map<String, dynamic>>(
      '/v1/odds/latest',
      query: {
        'match_id': matchId,
        'market': ?market,
        'max_age_seconds': maxAgeSeconds,
      },
      parse: (data) => Map<String, dynamic>.from(data),
    );
    final snapshots = (envelope.data['snapshots'] as List<dynamic>? ?? const []);
    return snapshots
        .map((raw) => OddsSnapshotItem.fromJson(Map<String, dynamic>.from(raw as Map)))
        .toList(growable: false);
  }
}
