import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/pose_math.dart';
import '../../models/form_check_result.dart';
import '../../models/form_exercise.dart';
import '../../services/form_analysis_service.dart';
import '../../widgets/pose_skeleton_painter.dart';
import 'form_result_screen.dart';

enum _FormPhase { initializing, countdown, analysing, done }

class FormCameraScreen extends StatefulWidget {
  final FormExercise exercise;
  const FormCameraScreen({super.key, required this.exercise});

  @override
  State<FormCameraScreen> createState() => _FormCameraScreenState();
}

class _FormCameraScreenState extends State<FormCameraScreen> {
  CameraController? _controller;
  CameraDescription? _camera;
  PoseDetector? _detector;

  _FormPhase _phase = _FormPhase.initializing;
  int _countdown = 3;
  int _remaining = 10;

  Pose? _currentPose;
  Size _effectiveImageSize = Size.zero;

  // Squat tracking data (kept unchanged)
  double _minKneeAngle = 180.0;
  double _maxKneeAngle = 0.0;
  double _maxTorsoLean = 0.0;
  int _repCount = 0;
  int _validFrameCount = 0;
  bool _repWasStanding = false;
  bool _repInBottom = false;

  // Leg Press tracking data
  double _lpMinKneeAngle = 180.0;
  double _lpMaxKneeAngle = 0.0;
  double _lpMaxHipDrift = 0.0;
  double? _lpBaseHipX;
  double? _lpBaseHipY;
  int _lpRepCount = 0;
  int _lpValidFrameCount = 0;
  bool _lpWasExtended = false;
  bool _lpInBottom = false;

  // Bicep Curl tracking data
  double _bcMinElbowAngle = 180.0;
  double _bcMaxElbowAngle = 0.0;
  double _bcMaxElbowDrift = 0.0;
  double _bcMaxShoulderMovement = 0.0;
  double? _bcBaseElbowX;
  double? _bcBaseElbowY;
  double? _bcBaseShoulderX;
  double? _bcBaseShoulderY;
  int _bcRepCount = 0;
  int _bcValidFrameCount = 0;
  bool _bcWasExtended = false;
  bool _bcInContracted = false;

  bool _isProcessing = false;
  bool _streamActive = false;

