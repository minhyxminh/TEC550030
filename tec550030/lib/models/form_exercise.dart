/// Supported Form Check exercises.
enum FormExercise {
  squat,
  legPress,
  bicepCurl;

  String get displayName => switch (this) {
        FormExercise.squat => 'Squat',
        FormExercise.legPress => 'Leg Press',
        FormExercise.bicepCurl => 'Bicep Curl',
      };

  String get cardTitle => switch (this) {
        FormExercise.squat => 'Kiểm tra form của bạn',
        FormExercise.legPress => 'Kiểm tra Leg Press',
        FormExercise.bicepCurl => 'Kiểm tra Bicep Curl',
      };

  String get cardSubtitle => switch (this) {
        FormExercise.squat =>
          'Xem hướng dẫn xong? Hãy thử thực hiện và kiểm tra chuyển động của bạn.',
        FormExercise.legPress =>
          'Thực hiện một vài nhịp Leg Press trước camera để kiểm tra biên độ gối và độ ổn định chuyển động.',
        FormExercise.bicepCurl =>
          'Thử động tác cuốn tạ tay trước để kiểm tra biên độ và độ ổn định khuỷu tay.',
      };

  String get positioningHint => switch (this) {
        FormExercise.squat =>
          'Đặt điện thoại ngang hông và lùi lại để camera nhìn thấy toàn bộ cơ thể từ đầu đến chân.',
        FormExercise.legPress =>
          'Đặt điện thoại ở bên hông máy Leg Press để camera thấy rõ hông, đầu gối và mắt cá chân. Giữ toàn bộ chân trong khung hình.',
        FormExercise.bicepCurl =>
          'Đặt camera ngang hoặc hơi chéo bên cạnh cơ thể để thấy rõ vai, khuỷu tay và cổ tay trong suốt động tác.',
      };
}

/// Returns the [FormExercise] for a given machine guide id, or null if
/// Form Check is not supported for that guide.
FormExercise? formExerciseForGuide(String guideId) => switch (guideId) {
      'dumbbell-squat' => FormExercise.squat,
      'leg-press-variations' => FormExercise.legPress,
      'dumbbell-upper-body' => FormExercise.bicepCurl,
      _ => null,
    };
