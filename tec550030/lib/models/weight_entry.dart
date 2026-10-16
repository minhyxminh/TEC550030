class WeightEntry {
  final double weightKg;
  final DateTime measuredAt;
  WeightEntry({required this.weightKg, required this.measuredAt}) {
    if (!weightKg.isFinite || weightKg < 20 || weightKg > 350) {
      throw const FormatException('Cân nặng phải từ 20 đến 350 kg.');
    }
  }
  Map<String, dynamic> toJson() => {
    'weight_kg': weightKg,
    'measured_at': measuredAt.toIso8601String(),
  };
  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
    weightKg: (json['weight_kg'] as num).toDouble(),
    measuredAt: DateTime.parse(json['measured_at'] as String),
  );
}
