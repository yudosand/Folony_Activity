enum FaceScanScenario {
  enrollment,
  verification,
}

enum FaceScanChallengeType {
  front,
  left,
  right,
  up,
  down,
  blink,
}

class FaceScanChallenge {
  const FaceScanChallenge({
    required this.type,
    required this.label,
    required this.instruction,
    this.captureOnComplete = true,
    this.requiredStableFrames = 1,
  });

  final FaceScanChallengeType type;
  final String label;
  final String instruction;
  final bool captureOnComplete;
  final int requiredStableFrames;
}

class FaceObservation {
  const FaceObservation({
    required this.faceCount,
    required this.isCentered,
    required this.hasAcceptableSize,
    required this.faceWidthRatio,
    required this.faceHeightRatio,
    this.yaw = 0,
    this.pitch = 0,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
  });

  final int faceCount;
  final bool isCentered;
  final bool hasAcceptableSize;
  final double faceWidthRatio;
  final double faceHeightRatio;
  final double yaw;
  final double pitch;
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;
}

class FaceScanFrameUpdate {
  const FaceScanFrameUpdate({
    required this.guidance,
    required this.completedSteps,
    required this.totalSteps,
    required this.shouldCaptureFrame,
    required this.scanCompleted,
    required this.currentChallenge,
  });

  final String guidance;
  final int completedSteps;
  final int totalSteps;
  final bool shouldCaptureFrame;
  final bool scanCompleted;
  final FaceScanChallenge? currentChallenge;
}

class FaceScanEngine {
  FaceScanEngine.enrollment()
      : _scenario = FaceScanScenario.enrollment,
        _challenges = const [
          FaceScanChallenge(
            type: FaceScanChallengeType.front,
            label: 'Scan wajah 1',
            instruction: 'Lihat ke kamera dan tahan wajah tetap di area oval.',
            requiredStableFrames: 3,
          ),
          FaceScanChallenge(
            type: FaceScanChallengeType.front,
            label: 'Scan wajah 2',
            instruction: 'Tetap lihat kamera. Pastikan cahaya wajah cukup terang.',
            requiredStableFrames: 3,
          ),
          FaceScanChallenge(
            type: FaceScanChallengeType.front,
            label: 'Scan wajah 3',
            instruction: 'Tahan beberapa detik lagi sampai scan selesai.',
            requiredStableFrames: 3,
          ),
        ];

  FaceScanEngine.verification({
    required String actionLabel,
    required FaceScanChallengeType turnChallenge,
  })  : assert(
          turnChallenge == FaceScanChallengeType.left ||
              turnChallenge == FaceScanChallengeType.right,
          'turnChallenge must be left or right.',
        ),
        _scenario = FaceScanScenario.verification,
        _challenges = [
          FaceScanChallenge(
            type: FaceScanChallengeType.front,
            label: 'Scan wajah',
            instruction:
                'Lihat ke kamera untuk verifikasi $actionLabel. Tidak perlu tengok atau kedip.',
            requiredStableFrames: 5,
          ),
        ];

  final FaceScanScenario _scenario;
  final List<FaceScanChallenge> _challenges;
  int _currentIndex = 0;
  int _stableFrames = 0;
  bool _blinkClosedSeen = false;
  bool _blinkFallbackAccepted = false;
  int _livenessScore = 0;

  List<FaceScanChallenge> get challenges => List.unmodifiable(_challenges);

  bool get isComplete => _currentIndex >= _challenges.length;

  FaceScanChallenge? get currentChallenge =>
      isComplete ? null : _challenges[_currentIndex];

  double get livenessScore => _scenario == FaceScanScenario.verification
      ? _livenessScore.clamp(0, 100).toDouble()
      : 0;

