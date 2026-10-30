import '../../core/api/api_client.dart';
import '../models/prediction.dart';

class PredictionsRepository {
  const PredictionsRepository(this._client);

  final ApiClient _client;

  Future<List<PredictionItem>> forMatch(String matchId) async {
    final envelope = await _client.getListEnvelope<PredictionItem>(
      '/v1/predictions',
      query: {'match_id': matchId},
      parseItem: PredictionItem.fromJson,
    );
    return envelope.data;
  }
}
