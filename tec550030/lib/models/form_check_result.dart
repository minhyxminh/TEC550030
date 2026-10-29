import 'form_exercise.dart';

enum FormRating { excellent, good, needsWork, tryAgain }

extension FormRatingX on FormRating {
  String get label => switch (this) {
        FormRating.excellent => 'Rất tốt',
        FormRating.good => 'Tốt',
        FormRating.needsWork => 'Cần cải thiện',
        FormRating.tryAgain => 'Thử lại',
      };

  static FormRating fromScore(int score) {
    if (score >= 90) return FormRating.excellent;
    if (score >= 75) return FormRating.good;
    if (score >= 60) return FormRating.needsWork;
    return FormRating.tryAgain;
  }
}

class FormMetric {
  final String label;
  final String value;
  final String? quality;
  const FormMetric({required this.label, required this.value, this.quality});
}

class FormCheckResult {
  final FormExercise exercise;
  final int score; // 0–100
  final FormRating rating;
  final List<FormMetric> metrics;
  final List<String> feedback;
  final int repCount;
  final int validFrameCount;

  const FormCheckResult({
    required this.exercise,
    required this.score,
    required this.rating,
    required this.metrics,
    required this.feedback,
    required this.repCount,
    required this.validFrameCount,
  });
}

