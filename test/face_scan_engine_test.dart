import 'package:flutter_test/flutter_test.dart';

import 'package:folony_activity/features/face/domain/face_scan_engine.dart';

void main() {
  test('enrollment flow completes three stable front scans', () {
    final engine = FaceScanEngine.enrollment();

    for (var scanIndex = 1; scanIndex <= 3; scanIndex += 1) {
      FaceScanFrameUpdate? update;
      for (var frame = 1; frame <= 3; frame += 1) {
        update = engine.evaluate(
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
      }

      expect(update?.shouldCaptureFrame, isTrue);
      expect(update?.completedSteps, scanIndex);
      expect(update?.currentChallenge?.type,
          scanIndex == 3 ? isNull : FaceScanChallengeType.front);
    }

    expect(engine.isComplete, isTrue);
  });

  test('verification finishes with a few stable front frames only', () {
    final engine = FaceScanEngine.verification(
      actionLabel: 'check-in',
      turnChallenge: FaceScanChallengeType.left,
    );

    FaceScanFrameUpdate? update;
    for (var frame = 1; frame <= 5; frame += 1) {
      update = engine.evaluate(
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
    }

    expect(update?.shouldCaptureFrame, isTrue);
    expect(update?.scanCompleted, isTrue);
    expect(update?.currentChallenge, isNull);
    expect(engine.livenessScore, 100);
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
    expect(update.guidance, contains('Lihat lurus ke kamera'));
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
