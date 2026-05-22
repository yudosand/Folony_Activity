import 'package:flutter_test/flutter_test.dart';

import 'package:folony_activity/features/face/domain/face_scan_engine.dart';

void main() {
  test('enrollment flow completes front and left poses in order', () {
    final engine = FaceScanEngine.enrollment();

    final frontUpdate = engine.evaluate(
      const FaceObservation(
        faceCount: 1,
        isCentered: true,
        hasAcceptableSize: true,
        faceWidthRatio: 0.3,
        faceHeightRatio: 0.36,
        yaw: 0,
        pitch: 0,
      ),
    );
    expect(frontUpdate.shouldCaptureFrame, isFalse);
    expect(engine.currentChallenge?.type, FaceScanChallengeType.front);

    final frontCompleted = engine.evaluate(
      const FaceObservation(
        faceCount: 1,
        isCentered: true,
        hasAcceptableSize: true,
        faceWidthRatio: 0.3,
        faceHeightRatio: 0.36,
        yaw: 1,
        pitch: 1,
      ),
    );
    expect(frontCompleted.shouldCaptureFrame, isTrue);
    expect(engine.currentChallenge?.type, FaceScanChallengeType.left);

    final leftCompleted = engine.evaluate(
      const FaceObservation(
        faceCount: 1,
        isCentered: true,
        hasAcceptableSize: true,
        faceWidthRatio: 0.3,
        faceHeightRatio: 0.36,
        yaw: 18,
        pitch: 0,
      ),
    );
    expect(leftCompleted.shouldCaptureFrame, isTrue);
    expect(engine.currentChallenge?.type, FaceScanChallengeType.right);
  });

  test('blink challenge requires closed then open eyes', () {
    final engine = FaceScanEngine.verification(
      actionLabel: 'check-in',
      turnChallenge: FaceScanChallengeType.left,
    );

    engine.evaluate(
      const FaceObservation(
        faceCount: 1,
        isCentered: true,
        hasAcceptableSize: true,
        faceWidthRatio: 0.3,
        faceHeightRatio: 0.36,
        yaw: 0,
        pitch: 0,
      ),
    );
    engine.evaluate(
      const FaceObservation(
        faceCount: 1,
        isCentered: true,
        hasAcceptableSize: true,
        faceWidthRatio: 0.3,
        faceHeightRatio: 0.36,
        yaw: 0,
        pitch: 0,
      ),
    );

    expect(engine.currentChallenge?.type, FaceScanChallengeType.left);

    engine.evaluate(
      const FaceObservation(
        faceCount: 1,
        isCentered: true,
        hasAcceptableSize: true,
        faceWidthRatio: 0.3,
        faceHeightRatio: 0.36,
        yaw: 18,
        pitch: 0,
      ),
    );

    expect(engine.currentChallenge?.type, FaceScanChallengeType.blink);

    final waitingBlink = engine.evaluate(
      const FaceObservation(
        faceCount: 1,
        isCentered: true,
        hasAcceptableSize: true,
        faceWidthRatio: 0.3,
        faceHeightRatio: 0.36,
        yaw: 0,
        pitch: 0,
        leftEyeOpenProbability: 0.9,
        rightEyeOpenProbability: 0.88,
      ),
    );
    expect(waitingBlink.scanCompleted, isFalse);

    final blinkClosed = engine.evaluate(
      const FaceObservation(
        faceCount: 1,
        isCentered: true,
        hasAcceptableSize: true,
        faceWidthRatio: 0.3,
        faceHeightRatio: 0.36,
        yaw: 0,
        pitch: 0,
        leftEyeOpenProbability: 0.12,
        rightEyeOpenProbability: 0.18,
      ),
    );
    expect(blinkClosed.shouldCaptureFrame, isFalse);

    final blinkOpened = engine.evaluate(
      const FaceObservation(
        faceCount: 1,
        isCentered: true,
        hasAcceptableSize: true,
        faceWidthRatio: 0.3,
        faceHeightRatio: 0.36,
        yaw: 0,
        pitch: 0,
        leftEyeOpenProbability: 0.92,
        rightEyeOpenProbability: 0.94,
      ),
    );
    expect(blinkOpened.shouldCaptureFrame, isTrue);
    expect(blinkOpened.scanCompleted, isTrue);
    expect(engine.livenessScore, 100);
  });

  test('verification can finish with fallback blink and lower liveness score', () {
    final engine = FaceScanEngine.verification(
      actionLabel: 'check-out',
      turnChallenge: FaceScanChallengeType.right,
    );

    engine.evaluate(
      const FaceObservation(
        faceCount: 1,
        isCentered: true,
        hasAcceptableSize: true,
        faceWidthRatio: 0.3,
        faceHeightRatio: 0.36,
        yaw: 0,
        pitch: 0,
      ),
    );
    engine.evaluate(
      const FaceObservation(
        faceCount: 1,
        isCentered: true,
        hasAcceptableSize: true,
        faceWidthRatio: 0.3,
        faceHeightRatio: 0.36,
        yaw: 0,
        pitch: 0,
      ),
    );
    engine.evaluate(
      const FaceObservation(
        faceCount: 1,
        isCentered: true,
        hasAcceptableSize: true,
        faceWidthRatio: 0.3,
        faceHeightRatio: 0.36,
        yaw: -18,
        pitch: 0,
      ),
    );

    final firstBlinkFrame = engine.evaluate(
      const FaceObservation(
        faceCount: 1,
        isCentered: true,
        hasAcceptableSize: true,
        faceWidthRatio: 0.3,
        faceHeightRatio: 0.36,
        yaw: 0,
        pitch: 0,
      ),
    );
    expect(firstBlinkFrame.scanCompleted, isFalse);

    final secondBlinkFrame = engine.evaluate(
      const FaceObservation(
        faceCount: 1,
        isCentered: true,
        hasAcceptableSize: true,
        faceWidthRatio: 0.3,
        faceHeightRatio: 0.36,
        yaw: 0,
        pitch: 0,
      ),
    );
    expect(secondBlinkFrame.scanCompleted, isTrue);
    expect(engine.livenessScore, 75);
  });

  test('missing face resets guidance without progress', () {
    final engine = FaceScanEngine.enrollment();

    final update = engine.evaluate(
      const FaceObservation(
        faceCount: 0,
        isCentered: false,
        hasAcceptableSize: false,
        faceWidthRatio: 0,
        faceHeightRatio: 0,
      ),
    );

    expect(update.completedSteps, 0);
    expect(update.guidance, contains('Wajah belum terlihat'));
    expect(engine.currentChallenge?.type, FaceScanChallengeType.front);
  });

  test('front pose can pass even when centering is slightly off', () {
    final engine = FaceScanEngine.enrollment();

    final update = engine.evaluate(
      const FaceObservation(
        faceCount: 1,
        isCentered: false,
        hasAcceptableSize: true,
        faceWidthRatio: 0.3,
        faceHeightRatio: 0.36,
        yaw: 6,
        pitch: 4,
      ),
    );

    expect(update.shouldCaptureFrame, isFalse);
    expect(update.guidance, contains('Tahan stabil'));
    expect(engine.currentChallenge?.type, FaceScanChallengeType.front);
  });

  test('front pose asks user to get closer when face is still too small', () {
    final engine = FaceScanEngine.enrollment();

    final update = engine.evaluate(
      const FaceObservation(
        faceCount: 1,
        isCentered: true,
        hasAcceptableSize: true,
        faceWidthRatio: 0.18,
        faceHeightRatio: 0.24,
        yaw: 4,
        pitch: 2,
      ),
    );

    expect(update.shouldCaptureFrame, isFalse);
    expect(update.guidance, contains('Dekatkan wajah'));
  });
}
