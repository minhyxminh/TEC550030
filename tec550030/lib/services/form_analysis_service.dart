import '../models/form_check_result.dart';
import '../models/form_exercise.dart';

class SquatSessionData {
  double minKneeAngle = 180;
  double maxKneeAngle = 0;
  double maxTorsoLean = 0; // Degrees from vertical
  int repCount = 0;
  int validFrameCount = 0;
}

class LegPressSessionData {
  double minKneeAngle = 180;
  double maxKneeAngle = 0;
  double maxHipDrift = 0; // Normalized body displacement
  int repCount = 0;
  int validFrameCount = 0;
}

class BicepCurlSessionData {
  double minElbowAngle = 180;
  double maxElbowAngle = 0;
  double maxElbowDrift = 0; // Normalized drift / upper arm length
  double maxShoulderMovement = 0; // Normalized movement / upper arm length
  int repCount = 0;
  int validFrameCount = 0;
}

class FormAnalysisService {
  const FormAnalysisService();

  FormCheckResult analyseSquat(SquatSessionData data) {
    if (data.validFrameCount < 10) {
      return const FormCheckResult(
        exercise: FormExercise.squat,
        score: 30,
        rating: FormRating.tryAgain,
        metrics: [
          FormMetric(label: 'Số khung hình nhận diện', value: 'Chưa đủ'),
        ],
        feedback: [
          'Camera chưa thấy rõ toàn bộ cơ thể từ đầu đến chân.',
          'Hãy lùi lại và giữ góc quay ổn định.',
        ],
        repCount: 0,
        validFrameCount: 0,
      );
    }

    // A. Depth score (40 points)
    // Target depth at deepest position: 80° - 115°
    final depth = data.minKneeAngle;
    int depthScore;
    String depthFeedback;
    String depthQuality;

    if (depth <= 95) {
      depthScore = 40;
      depthFeedback = 'Độ sâu tốt.';
      depthQuality = 'Tốt';
    } else if (depth <= 115) {
      depthScore = 32;
      depthFeedback = 'Độ sâu đạt chuẩn.';
      depthQuality = 'Khá';
    } else if (depth <= 135) {
      depthScore = 20;
      depthFeedback = 'Thử hạ thấp hông hơn một chút để đùi song song sàn.';
      depthQuality = 'Hơi nông';
    } else {
      depthScore = 8;
      depthFeedback = 'Biên độ squat quá nông, hãy hạ gối sâu hơn.';
      depthQuality = 'Cần cải thiện';
    }

    // B. Torso stability (30 points)
    // Shoulder-to-hip vector angle relative to vertical.
    final torsoLean = data.maxTorsoLean;
    int torsoScore;
    String? torsoFeedback;
    String torsoQuality;

    if (torsoLean <= 28) {
      torsoScore = 30;
      torsoQuality = 'Rất ổn định';
    } else if (torsoLean <= 42) {
      torsoScore = 22;
      torsoQuality = 'Ổn định';
      torsoFeedback = 'Giữ ngực mở và lưng thẳng hơn khi xuống.';
    } else {
      torsoScore = 10;
      torsoQuality = 'Nghiêng nhiều';
      torsoFeedback = 'Tránh đổ người quá nhiều về phía trước.';
    }

    // C. Rep completion (30 points)
    int repScore;
    String? repFeedback;
    if (data.repCount >= 1) {
      repScore = 30;
    } else {
      repScore = 0;
      repFeedback = 'Hãy hoàn thành trọn vẹn nhịp đứng - xuống - đứng lên.';
    }

    final totalScore = (depthScore + torsoScore + repScore).clamp(0, 100);

    final feedbackList = <String>[
      depthFeedback,
      ?torsoFeedback,
      ?repFeedback,
    ].take(3).toList();

    return FormCheckResult(
      exercise: FormExercise.squat,
      score: totalScore,
      rating: FormRatingX.fromScore(totalScore),
      metrics: [
        FormMetric(
          label: 'Góc gối thấp nhất',
          value: '${depth.toStringAsFixed(0)}°',
          quality: depthQuality,
        ),
        FormMetric(
          label: 'Độ ổn định thân người',
          value: torsoQuality,
        ),
        FormMetric(
          label: 'Số lần hoàn chỉnh',
          value: '${data.repCount} rep',
          quality: data.repCount >= 1 ? 'Đạt' : 'Chưa đạt',
        ),
      ],
      feedback: feedbackList,
      repCount: data.repCount,
      validFrameCount: data.validFrameCount,
    );
  }

