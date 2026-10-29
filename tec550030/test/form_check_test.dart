import 'package:flutter_test/flutter_test.dart';
import 'package:tec550030/core/pose_math.dart';
import 'package:tec550030/models/form_check_result.dart';
import 'package:tec550030/models/form_exercise.dart';
import 'package:tec550030/services/form_analysis_service.dart';

void main() {
  group('angleDeg', () {
    test('calculates 90 degree angle accurately', () {
      final angle = angleDeg(
        (x: 0, y: 0),
        (x: 1, y: 0),
        (x: 1, y: 1),
      );
      expect(angle, closeTo(90, 0.1));
    });

    test('calculates 180 degree angle in straight line', () {
      final angle = angleDeg(
        (x: 0, y: 0),
        (x: 1, y: 0),
        (x: 2, y: 0),
      );
      expect(angle, closeTo(180, 0.1));
    });

    test('handles zero magnitude safely without NaN', () {
      final angle = angleDeg(
        (x: 1, y: 1),
        (x: 1, y: 1),
        (x: 2, y: 2),
      );
      expect(angle, 0);
      expect(angle.isNaN, isFalse);
    });
  });

  group('FormRatingX.fromScore', () {
    test('classifies rating ranges correctly', () {
      expect(FormRatingX.fromScore(95), FormRating.excellent);
      expect(FormRatingX.fromScore(90), FormRating.excellent);
      expect(FormRatingX.fromScore(85), FormRating.good);
      expect(FormRatingX.fromScore(75), FormRating.good);
      expect(FormRatingX.fromScore(70), FormRating.needsWork);
      expect(FormRatingX.fromScore(60), FormRating.needsWork);
      expect(FormRatingX.fromScore(59), FormRating.tryAgain);
      expect(FormRatingX.fromScore(0), FormRating.tryAgain);
    });
  });

  group('FormAnalysisService - Squat', () {
    const service = FormAnalysisService();

    test('full depth squat with completed rep scores high (>=75)', () {
      final session = SquatSessionData()
        ..minKneeAngle = 88.0
        ..maxKneeAngle = 170.0
        ..maxTorsoLean = 18.0
        ..repCount = 1
        ..validFrameCount = 35;

      final result = service.analyseSquat(session);

      expect(result.score, greaterThanOrEqualTo(75));
      expect(result.rating, anyOf(FormRating.good, FormRating.excellent));
      expect(result.exercise, FormExercise.squat);
      expect(result.feedback.length, inInclusiveRange(1, 3));
    });

    test('shallow squat with incomplete rep scores lower (<60)', () {
      final session = SquatSessionData()
        ..minKneeAngle = 145.0
        ..maxKneeAngle = 168.0
        ..maxTorsoLean = 35.0
        ..repCount = 0
        ..validFrameCount = 30;

      final result = service.analyseSquat(session);

      expect(result.score, lessThan(60));
      expect(result.rating, FormRating.tryAgain);
      expect(result.feedback, contains(contains('hoàn thành trọn vẹn')));
    });

    test('handles insufficient valid frames gracefully without crash', () {
      final session = SquatSessionData()
        ..minKneeAngle = 90.0
        ..repCount = 0
        ..validFrameCount = 4;

      final result = service.analyseSquat(session);

      expect(result.score, lessThanOrEqualTo(40));
      expect(result.rating, FormRating.tryAgain);
      expect(result.feedback.first, contains('toàn bộ cơ thể'));
    });
  });

  group('FormAnalysisService - Leg Press', () {
    const service = FormAnalysisService();

    test('full ROM with stable hip and completed rep scores high (>=75)', () {
      final session = LegPressSessionData()
        ..minKneeAngle = 92.0
        ..maxKneeAngle = 165.0
        ..maxHipDrift = 0.08
        ..repCount = 2
        ..validFrameCount = 35;

      final result = service.analyseLegPress(session);

      expect(result.score, greaterThanOrEqualTo(75));
      expect(result.rating, anyOf(FormRating.good, FormRating.excellent));
      expect(result.exercise, FormExercise.legPress);
      expect(result.feedback.length, inInclusiveRange(1, 3));
      expect(result.metrics.any((m) => m.label == 'Biên độ chuyển động'), isTrue);
    });

    test('shallow ROM with 0 reps scores lower (<60)', () {
      final session = LegPressSessionData()
        ..minKneeAngle = 140.0
        ..maxKneeAngle = 160.0
        ..maxHipDrift = 0.25
        ..repCount = 0
        ..validFrameCount = 25;

      final result = service.analyseLegPress(session);

      expect(result.score, lessThan(60));
      expect(result.rating, FormRating.tryAgain);
      expect(result.feedback, contains(contains('đủ một nhịp xuống và đẩy lên')));
    });

    test('overly deep flexion triggers safe range recommendation', () {
      final session = LegPressSessionData()
        ..minKneeAngle = 60.0
        ..maxKneeAngle = 165.0
        ..maxHipDrift = 0.05
        ..repCount = 1
        ..validFrameCount = 30;

      final result = service.analyseLegPress(session);

      expect(result.feedback, contains(contains('Không cần hạ quá sâu')));
    });

    test('handles insufficient valid frames gracefully', () {
      final session = LegPressSessionData()
        ..minKneeAngle = 90.0
        ..repCount = 0
        ..validFrameCount = 5;

      final result = service.analyseLegPress(session);

      expect(result.score, lessThanOrEqualTo(40));
      expect(result.rating, FormRating.tryAgain);
      expect(result.feedback.first, contains('hông, đầu gối và mắt cá chân'));
    });
  });

  group('FormAnalysisService - Bicep Curl', () {
    const service = FormAnalysisService();

    test('full ROM with stable elbow and completed rep scores high (>=75)', () {
      final session = BicepCurlSessionData()
        ..minElbowAngle = 62.0
        ..maxElbowAngle = 152.0
        ..maxElbowDrift = 0.06
        ..maxShoulderMovement = 0.04
        ..repCount = 2
        ..validFrameCount = 35;

      final result = service.analyseBicepCurl(session);

      expect(result.score, greaterThanOrEqualTo(75));
      expect(result.rating, anyOf(FormRating.good, FormRating.excellent));
      expect(result.exercise, FormExercise.bicepCurl);
      expect(result.feedback.length, inInclusiveRange(1, 3));
    });

    test('partial curl contraction gives appropriate feedback', () {
      final session = BicepCurlSessionData()
        ..minElbowAngle = 88.0
        ..maxElbowAngle = 150.0
        ..maxElbowDrift = 0.08
        ..maxShoulderMovement = 0.05
        ..repCount = 1
        ..validFrameCount = 30;

      final result = service.analyseBicepCurl(session);

      expect(result.feedback, contains(contains('Curl lên cao hơn')));
    });

    test('excessive elbow drift and shoulder swing lowers score', () {
      final session = BicepCurlSessionData()
        ..minElbowAngle = 65.0
        ..maxElbowAngle = 150.0
        ..maxElbowDrift = 0.35
        ..maxShoulderMovement = 0.25
        ..repCount = 0
        ..validFrameCount = 28;

      final result = service.analyseBicepCurl(session);

      expect(result.score, lessThan(75));
      expect(result.feedback, contains(contains('Giữ khuỷu tay gần vị trí ban đầu')));
    });

    test('handles insufficient valid frames gracefully', () {
      final session = BicepCurlSessionData()
        ..minElbowAngle = 60.0
        ..repCount = 0
        ..validFrameCount = 3;

      final result = service.analyseBicepCurl(session);

      expect(result.score, lessThanOrEqualTo(40));
      expect(result.rating, FormRating.tryAgain);
      expect(result.feedback.first, contains('vai, khuỷu tay và cổ tay'));
    });
  });

  group('formExerciseForGuide', () {
    test('maps dumbbell-squat to squat', () {
      expect(formExerciseForGuide('dumbbell-squat'), FormExercise.squat);
    });

    test('maps leg-press-variations to legPress', () {
      expect(formExerciseForGuide('leg-press-variations'), FormExercise.legPress);
    });

    test('maps dumbbell-upper-body to bicepCurl', () {
      expect(formExerciseForGuide('dumbbell-upper-body'), FormExercise.bicepCurl);
    });

    test('returns null for unsupported guides', () {
      expect(formExerciseForGuide('side-plank-twist'), isNull);
      expect(formExerciseForGuide('beginner-tabata'), isNull);
    });
  });
}
