import '../core/api/api_client.dart';
import '../models/gym_branch.dart';

class BranchService {
  const BranchService();

  Future<List<GymBranch>> getBranches() async =>
      (await ApiClient.catalogue('/gyms'))
          .map((row) => GymBranch.fromJson(row as Map<String, dynamic>))
          .toList();

  Future<void> selectHomeGym(String gymId) async {
    await ApiClient.postJson('/me/home-gym', {'gym_id': gymId});
  }
}