import '../core/api/api_client.dart';
import '../models/boss_battle.dart';

/// Đại chiến Boss, always from the server's real check-in totals.
class BossService {
  const BossService();

  static const notDeployed =
      'Đại chiến Boss đang được cập nhật trên máy chủ. Vui lòng thử lại sau.';

  Future<BossBattle> status() => _call(() => ApiClient.getJson('/boss'));

  /// Fights the boss; a win pays every member's reward into their wallet.
  Future<(BossFightResult, BossBattle)> fight() async {
    late Map<String, dynamic> json;
    final battle = await _call(() async {
      json = Map<String, dynamic>.from(
        await ApiClient.postJson('/boss/fight', {}) as Map,
      );
      return json;
    });
    return (
      json['result'] == 'WIN' ? BossFightResult.win : BossFightResult.lose,
      battle,
    );
  }

  Future<BossBattle> _call(Future<dynamic> Function() request) async {
    try {
      return BossBattle.fromJson(
        Map<String, dynamic>.from(await request() as Map),
      );
    } on ApiException catch (e) {
      // The route exists once migration 015 and the API are deployed.
      if (e.statusCode == 404) throw const ApiException(notDeployed, 404);
      rethrow;
    }
  }
}
