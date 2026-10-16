import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/bmi_result.dart';
import '../models/weight_entry.dart';

class HealthOverview {
  final BmiResult? result;
  final List<WeightEntry> weights;
  const HealthOverview(this.result, this.weights);
}

class HealthService {
  static String dayKey(DateTime date) => date
      .toUtc()
      .add(const Duration(hours: 7))
      .toIso8601String()
      .substring(0, 10);
  Future<HealthOverview> overview(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('health_$userId');
    if (raw != null) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final result = json['bmi'] == null
            ? null
            : BmiResult.fromJson(json['bmi'] as Map<String, dynamic>);
        final weights = <WeightEntry>[];
        for (final row in json['weights'] as List? ?? []) {
          try {
            weights.add(
              WeightEntry.fromJson(Map<String, dynamic>.from(row as Map)),
            );
          } on FormatException {
            continue;
          } on TypeError {
            continue;
          }
        }
        weights.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
        return HealthOverview(result, weights);
      } on FormatException {
        return const HealthOverview(null, []);
      } on TypeError {
        return const HealthOverview(null, []);
      }
    }
    // Read the previous single-result format without inventing a measurement.
    final legacy = prefs.getString('bmi_$userId');
    if (legacy != null) {
      try {
        final result = BmiResult.fromJson(
          jsonDecode(legacy) as Map<String, dynamic>,
        );
        return HealthOverview(result, [
          WeightEntry(weightKg: result.weightKg, measuredAt: result.measuredAt),
        ]);
      } on FormatException {
        return const HealthOverview(null, []);
      } on TypeError {
        return const HealthOverview(null, []);
      }
    }
    return const HealthOverview(null, []);
  }

  Future<BmiResult?> latest(String userId) async =>
      (await overview(userId)).result;
  Future<void> save(String userId, BmiResult result) async {
    if (userId.isEmpty) throw const FormatException('Chưa xác định tài khoản.');
    final previous = await overview(userId);
    await _persist(
      userId,
      previous,
      WeightEntry(weightKg: result.weightKg, measuredAt: result.measuredAt),
      result,
    );
  }

  Future<void> saveWeight(
    String userId,
    double weightKg, {
    DateTime? measuredAt,
  }) async {
    if (userId.isEmpty) throw const FormatException('Chưa xác định tài khoản.');
    final entry = WeightEntry(
      weightKg: weightKg,
      measuredAt: measuredAt ?? DateTime.now(),
    );
    final previous = await overview(userId);
    final existing = previous.result;
    // A standalone weigh-in never invents height or age for a new user.
    final result = existing == null
        ? null
        : BmiResult(
            weightKg: weightKg,
            heightCm: existing.heightCm,
            age: existing.age,
            measuredAt: entry.measuredAt,
          );
    await _persist(userId, previous, entry, result);
  }

  Future<void> _persist(
    String userId,
    HealthOverview previous,
    WeightEntry entry,
    BmiResult? result,
  ) async {
    final weights = [
      ...previous.weights.where(
        (e) => dayKey(e.measuredAt) != dayKey(entry.measuredAt),
      ),
      entry,
    ]..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      'health_$userId',
      jsonEncode({
        'bmi': result?.toJson(),
        'weights': weights.map((e) => e.toJson()).toList(),
      }),
    );
    if (!saved) throw StateError('Chưa lưu được kết quả.');
    await prefs.remove('bmi_$userId');
  }
}