  FormCheckResult analyseLegPress(LegPressSessionData data) {
    if (data.validFrameCount < 10) {
      return const FormCheckResult(
        exercise: FormExercise.legPress,
        score: 30,
        rating: FormRating.tryAgain,
        metrics: [
          FormMetric(label: 'Số khung hình nhận diện', value: 'Chưa đủ'),
        ],
        feedback: [
          'Hãy điều chỉnh camera để thấy rõ hông, đầu gối và mắt cá chân.',
          'Giữ toàn bộ chân trong khung hình.',
        ],
        repCount: 0,
        validFrameCount: 0,
      );
    }

    // A. Range of motion (50 points)
    // Target depth at flexed position: 80° - 115°
    final depth = data.minKneeAngle;
    int romScore;
    String romFeedback;
    String romQuality;

    if (depth < 70) {
      romScore = 40;
      romFeedback = 'Không cần hạ quá sâu.';
      romQuality = 'Hơi sâu';
    } else if (depth <= 95) {
      romScore = 50;
      romFeedback = 'Biên độ Leg Press tốt.';
      romQuality = 'Tốt';
    } else if (depth <= 115) {
      romScore = 40;
      romFeedback = 'Biên độ Leg Press tốt.';
      romQuality = 'Đạt';
    } else if (depth <= 135) {
      romScore = 25;
      romFeedback = 'Hạ bàn đạp thêm một chút để hoàn thiện biên độ.';
      romQuality = 'Hơi nông';
    } else {
      romScore = 10;
      romFeedback = 'Hạ bàn đạp thêm một chút để hoàn thiện biên độ.';
      romQuality = 'Cần cải thiện';
    }

    // B. Movement stability (30 points)
    // Normalized hip movement relative to upper leg length
    final hipDrift = data.maxHipDrift;
    int stabilityScore;
    String? stabilityFeedback;
    String stabilityQuality;

    if (hipDrift <= 0.10) {
      stabilityScore = 30;
      stabilityQuality = 'Rất ổn định';
    } else if (hipDrift <= 0.22) {
      stabilityScore = 20;
      stabilityQuality = 'Ổn định';
      stabilityFeedback = 'Giữ chuyển động ổn định hơn.';
    } else {
      stabilityScore = 8;
      stabilityQuality = 'Có rung lắc';
      stabilityFeedback = 'Giữ hông cố định vào đệm và chuyển động đều nhịp.';
    }

    // C. Completed repetition (20 points)
    int repScore;
    String? repFeedback;
    if (data.repCount >= 1) {
      repScore = 20;
    } else {
      repScore = 0;
      repFeedback = 'Hãy hoàn thành đủ một nhịp xuống và đẩy lên.';
    }

    final totalScore = (romScore + stabilityScore + repScore).clamp(0, 100);

    final feedbackList = <String>[
      romFeedback,
      ?stabilityFeedback,
      ?repFeedback,
    ].take(3).toList();

    return FormCheckResult(
      exercise: FormExercise.legPress,
      score: totalScore,
      rating: FormRatingX.fromScore(totalScore),
      metrics: [
        FormMetric(
          label: 'Góc gối nhỏ nhất',
          value: '${depth.toStringAsFixed(0)}°',
          quality: romQuality,
        ),
        FormMetric(
          label: 'Biên độ chuyển động',
          value: romQuality,
        ),
        FormMetric(
          label: 'Độ ổn định chuyển động',
          value: stabilityQuality,
        ),
        FormMetric(
          label: 'Số lần hoàn chỉnh',
          value: '${data.repCount} rep',
          quality: data.repCount >= 1 ? 'Đạt' : 'Chưa đạt',
        ),
      ],
      feedback: feedbackList,
      repCount: data.repCount,
      validFrameCount: data.validFrameCount,
    );
  }

