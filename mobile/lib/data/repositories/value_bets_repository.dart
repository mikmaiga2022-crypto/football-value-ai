import '../../core/api/api_client.dart';
import '../models/value_bet.dart';

class ValueBetsRepository {
  const ValueBetsRepository(this._client);

  final ApiClient _client;

  Future<List<ValueBetItem>> list({String? matchId, String? priority, int limit = 50}) async {
    final envelope = await _client.getListEnvelope<ValueBetItem>(
      '/v1/value-bets',
      query: {
        'limit': limit,
        'match_id': ?matchId,
        'priority': ?priority,
      },
      parseItem: ValueBetItem.fromJson,
    );
    return envelope.data;
  }
}
