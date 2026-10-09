import '../core/api/api_client.dart';
import '../models/occupancy.dart';

class GymService {
  Future<Occupancy> getCurrentOccupancy(String gymId) async =>
      Occupancy.fromJson(await ApiClient.getJson('/gym/$gymId/occupancy'));
  Future<List<HourlyOccupancy>> getHourlyOccupancy(String gymId) async =>
      (await ApiClient.getJson('/gym/$gymId/hourly') as List<dynamic>)
          .map((e) => HourlyOccupancy.fromJson(e))
          .toList();
  Future<Map<String, dynamic>?> currentSession() async =>
      await ApiClient.getJson('/gym/session') as Map<String, dynamic>?;
  Future<Map<String, dynamic>> checkIn(String token) =>
      ApiClient.postJson('/gym/check-in', {'token': token});
  Future<Map<String, dynamic>> checkOut(String id) =>
      ApiClient.postJson('/gym/check-out', {'session_id': id});
}
