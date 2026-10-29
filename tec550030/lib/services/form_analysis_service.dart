import '../models/form_check_result.dart';
import '../models/form_exercise.dart';

class SquatSessionData {
  double minKneeAngle = 180;
  double maxKneeAngle = 0;
  double maxTorsoLean = 0; // Degrees from vertical
  int repCount = 0;
  int validFrameCount = 0;
}

class BicepCurlSessionData {
  double minElbowAngle = 180;
  double maxElbowAngle = 0;
  double maxElbowDrift = 0;
  double maxShoulderMovement = 0;
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
          'Camera chưa nhìn rõ vai, khuỷu tay và cổ tay.',
          'Hãy điều chỉnh góc đứng nhìn thấy rõ cánh tay.',
        ],
        repCount: 0,
        validFrameCount: 0,
      );
    }

    final minElbow = data.minElbowAngle;
    final maxElbow = data.maxElbowAngle;
    final goodExtension = maxElbow >= 145;
    final goodContraction = minElbow <= 70;

    int romScore = 15;
    if (goodExtension && goodContraction) {
      romScore = 50;
    } else if (goodExtension || goodContraction) {
      romScore = 32;
    }

    String romFeedback;
    if (!goodContraction) {
      romFeedback = 'Curl tạ lên cao hơn một chút.';
    } else if (!goodExtension) {
      romFeedback = 'Duỗi tay thêm ở cuối nhịp.';
    } else {
      romFeedback = 'Biên độ chuyển động tốt.';
    }

    int elbowScore = 10;
    String? elbowFeedback;
    if (data.maxElbowDrift <= 0.10) {
      elbowScore = 30;
    } else if (data.maxElbowDrift <= 0.20) {
      elbowScore = 20;
      elbowFeedback = 'Cố định khuỷu tay sát thân sườn.';
    } else {
      elbowFeedback = 'Khuỷu tay bị vung ra trước quá nhiều.';
    }

    int shoulderScore = 10;
    String? shoulderFeedback;
    if (data.maxShoulderMovement <= 0.08) {
      shoulderScore = 20;
    } else {
      shoulderFeedback = 'Hạn chế đung đưa vai và thân người để lấy đà.';
    }

    final totalScore = (romScore + elbowScore + shoulderScore).clamp(0, 100);

    return FormCheckResult(
      exercise: FormExercise.bicepCurl,
      score: totalScore,
      rating: FormRatingX.fromScore(totalScore),
      metrics: [
        FormMetric(
          label: 'Góc khuỷu tay nhỏ nhất',
          value: '${minElbow.toStringAsFixed(0)}°',
          quality: goodContraction ? 'Tốt' : 'Cần gập thêm',
        ),
        FormMetric(
          label: 'Cố định khuỷu tay',
          value: data.maxElbowDrift <= 0.12 ? 'Ổn định' : 'Có rung lắc',
        ),
        FormMetric(
          label: 'Số lần hoàn chỉnh',
          value: '${data.repCount} rep',
        ),
      ],
      feedback: [
        romFeedback,
        ?elbowFeedback,
        ?shoulderFeedback,
      ].take(3).toList(),
      repCount: data.repCount,
      validFrameCount: data.validFrameCount,
    );
  }
}