  FormCheckResult analyseBicepCurl(BicepCurlSessionData data) {
    if (data.validFrameCount < 10) {
      return const FormCheckResult(
        exercise: FormExercise.bicepCurl,
        score: 30,
        rating: FormRating.tryAgain,
        metrics: [
          FormMetric(label: 'Nhận diện chuyển động', value: 'Chưa đủ khung hình'),
        ],
        feedback: [
          'Hãy điều chỉnh camera để thấy rõ vai, khuỷu tay và cổ tay.',
          'Đảm bảo nhìn rõ cánh tay trong suốt chuyển động.',
        ],
        repCount: 0,
        validFrameCount: 0,
      );
    }

    final minElbow = data.minElbowAngle;
    final maxElbow = data.maxElbowAngle;
    final goodExtension = maxElbow >= 145;
    final goodContraction = minElbow <= 70;

    // A. Range of motion (50 points)
    int romScore;
    String romFeedback;
    String romQuality;

    if (goodExtension && goodContraction) {
      romScore = 50;
      romFeedback = 'Biên độ chuyển động tốt.';
      romQuality = 'Tốt';
    } else if (goodExtension || goodContraction) {
      romScore = 32;
      romQuality = 'Khá';
      if (!goodContraction) {
        romFeedback = 'Curl lên cao hơn một chút.';
      } else {
        romFeedback = 'Duỗi tay thêm ở cuối nhịp.';
      }
    } else {
      romScore = 15;
      romQuality = 'Cần cải thiện';
      romFeedback = 'Biên độ chuyển động còn hạn chế.';
    }

    // B. Elbow stability (30 points)
    int elbowScore;
    String? elbowFeedback;
    String elbowQuality;

    if (data.maxElbowDrift <= 0.10) {
      elbowScore = 30;
      elbowQuality = 'Ổn định';
    } else if (data.maxElbowDrift <= 0.20) {
      elbowScore = 20;
      elbowQuality = 'Có rung lắc';
      elbowFeedback = 'Giữ khuỷu tay gần vị trí ban đầu.';
    } else {
      elbowScore = 8;
      elbowQuality = 'Lệch nhiều';
      elbowFeedback = 'Giữ khuỷu tay gần vị trí ban đầu.';
    }

    // C. Shoulder/body stability (20 points)
    int shoulderScore;
    String? shoulderFeedback;

    if (data.maxShoulderMovement <= 0.08) {
      shoulderScore = 20;
    } else if (data.maxShoulderMovement <= 0.16) {
      shoulderScore = 12;
      shoulderFeedback = 'Hạn chế đung đưa vai và thân người.';
    } else {
      shoulderScore = 4;
      shoulderFeedback = 'Hạn chế đung đưa vai và thân người.';
    }

    String? repFeedback;
    if (data.repCount == 0) {
      repFeedback = 'Hãy hoàn thành trọn vẹn một nhịp cuốn lên và hạ xuống.';
    }

    final totalScore = (romScore + elbowScore + shoulderScore).clamp(0, 100);

    final feedbackList = <String>[
      romFeedback,
      ?elbowFeedback,
      ?shoulderFeedback,
      ?repFeedback,
    ].take(3).toList();

    return FormCheckResult(
      exercise: FormExercise.bicepCurl,
      score: totalScore,
      rating: FormRatingX.fromScore(totalScore),
      metrics: [
        FormMetric(
          label: 'Góc khuỷu nhỏ nhất',
          value: '${minElbow.toStringAsFixed(0)}°',
          quality: romQuality,
        ),
        FormMetric(
          label: 'Biên độ chuyển động',
          value: romQuality,
        ),
        FormMetric(
          label: 'Độ ổn định khuỷu tay',
          value: elbowQuality,
        ),
        FormMetric(
          label: 'Số lần hoàn chỉnh',
          value: '${data.repCount} rep',
          quality: data.repCount >= 1 ? 'Đạt' : 'Chưa đạt',
        ),
      ],
      feedback: feedbackList,
      repCount: data.repCount,
      validFrameCount: data.validFrameCount,
    );
  }
}
