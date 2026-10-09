import '../core/api/api_client.dart';
import '../models/membership.dart';
import '../models/trainer.dart';

class CatalogueService {
  Future<List<Membership>> getMemberships() async =>
      (await ApiClient.catalogue('/memberships'))
          .map((json) => Membership.fromJson(json as Map<String, dynamic>))
          .toList();
  Future<Membership> getMembership(String id) async => Membership.fromJson(
    await ApiClient.getJson('/memberships/$id', authenticated: false)
        as Map<String, dynamic>,
  );
  Future<List<Trainer>> getTrainers() async =>
      (await ApiClient.catalogue('/trainers'))
          .map((json) => Trainer.fromJson(json as Map<String, dynamic>))
          .toList();
  Future<Trainer> getTrainer(String id) async => Trainer.fromJson(
    await ApiClient.getJson('/trainers/$id', authenticated: false)
        as Map<String, dynamic>,
  );
}
