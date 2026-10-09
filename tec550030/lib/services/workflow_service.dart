import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';

class WorkflowService {
  static final revision = ValueNotifier<int>(0);
  static String requestKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<Map<String, dynamic>> history({int offset = 0}) async =>
      await ApiClient.getJson('/activity?limit=20&offset=$offset')
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> admin({int offset = 0}) async =>
      await ApiClient.getJson('/admin/dashboard?limit=20&offset=$offset')
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> send(
    String path,
    Map<String, dynamic> body,
  ) async {
    final result = await ApiClient.postJson(path, body);
    revision.value++;
    return result;
  }

  Future<List<dynamic>> slots(String trainer, String date) async =>
      await ApiClient.getJson('/trainers/$trainer/slots?date=$date')
          as List<dynamic>;
}
