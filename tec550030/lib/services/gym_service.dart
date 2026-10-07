import 'dart:convert';

import '../core/api/api_client.dart';
import '../models/occupancy.dart';

class GymService {
  Future<Occupancy> getCurrentOccupancy(String gymId) async {
    final response = await ApiClient.get('/gym/$gymId/occupancy');
    if (response.statusCode == 200) {
      return Occupancy.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load occupancy');
    }
  }

  Future<List<HourlyOccupancy>> getHourlyOccupancy(String gymId) async {
    final response = await ApiClient.get('/gym/$gymId/occupancy/hourly');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => HourlyOccupancy.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load hourly occupancy');
    }
  }

  Future<Map<String, dynamic>> checkInOut(String qrToken) async {
    final response = await ApiClient.post(
      '/gym/check',
      body: {'qr_token': qrToken},
    );

    if (response.statusCode == 200) {
      return jsonDecode(
        response.body,
      ); // e.g. { "status": "IN", "message": "Check-in successful" }
    } else {
      throw Exception(
        jsonDecode(response.body)['message'] ?? 'Check-in/out failed',
      );
    }
  }
}
