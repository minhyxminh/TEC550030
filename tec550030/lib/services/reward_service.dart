import 'dart:convert';

import '../core/api/api_client.dart';
import '../models/reward.dart';

class RewardService {
  Future<List<Reward>> getRewards() async {
    final response = await ApiClient.get('/rewards');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Reward.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load rewards');
    }
  }

  Future<Reward> getRewardDetails(String id) async {
    final response = await ApiClient.get('/rewards/$id');
    if (response.statusCode == 200) {
      return Reward.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load reward details');
    }
  }

  Future<void> redeemReward(String id) async {
    final response = await ApiClient.post('/rewards/$id/redeem');
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Redeem failed');
    }
  }
}