  FaceScanFrameUpdate evaluate(FaceObservation observation) {
    final challenge = currentChallenge;
    if (challenge == null) {
      return FaceScanFrameUpdate(
        guidance: 'Scan wajah selesai.',
        completedSteps: _challenges.length,
        totalSteps: _challenges.length,
        shouldCaptureFrame: false,
        scanCompleted: true,
        currentChallenge: null,
      );
    }

    if (observation.faceCount == 0) {
      _resetProgress();
      return _update(
        challenge,
        guidance: 'Wajah belum terlihat jelas. Lihat ke kamera dan pastikan cahaya cukup terang.',
      );
    }

    if (observation.faceCount > 1) {
      _resetProgress();
      return _update(
        challenge,
        guidance: 'Pastikan hanya satu wajah yang masuk ke frame kamera.',
      );
    }

    if (!observation.hasAcceptableSize) {
      _resetProgress();
      return _update(
        challenge,
        guidance: 'Jarak wajah belum pas. Dekatkan sedikit dan tahan di area oval.',
      );
    }

    switch (challenge.type) {
      case FaceScanChallengeType.front:
        final isFramedEnough = observation.faceWidthRatio >= 0.24 &&
            observation.faceHeightRatio >= 0.30;
        if (!isFramedEnough) {
          _resetProgress();
          return _update(
            challenge,
            guidance:
                'Dekatkan wajah sedikit lagi sampai dahi, mata, dan dagu jelas di area oval.',
          );
        }
        return _evaluatePose(
          challenge,
          matched: observation.isCentered &&
              observation.yaw.abs() <= 18 &&
              observation.pitch.abs() <= 18,
          retryMessage:
              'Lihat lurus ke kamera dan posisikan wajah di tengah area oval.',
        );
      case FaceScanChallengeType.left:
        return _evaluatePose(
          challenge,
          matched: observation.yaw >= 14,
          retryMessage: challenge.instruction,
        );
      case FaceScanChallengeType.right:
        return _evaluatePose(
          challenge,
          matched: observation.yaw <= -14,
          retryMessage: challenge.instruction,
        );
      case FaceScanChallengeType.up:
        return _evaluatePose(
          challenge,
          matched: observation.pitch >= 12,
          retryMessage: challenge.instruction,
        );
      case FaceScanChallengeType.down:
        return _evaluatePose(
          challenge,
          matched: observation.pitch <= -12,
          retryMessage: challenge.instruction,
        );
      case FaceScanChallengeType.blink:
        return _evaluateBlink(challenge, observation);
    }
  }

  FaceScanFrameUpdate _evaluatePose(
    FaceScanChallenge challenge, {
    required bool matched,
    required String retryMessage,
  }) {
    if (!matched) {
      _resetProgress();
      return _update(challenge, guidance: retryMessage);
    }

    _stableFrames += 1;
    if (_stableFrames < challenge.requiredStableFrames) {
      return _update(
        challenge,
        guidance: '${challenge.label} terdeteksi. Tahan stabil sebentar lagi.',
      );
    }

    return _completeCurrentChallenge(challenge);
  }

  FaceScanFrameUpdate _evaluateBlink(
    FaceScanChallenge challenge,
    FaceObservation observation,
  ) {
    final leftEye = observation.leftEyeOpenProbability;
    final rightEye = observation.rightEyeOpenProbability;
    if (leftEye == null || rightEye == null) {
      _stableFrames += 1;
      if (_stableFrames >= 2) {
        _blinkFallbackAccepted = true;
        return _completeCurrentChallenge(challenge);
      }
      return _update(
        challenge,
        guidance:
            'Tatap kamera lurus sebentar. Device ini akan lanjut otomatis jika kedipan sulit terbaca.',
      );
    }

    if (!_blinkClosedSeen) {
      if (leftEye <= 0.35 && rightEye <= 0.35) {
        _blinkClosedSeen = true;
        return _update(
          challenge,
          guidance: 'Bagus. Sekarang buka mata kembali untuk lanjut.',
        );
      }

      return _update(
        challenge,
        guidance: challenge.instruction,
      );
    }

    if (leftEye >= 0.65 && rightEye >= 0.65) {
      return _completeCurrentChallenge(challenge);
    }

    return _update(
      challenge,
      guidance: 'Buka mata kembali sampai indikator scan selesai.',
    );
  }

  FaceScanFrameUpdate _completeCurrentChallenge(FaceScanChallenge challenge) {
    _livenessScore += _scoreForCompletion(challenge);
    _currentIndex += 1;
    _stableFrames = 0;
    _blinkClosedSeen = false;
    _blinkFallbackAccepted = false;

    return FaceScanFrameUpdate(
      guidance: isComplete
          ? 'Scan wajah selesai. Menyimpan hasil...'
          : '${challenge.label} berhasil. Lanjut ke ${currentChallenge!.label}.',
      completedSteps: _currentIndex,
      totalSteps: _challenges.length,
      shouldCaptureFrame: challenge.captureOnComplete,
      scanCompleted: isComplete,
      currentChallenge: currentChallenge,
    );
  }

  FaceScanFrameUpdate _update(
    FaceScanChallenge challenge, {
    required String guidance,
  }) {
    return FaceScanFrameUpdate(
      guidance: guidance,
      completedSteps: _currentIndex,
      totalSteps: _challenges.length,
      shouldCaptureFrame: false,
      scanCompleted: false,
      currentChallenge: challenge,
    );
  }

  void _resetProgress() {
    _stableFrames = 0;
    _blinkClosedSeen = false;
    _blinkFallbackAccepted = false;
  }

  int _scoreForCompletion(FaceScanChallenge challenge) {
    if (_scenario != FaceScanScenario.verification) {
      return 0;
    }

    switch (challenge.type) {
      case FaceScanChallengeType.front:
        return 100;
      case FaceScanChallengeType.left:
      case FaceScanChallengeType.right:
      case FaceScanChallengeType.up:
      case FaceScanChallengeType.down:
        return 32;
      case FaceScanChallengeType.blink:
        return _blinkFallbackAccepted ? 15 : 40;
    }
  }
}
