import '../core/api/api_client.dart';
import '../models/gympoint.dart';
import '../models/point_transaction.dart';

class GymPointService {
  Future<GymPointBalance> getBalance() async => GymPointBalance.fromJson(
    await ApiClient.getJson('/points/balance') as Map<String, dynamic>,
  );
  Future<List<PointTransaction>> getHistory({
    int offset = 0,
    int limit = 20,
  }) async {
    final data = await ApiClient.getJson(
      '/points/history?limit=$limit&offset=$offset',
    ) as List<dynamic>;
    return data
        .map((json) => PointTransaction.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
