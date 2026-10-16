class BmiResult {
  final double weightKg, heightCm;
  final int age;
  final DateTime measuredAt;

  BmiResult({
    required this.weightKg,
    required this.heightCm,
    required this.age,
    DateTime? measuredAt,
  }) : measuredAt = measuredAt ?? DateTime.now() {
    if (!weightKg.isFinite ||
        weightKg < 20 ||
        weightKg > 350 ||
        !heightCm.isFinite ||
        heightCm < 100 ||
        heightCm > 250 ||
        age < 20 ||
        age > 120) {
      throw const FormatException(
        'Nhập cân nặng 20–350 kg, chiều cao 100–250 cm và tuổi 20–120.',
      );
    }
  }

  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));
  int get categoryIndex => bmi < 18.5
      ? 0
      : bmi < 25
      ? 1
      : bmi < 30
      ? 2
      : 3;
  String get classification =>
      ['Thiếu cân', 'Cân nặng khỏe mạnh', 'Thừa cân', 'Béo phì'][categoryIndex];
  Map<String, dynamic> toJson() => {
    'weight_kg': weightKg,
    'height_cm': heightCm,
    'age': age,
    'measured_at': measuredAt.toIso8601String(),
  };
  factory BmiResult.fromJson(Map<String, dynamic> json) => BmiResult(
    weightKg: (json['weight_kg'] as num).toDouble(),
    heightCm: (json['height_cm'] as num).toDouble(),
    age: json['age'] as int,
    measuredAt: DateTime.parse(json['measured_at'] as String),
  );
}
