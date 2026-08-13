import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../domain/face_scan_engine.dart';

class FaceScanResult {
  const FaceScanResult({
    required this.samplePaths,
    this.primaryCapturePath,
    this.livenessScore = 0,
  });

  final List<String> samplePaths;
  final String? primaryCapturePath;
  final double livenessScore;
}

enum FaceScanVerificationPurpose {
  checkIn,
  checkOut,
}

class FaceScanPage extends StatefulWidget {
  const FaceScanPage.enrollment({super.key})
      : scenario = FaceScanScenario.enrollment,
        verificationPurpose = null;

  const FaceScanPage.verification({
    super.key,
    required this.verificationPurpose,
  }) : scenario = FaceScanScenario.verification;

  final FaceScanScenario scenario;
  final FaceScanVerificationPurpose? verificationPurpose;

  @override
  State<FaceScanPage> createState() => _FaceScanPageState();
}

class _FaceScanPageState extends State<FaceScanPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanLineController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);
  late final FaceScanEngine _engine =
      widget.scenario == FaceScanScenario.enrollment
          ? FaceScanEngine.enrollment()
          : FaceScanEngine.verification(
              actionLabel: _verificationLabel.toLowerCase(),
              turnChallenge: _verificationTurnChallenge,
            );
  late final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableClassification: true,
      minFaceSize: 0.15,
    ),
  );

  CameraController? _cameraController;
  bool _isStreaming = false;
  bool _isAnalyzing = false;
  bool _isCapturingSample = false;
  bool _isFinishing = false;
  String? _cameraError;
  String _statusText = 'Menyiapkan kamera depan untuk face scan...';
  final List<String> _capturedPaths = [];
  String? _primaryCapturePath;

  String get _verificationLabel {
    switch (widget.verificationPurpose) {
      case FaceScanVerificationPurpose.checkOut:
        return 'Check-out';
      case FaceScanVerificationPurpose.checkIn:
      case null:
        return 'Check-in';
    }
  }

  String get _pageTitle {
    if (widget.scenario == FaceScanScenario.enrollment) {
      return 'Scan Face ID MVP';
    }
    return 'Face $_verificationLabel';
  }

  String get _pageDescription {
    if (widget.scenario == FaceScanScenario.enrollment) {
      return 'Ikuti scan singkat: depan, kiri, kanan, lalu kedip sekali.';
    }
    return 'Lihat ke kamera, ikuti satu gerakan tengok, lalu kedip sekali agar verifikasi $_verificationLabel lebih hidup dan aman.';
  }

  FaceScanChallengeType get _verificationTurnChallenge {
    switch (widget.verificationPurpose) {
      case FaceScanVerificationPurpose.checkOut:
        return FaceScanChallengeType.right;
      case FaceScanVerificationPurpose.checkIn:
      case null:
        return FaceScanChallengeType.left;
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_initCamera());
  }

  @override
  void dispose() {
    unawaited(_stopImageStream());
    unawaited(_faceDetector.close());
    _cameraController?.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentChallenge = _engine.currentChallenge;
    final completedSteps = _capturedProgressCount;
    final totalSteps = _engine.challenges.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          children: [
            Text(
              _pageDescription,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            _FaceScanProgressCard(
              completedSteps: completedSteps,
              totalSteps: totalSteps,
              currentLabel: currentChallenge?.label ?? 'Selesai',
              instruction: currentChallenge?.instruction ??
                  'Scan wajah selesai diproses.',
              statusText: _statusText,
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FBF9),
                  ),
                  child: SizedBox.expand(
                    child: _buildCameraFrame(theme),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isBusy ? null : () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                if (_cameraError != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isBusy ? null : _retryCamera,
                      child: const Text('Coba Lagi'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _isBusy => _isAnalyzing || _isCapturingSample || _isFinishing;

  int get _capturedProgressCount {
    if (widget.scenario == FaceScanScenario.enrollment) {
      return _engine.challenges
          .where((challenge) => challenge.captureOnComplete)
          .take(_capturedPaths.length)
          .length;
    }
    return _primaryCapturePath == null ? 0 : 2;
  }

  Widget _buildCameraFrame(ThemeData theme) {
    if (_cameraError != null) {
      return _buildCameraPlaceholder(
        theme,
        icon: Icons.videocam_off_rounded,
        message: _cameraError!,
      );
    }

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return _buildCameraPlaceholder(
        theme,
        icon: Icons.camera_alt_rounded,
        message: 'Menyiapkan kamera depan untuk face scan...',
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: CameraPreview(controller),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.08),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.06),
                ],
              ),
            ),
          ),
        ),
        Container(
          width: 220,
          height: 290,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(140),
            border: Border.all(
              color: Colors.white,
              width: 2.4,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 20,
              ),
            ],
          ),
        ),
        AnimatedBuilder(
          animation: _scanLineController,
          builder: (context, _) {
            return Positioned(
              top: 48 + (185 * _scanLineController.value),
              child: Container(
                width: 184,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        Positioned(
          top: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.face_retouching_natural_rounded, size: 16),
                const SizedBox(width: 8),
                Text(
                  _engine.currentChallenge?.label ?? 'Selesai',
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraPlaceholder(
    ThemeData theme, {
    required IconData icon,
    required String message,
  }) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE4F2ED),
            Color(0xFFF6F2EA),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _retryCamera() async {
    setState(() {
      _cameraError = null;
      _statusText = 'Menyiapkan ulang kamera depan...';
    });
    await _cameraController?.dispose();
    _cameraController = null;
    await _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) {
        return;
      }

      if (cameras.isEmpty) {
        setState(() {
          _cameraError = 'Kamera tidak ditemukan di device ini.';
        });
        return;
      }

      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup:
            Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21,
      );

      await controller.initialize();
      await controller.setFocusMode(FocusMode.auto);
      await controller.setExposureMode(ExposureMode.auto);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _cameraError = null;
        _statusText = 'Arahkan wajah ke tengah. Scan akan berjalan otomatis.';
      });

      await _startImageStream();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cameraError =
            'Kamera tidak bisa diakses. Pastikan izin kamera tersedia.';
      });
    }
  }

  Future<void> _startImageStream() async {
    final controller = _cameraController;
    if (controller == null || _isStreaming || !controller.value.isInitialized) {
      return;
    }

    await controller.startImageStream((image) {
      if (_isAnalyzing || _isCapturingSample || _isFinishing) {
        return;
      }
      unawaited(_processCameraImage(image));
    });

    _isStreaming = true;
  }

  Future<void> _stopImageStream() async {
    final controller = _cameraController;
    if (controller == null || !_isStreaming) {
      return;
    }

    await controller.stopImageStream();
    _isStreaming = false;
  }

  Future<void> _processCameraImage(CameraImage image) async {
    final controller = _cameraController;
    if (controller == null || !mounted || _isFinishing) {
      return;
    }

    final inputImage = _buildInputImage(controller, image);
    if (inputImage == null) {
      return;
    }

    _isAnalyzing = true;
    try {
      final faces = await _faceDetector.processImage(inputImage);
      if (!mounted) {
        return;
      }

      final observation = _buildObservation(
        faces: faces,
        imageWidth: image.width.toDouble(),
        imageHeight: image.height.toDouble(),
      );
      final update = _engine.evaluate(observation);
      setState(() {
        _statusText = update.guidance;
      });

      if (update.shouldCaptureFrame) {
        await _captureAcceptedFrame();
      } else if (update.scanCompleted) {
        await _finishScan();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText =
            'Scan wajah belum stabil. Pastikan cahaya cukup lalu coba lagi.';
      });
    } finally {
      _isAnalyzing = false;
    }
  }

  InputImage? _buildInputImage(
    CameraController controller,
    CameraImage image,
  ) {
    final rotation = InputImageRotationValue.fromRawValue(
      controller.description.sensorOrientation,
    );
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null) {
      return null;
    }

    final bytes = _concatenatePlanes(image.planes);
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final buffer = WriteBuffer();
    for (final plane in planes) {
      buffer.putUint8List(plane.bytes);
    }
    return buffer.done().buffer.asUint8List();
  }

  FaceObservation _buildObservation({
    required List<Face> faces,
    required double imageWidth,
    required double imageHeight,
  }) {
    if (faces.isEmpty) {
      return const FaceObservation(
        faceCount: 0,
        isCentered: false,
        hasAcceptableSize: false,
        faceWidthRatio: 0,
        faceHeightRatio: 0,
      );
    }

    final face = faces.first;
    final bounds = face.boundingBox;
    final centerX = bounds.center.dx / imageWidth;
    final centerY = bounds.center.dy / imageHeight;
    final faceWidthRatio = bounds.width / imageWidth;
    final faceHeightRatio = bounds.height / imageHeight;

    return FaceObservation(
      faceCount: faces.length,
      isCentered:
          (centerX - 0.5).abs() <= 0.22 && (centerY - 0.5).abs() <= 0.22,
      hasAcceptableSize: faceWidthRatio >= 0.22 && faceHeightRatio >= 0.24,
      faceWidthRatio: faceWidthRatio,
      faceHeightRatio: faceHeightRatio,
      yaw: face.headEulerAngleY ?? 0,
      pitch: face.headEulerAngleX ?? 0,
      leftEyeOpenProbability: face.leftEyeOpenProbability,
      rightEyeOpenProbability: face.rightEyeOpenProbability,
    );
  }

  Future<void> _captureAcceptedFrame() async {
    final controller = _cameraController;
    if (controller == null || _isCapturingSample || _isFinishing) {
      return;
    }

    _isCapturingSample = true;
    await _stopImageStream();
    try {
      final photo = await controller.takePicture();
      if (widget.scenario == FaceScanScenario.enrollment) {
        _capturedPaths.add(photo.path);
      } else {
        _primaryCapturePath = photo.path;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _statusText = _engine.isComplete
            ? 'Scan lengkap. Menyimpan hasil...'
            : 'Pose tersimpan. Ikuti instruksi langkah berikutnya.';
      });

      if (_engine.isComplete) {
        await _finishScan();
      } else {
        await _startImageStream();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText =
            'Capture wajah gagal. Tahan device stabil dan ikuti instruksi lagi.';
      });
      await _startImageStream();
    } finally {
      _isCapturingSample = false;
    }
  }

  Future<void> _finishScan() async {
    if (_isFinishing) {
      return;
    }

    _isFinishing = true;
    await _stopImageStream();

    if (!mounted) {
      return;
    }

    final result = FaceScanResult(
      samplePaths: List.unmodifiable(_capturedPaths),
      primaryCapturePath: _primaryCapturePath ?? _capturedPaths.lastOrNull,
      livenessScore: _engine.livenessScore,
    );
    Navigator.pop(context, result);
  }
}

class _FaceScanProgressCard extends StatelessWidget {
  const _FaceScanProgressCard({
    required this.completedSteps,
    required this.totalSteps,
    required this.currentLabel,
    required this.instruction,
    required this.statusText,
  });

  final int completedSteps;
  final int totalSteps;
  final String currentLabel;
  final String instruction;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeTotal = totalSteps == 0 ? 1 : totalSteps;
    final progress = (completedSteps / safeTotal).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  currentLabel,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                '$completedSteps/$totalSteps',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFE7E5E4),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            instruction,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            statusText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

extension on List<String> {
  String? get lastOrNull => isEmpty ? null : last;
}
