import 'dart:convert';

import '../core/api/api_client.dart';
import '../models/gympoint.dart';
import '../models/point_transaction.dart';

class GymPointService {
  Future<GymPointBalance> getBalance() async {
    final response = await ApiClient.get('/points/balance');
    if (response.statusCode == 200) {
      return GymPointBalance.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load GymPoint balance');
    }
  }

  Future<List<PointTransaction>> getHistory() async {
    final response = await ApiClient.get('/points/history');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => PointTransaction.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load GymPoint history');
    }
  }
}