  Timer? _countdownTimer;
  Timer? _analysisTimer;

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('Không tìm thấy camera trên thiết bị.');
      }

      final rearCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _camera = rearCamera;

      final ctrl = CameraController(
        rearCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }

      _detector = PoseDetector(
        options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
      );

      setState(() {
        _controller = ctrl;
      });

      _startCountdown();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể khởi động camera: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _startCountdown() {
    if (!mounted) return;
    setState(() {
      _phase = _FormPhase.countdown;
      _countdown = 3;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        _startAnalysis();
      }
    });
  }

  void _startAnalysis() {
    if (!mounted) return;
    setState(() {
      _phase = _FormPhase.analysing;
      _remaining = 10;
    });

    _startImageStream();

    _analysisTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remaining > 1) {
        setState(() => _remaining--);
      } else {
        timer.cancel();
        _finishAnalysis();
      }
    });
  }

  void _startImageStream() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    _streamActive = true;
    _controller!.startImageStream(_processCameraImage);
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing || !_streamActive || _phase != _FormPhase.analysing) return;
    _isProcessing = true;

    try {
      final inputImage = _toInputImage(image);
      if (inputImage == null || _detector == null) {
        _isProcessing = false;
        return;
      }

      final poses = await _detector!.processImage(inputImage);
      if (!mounted || !_streamActive) {
        _isProcessing = false;
        return;
      }

      if (poses.isNotEmpty) {
        final pose = poses.first;
        _trackPose(pose);

        final rotation = inputImage.metadata?.rotation ?? InputImageRotation.rotation0deg;
        final bool isRotated = rotation == InputImageRotation.rotation90deg ||
            rotation == InputImageRotation.rotation270deg;

        final effectiveSize = isRotated
            ? Size(image.height.toDouble(), image.width.toDouble())
            : Size(image.width.toDouble(), image.height.toDouble());

        if (mounted) {
          setState(() {
            _currentPose = pose;
            _effectiveImageSize = effectiveSize;
          });
        }
      }
    } catch (_) {
      // Continue next frame on any transient failure
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    if (_controller == null || _camera == null) return null;

    final sensorOrientation = _camera!.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (_camera!.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    if (rotation == null) return null;

    Uint8List bytes;
    if (image.planes.length == 1) {
      bytes = image.planes.first.bytes;
    } else {
      final writeBuffer = WriteBuffer();
      for (final plane in image.planes) {
        writeBuffer.putUint8List(plane.bytes);
      }
      bytes = writeBuffer.done().buffer.asUint8List();
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: Platform.isAndroid
            ? InputImageFormat.nv21
            : InputImageFormat.bgra8888,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  void _trackPose(Pose pose) {
    switch (widget.exercise) {
      case FormExercise.squat:
        _trackSquatPose(pose);
      case FormExercise.legPress:
        _trackLegPressPose(pose);
      case FormExercise.bicepCurl:
        _trackBicepCurlPose(pose);
    }
  }

  void _trackSquatPose(Pose pose) {
    final lms = pose.landmarks;

    final lShoulder = lms[PoseLandmarkType.leftShoulder];
    final lHip = lms[PoseLandmarkType.leftHip];
    final lKnee = lms[PoseLandmarkType.leftKnee];
    final lAnkle = lms[PoseLandmarkType.leftAnkle];

    final rShoulder = lms[PoseLandmarkType.rightShoulder];
    final rHip = lms[PoseLandmarkType.rightHip];
    final rKnee = lms[PoseLandmarkType.rightKnee];
    final rAnkle = lms[PoseLandmarkType.rightAnkle];

    final lConfidence = _averageConfidence([
      lShoulder?.likelihood,
      lHip?.likelihood,
      lKnee?.likelihood,
      lAnkle?.likelihood,
    ]);

    final rConfidence = _averageConfidence([
      rShoulder?.likelihood,
      rHip?.likelihood,
      rKnee?.likelihood,
      rAnkle?.likelihood,
    ]);

    // Choose side with better visibility
    final bool useLeft = lConfidence >= rConfidence;
    final hip = useLeft ? lHip : rHip;
    final knee = useLeft ? lKnee : rKnee;
    final ankle = useLeft ? lAnkle : rAnkle;
    final shoulder = useLeft ? lShoulder : rShoulder;

    if (hip == null || knee == null || ankle == null) return;
    if (hip.likelihood < 0.4 || knee.likelihood < 0.4 || ankle.likelihood < 0.4) {
      return;
    }

    final kneeAngle = angleDeg(
      (x: hip.x, y: hip.y),
      (x: knee.x, y: knee.y),
      (x: ankle.x, y: ankle.y),
    );

    _minKneeAngle = math.min(_minKneeAngle, kneeAngle);
    _maxKneeAngle = math.max(_maxKneeAngle, kneeAngle);

    // Torso lean relative to vertical (dx / dy)
    if (shoulder != null && shoulder.likelihood >= 0.4) {
      final dx = (shoulder.x - hip.x).abs();
      final dy = (shoulder.y - hip.y).abs();
      final torsoAngle = math.atan2(dx, dy) * 180 / math.pi;
      _maxTorsoLean = math.max(_maxTorsoLean, torsoAngle);
    }

    // Rep state machine: standing (>155°) -> bottom (<115°) -> standing (>155°)
    if (kneeAngle > 155) {
      if (_repInBottom) {
        _repCount++;
        _repInBottom = false;
      }
      _repWasStanding = true;
    } else if (kneeAngle < 115 && _repWasStanding) {
      _repInBottom = true;
    }

    _validFrameCount++;
  }

  void _trackLegPressPose(Pose pose) {
    final lms = pose.landmarks;

    final lShoulder = lms[PoseLandmarkType.leftShoulder];
    final lHip = lms[PoseLandmarkType.leftHip];
    final lKnee = lms[PoseLandmarkType.leftKnee];
    final lAnkle = lms[PoseLandmarkType.leftAnkle];

    final rShoulder = lms[PoseLandmarkType.rightShoulder];
    final rHip = lms[PoseLandmarkType.rightHip];
    final rKnee = lms[PoseLandmarkType.rightKnee];
    final rAnkle = lms[PoseLandmarkType.rightAnkle];

    final lConfidence = _averageConfidence([
      lShoulder?.likelihood,
      lHip?.likelihood,
      lKnee?.likelihood,
      lAnkle?.likelihood,
    ]);

    final rConfidence = _averageConfidence([
      rShoulder?.likelihood,
      rHip?.likelihood,
      rKnee?.likelihood,
      rAnkle?.likelihood,
    ]);

    // Choose side with better visibility
    final bool useLeft = lConfidence >= rConfidence;
    final hip = useLeft ? lHip : rHip;
    final knee = useLeft ? lKnee : rKnee;
    final ankle = useLeft ? lAnkle : rAnkle;

    if (hip == null || knee == null || ankle == null) return;
    if (hip.likelihood < 0.4 || knee.likelihood < 0.4 || ankle.likelihood < 0.4) {
      return;
    }

    final kneeAngle = angleDeg(
      (x: hip.x, y: hip.y),
      (x: knee.x, y: knee.y),
      (x: ankle.x, y: ankle.y),
    );

    _lpMinKneeAngle = math.min(_lpMinKneeAngle, kneeAngle);
    _lpMaxKneeAngle = math.max(_lpMaxKneeAngle, kneeAngle);

    // Normalized hip drift relative to upper leg length (hip to knee)
    final upperLegLength = math.sqrt(
      math.pow(knee.x - hip.x, 2) + math.pow(knee.y - hip.y, 2),
    );

    _lpBaseHipX ??= hip.x;
    _lpBaseHipY ??= hip.y;

    if (upperLegLength > 10) {
      final hipDisplacement = math.sqrt(
        math.pow(hip.x - _lpBaseHipX!, 2) + math.pow(hip.y - _lpBaseHipY!, 2),
      );
      final normalizedDrift = hipDisplacement / upperLegLength;
      _lpMaxHipDrift = math.max(_lpMaxHipDrift, normalizedDrift);
    }

    // Rep state machine for Leg Press: extended (>150°) -> flexed (<115°) -> extended (>150°)
    if (kneeAngle > 150) {
      if (_lpInBottom) {
        _lpRepCount++;
        _lpInBottom = false;
      }
      _lpWasExtended = true;
    } else if (kneeAngle < 115 && _lpWasExtended) {
      _lpInBottom = true;
    }

    _lpValidFrameCount++;
  }

  void _trackBicepCurlPose(Pose pose) {
    final lms = pose.landmarks;

    final lShoulder = lms[PoseLandmarkType.leftShoulder];
    final lElbow = lms[PoseLandmarkType.leftElbow];
    final lWrist = lms[PoseLandmarkType.leftWrist];

    final rShoulder = lms[PoseLandmarkType.rightShoulder];
    final rElbow = lms[PoseLandmarkType.rightElbow];
    final rWrist = lms[PoseLandmarkType.rightWrist];

    final lConfidence = _averageConfidence([
      lShoulder?.likelihood,
      lElbow?.likelihood,
      lWrist?.likelihood,
    ]);

    final rConfidence = _averageConfidence([
      rShoulder?.likelihood,
      rElbow?.likelihood,
      rWrist?.likelihood,
    ]);

    // Choose arm with stronger visibility
    final bool useLeft = lConfidence >= rConfidence;
    final shoulder = useLeft ? lShoulder : rShoulder;
    final elbow = useLeft ? lElbow : rElbow;
    final wrist = useLeft ? lWrist : rWrist;

    if (shoulder == null || elbow == null || wrist == null) return;
    if (shoulder.likelihood < 0.4 || elbow.likelihood < 0.4 || wrist.likelihood < 0.4) {
      return;
    }

    final elbowAngle = angleDeg(
      (x: shoulder.x, y: shoulder.y),
      (x: elbow.x, y: elbow.y),
      (x: wrist.x, y: wrist.y),
    );

    _bcMinElbowAngle = math.min(_bcMinElbowAngle, elbowAngle);
    _bcMaxElbowAngle = math.max(_bcMaxElbowAngle, elbowAngle);

    // Upper arm length reference (shoulder to elbow)
    final upperArmLength = math.sqrt(
      math.pow(elbow.x - shoulder.x, 2) + math.pow(elbow.y - shoulder.y, 2),
    );

    _bcBaseElbowX ??= elbow.x;
    _bcBaseElbowY ??= elbow.y;
    _bcBaseShoulderX ??= shoulder.x;
    _bcBaseShoulderY ??= shoulder.y;

    if (upperArmLength > 10) {
      // Normalized elbow drift
      final elbowDisp = math.sqrt(
        math.pow(elbow.x - _bcBaseElbowX!, 2) + math.pow(elbow.y - _bcBaseElbowY!, 2),
      );
      _bcMaxElbowDrift = math.max(_bcMaxElbowDrift, elbowDisp / upperArmLength);

      // Normalized shoulder/body swing
      final shoulderDisp = math.sqrt(
        math.pow(shoulder.x - _bcBaseShoulderX!, 2) +
            math.pow(shoulder.y - _bcBaseShoulderY!, 2),
      );
      _bcMaxShoulderMovement =
          math.max(_bcMaxShoulderMovement, shoulderDisp / upperArmLength);
    }

    // Rep state machine for Bicep Curl: extended (>145°) -> contracted (<70°) -> extended (>145°)
    if (elbowAngle > 145) {
      if (_bcInContracted) {
        _bcRepCount++;
        _bcInContracted = false;
      }
      _bcWasExtended = true;
    } else if (elbowAngle < 70 && _bcWasExtended) {
      _bcInContracted = true;
    }

    _bcValidFrameCount++;
  }

  double _averageConfidence(List<double?> values) {
    final valid = values.whereType<double>().toList();
    if (valid.isEmpty) return 0;
    return valid.reduce((a, b) => a + b) / valid.length;
  }

  Future<void> _finishAnalysis() async {
    if (_phase == _FormPhase.done) return;
    if (mounted) {
      setState(() => _phase = _FormPhase.done);
    }

    await _stopStream();

    const service = FormAnalysisService();
    final FormCheckResult result = switch (widget.exercise) {
      FormExercise.squat => service.analyseSquat(
          SquatSessionData()
            ..minKneeAngle = _minKneeAngle == 180.0 ? 150.0 : _minKneeAngle
            ..maxKneeAngle = _maxKneeAngle
            ..maxTorsoLean = _maxTorsoLean
            ..repCount = _repCount
            ..validFrameCount = _validFrameCount,
        ),
      FormExercise.legPress => service.analyseLegPress(
          LegPressSessionData()
            ..minKneeAngle = _lpMinKneeAngle == 180.0 ? 150.0 : _lpMinKneeAngle
            ..maxKneeAngle = _lpMaxKneeAngle
            ..maxHipDrift = _lpMaxHipDrift
            ..repCount = _lpRepCount
            ..validFrameCount = _lpValidFrameCount,
        ),
      FormExercise.bicepCurl => service.analyseBicepCurl(
          BicepCurlSessionData()
            ..minElbowAngle = _bcMinElbowAngle == 180.0 ? 150.0 : _bcMinElbowAngle
            ..maxElbowAngle = _bcMaxElbowAngle
            ..maxElbowDrift = _bcMaxElbowDrift
            ..maxShoulderMovement = _bcMaxShoulderMovement
            ..repCount = _bcRepCount
            ..validFrameCount = _bcValidFrameCount,
        ),
    };

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FormResultScreen(result: result),
      ),
    );
  }

  Future<void> _stopStream() async {
    _streamActive = false;
    try {
      if (_controller?.value.isStreamingImages == true) {
        await _controller!.stopImageStream();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _analysisTimer?.cancel();
    _streamActive = false;
    _controller?.dispose();
    _detector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          if (_controller?.value.isInitialized == true)
            _CameraPreviewBox(controller: _controller!),

          // Neon Green Skeleton
          if (_phase == _FormPhase.analysing &&
              _currentPose != null &&
              _effectiveImageSize != Size.zero)
            CustomPaint(
              painter: PoseSkeletonPainter(
                pose: _currentPose,
                imageSize: _effectiveImageSize,
                isFrontCamera: _camera?.lensDirection == CameraLensDirection.front,
              ),
            ),

          // Dark Overlay & Controls
          SafeArea(
            child: Column(
              children: [
                // Top Header Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          widget.exercise.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Center Countdown or Active HUD
                if (_phase == _FormPhase.initializing)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Đang khởi động camera…',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),

                if (_phase == _FormPhase.countdown)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_countdown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 92,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Chuẩn bị vị trí…',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                if (_phase == _FormPhase.analysing)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF39FF14).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF39FF14).withValues(alpha: 0.6),
                          ),
                        ),
                        child: const Text(
                          'FORM CHECK',
                          style: TextStyle(
                            color: Color(0xFF39FF14),
                            fontSize: 12,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '00:${_remaining.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Đang kiểm tra chuyển động',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),

                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraPreviewBox extends StatelessWidget {
  final CameraController controller;
  const _CameraPreviewBox({required this.controller});

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: previewSize.height,
              height: previewSize.width,
              child: CameraPreview(controller),
            ),
          ),
        );
      },
    );
  }
}
