import '../core/api/api_client.dart';
import '../models/reward.dart';

class RewardService {
  Future<List<Reward>> getRewards() async =>
      (await ApiClient.catalogue('/rewards'))
          .map((json) => Reward.fromJson(json as Map<String, dynamic>))
          .toList();
  Future<Reward> getRewardDetails(String id) async => Reward.fromJson(
    await ApiClient.getJson('/rewards/$id', authenticated: false)
        as Map<String, dynamic>,
  );
}
