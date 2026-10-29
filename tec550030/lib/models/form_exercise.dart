/// Supported Form Check exercises.
enum FormExercise {
  squat,
  bicepCurl;

  String get displayName => switch (this) {
        FormExercise.squat => 'Squat',
        FormExercise.bicepCurl => 'Bicep Curl',
      };

  String get positioningHint => switch (this) {
        FormExercise.squat =>
          'Đặt điện thoại ngang hông và lùi lại để camera nhìn thấy toàn bộ cơ thể từ đầu đến chân.',
        FormExercise.bicepCurl =>
          'Đặt camera ngang hoặc hơi chéo để thấy rõ vai, khuỷu tay và cổ tay.',
      };
}

/// Returns the [FormExercise] for a given machine guide id, or null if
/// Form Check is not supported for that guide.
FormExercise? formExerciseForGuide(String guideId) => switch (guideId) {
      'dumbbell-squat' => FormExercise.squat,
      'bicep-curl' => FormExercise.bicepCurl,
      _ => null,
    };

