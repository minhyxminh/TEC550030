import '../core/api/api_client.dart';
import '../models/buddy_match.dart';
import '../models/buddy_profile.dart';

class BuddyService {
  const BuddyService();

  Future<BuddyProfile?> getProfile() async {
    final data = await ApiClient.getJson('/buddy/profile');
    if (data == null) return null;
    return BuddyProfile.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<BuddyProfile> saveProfile(Map<String, dynamic> data) async {
    final response = await ApiClient.postJson('/buddy/profile', data);
    return BuddyProfile.fromJson(response);
  }

  Future<List<BuddyProfile>> getFeed({int limit = 20}) async {
    final data = await ApiClient.getJson('/buddy/feed?limit=$limit');
    final candidates = (data['candidates'] as List? ?? []);
    return candidates
        .map((e) => BuddyProfile.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> swipe(String targetId, String action) async {
    return ApiClient.postJson('/buddy/swipe', {
      'target_id': targetId,
      'action': action,
    });
  }

  Future<List<BuddyMatch>> getMatches() async {
    final data = await ApiClient.getJson('/buddy/matches');
    final matches = (data['matches'] as List? ?? []);
    return matches
        .map((e) => BuddyMatch.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

