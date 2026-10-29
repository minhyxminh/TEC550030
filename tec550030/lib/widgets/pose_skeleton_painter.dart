import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:material_ui/material_ui.dart';

const Color _neonGreen = Color(0xFF39FF14);
const double _minLikelihood = 0.45;

class PoseSkeletonPainter extends CustomPainter {
  final Pose? pose;
  final Size imageSize;
  final bool isFrontCamera;

  PoseSkeletonPainter({
    required this.pose,
    required this.imageSize,
    this.isFrontCamera = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pose == null || imageSize.width == 0 || imageSize.height == 0) return;

    // Calculate scale and offset for BoxFit.cover
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;
    final double scale = scaleX > scaleY ? scaleX : scaleY;

    final double offsetX = (size.width - imageSize.width * scale) / 2;
    final double offsetY = (size.height - imageSize.height * scale) / 2;

    Offset mapPoint(PoseLandmark landmark) {
      double x = landmark.x * scale + offsetX;
      final double y = landmark.y * scale + offsetY;
      if (isFrontCamera) {
        x = size.width - x;
      }
      return Offset(x, y);
    }

    bool isReliable(PoseLandmark? lm) =>
        lm != null && lm.likelihood >= _minLikelihood;

    final Paint glowPaint = Paint()
      ..color = _neonGreen.withValues(alpha: 0.25)
      ..strokeWidth = 9.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final Paint mainPaint = Paint()
      ..color = _neonGreen
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final Paint jointGlowPaint = Paint()
      ..color = _neonGreen.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final Paint jointPaint = Paint()
      ..color = _neonGreen
      ..style = PaintingStyle.fill;

    final Map<PoseLandmarkType, PoseLandmark> lms = pose!.landmarks;

    void drawSegment(PoseLandmarkType a, PoseLandmarkType b) {
      final la = lms[a];
      final lb = lms[b];
      if (!isReliable(la) || !isReliable(lb)) return;

      final pA = mapPoint(la!);
      final pB = mapPoint(lb!);

      canvas.drawLine(pA, pB, glowPaint);
      canvas.drawLine(pA, pB, mainPaint);
    }

    void drawJoint(PoseLandmarkType type) {
      final lm = lms[type];
      if (!isReliable(lm)) return;
      final pt = mapPoint(lm!);
      canvas.drawCircle(pt, 8.0, jointGlowPaint);
      canvas.drawCircle(pt, 5.0, jointPaint);
    }

    // Shoulders
    drawSegment(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);

    // Torso / Spine sides
    drawSegment(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    drawSegment(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
    drawSegment(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

    // Left leg
    drawSegment(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    drawSegment(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);

    // Right leg
    drawSegment(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    drawSegment(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

    // Arms
    drawSegment(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    drawSegment(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    drawSegment(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    drawSegment(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

    // Joints
    const keyJoints = [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ];

    for (final j in keyJoints) {
      drawJoint(j);
    }
  }

  @override
  bool shouldRepaint(covariant PoseSkeletonPainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.isFrontCamera != isFrontCamera;
  }
}
