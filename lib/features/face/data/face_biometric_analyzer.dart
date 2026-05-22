import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import '../domain/face_signature_math.dart';

class FaceBiometricAnalyzer {
  Future<FaceBiometricTemplate> buildEnrollmentTemplate(
    List<String> samplePaths,
  ) async {
    final signatures = <List<double>>[];

    for (final samplePath in samplePaths) {
      final result = await analyzeCapture(samplePath);
      signatures.add(result.signature);
    }

    if (signatures.length < 3) {
      throw StateError(
        'Minimal 3 sampel wajah yang valid dibutuhkan untuk enrollment.',
      );
    }

    return FaceBiometricTemplate(
      template: FaceSignatureMath.averageVectors(signatures),
      samplesCount: signatures.length,
    );
  }

  Future<FaceBiometricCapture> analyzeCapture(String imagePath) async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableClassification: true,
        enableLandmarks: true,
        minFaceSize: 0.15,
      ),
    );

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await detector.processImage(inputImage);
      if (faces.isEmpty) {
        throw StateError('Wajah tidak terdeteksi di hasil capture.');
      }

      final targetFace = _largestFace(faces);
      final bytes = await File(imagePath).readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        throw StateError('Capture wajah tidak bisa dibaca untuk analisis.');
      }

      final bakedImage = img.bakeOrientation(decodedImage);
      final croppedFace = _cropFace(bakedImage, targetFace.boundingBox);
      final appearanceVector = _buildAppearanceVector(croppedFace);
      final geometryVector = _buildGeometryVector(targetFace);

      return FaceBiometricCapture(
        signature: FaceSignatureMath.normalize([
          ...appearanceVector,
          ...geometryVector,
        ]),
      );
    } finally {
      await detector.close();
    }
  }

  Face _largestFace(List<Face> faces) {
    return faces.reduce((current, next) {
      final currentArea =
          current.boundingBox.width * current.boundingBox.height;
      final nextArea = next.boundingBox.width * next.boundingBox.height;
      return nextArea > currentArea ? next : current;
    });
  }

  img.Image _cropFace(img.Image image, Rect bounds) {
    final safeX = math.max(0, bounds.left.floor());
    final safeY = math.max(0, bounds.top.floor());
    final safeWidth = math.min(
      image.width - safeX,
      bounds.width.ceil(),
    );
    final safeHeight = math.min(
      image.height - safeY,
      bounds.height.ceil(),
    );

    final expandedX = math.max(0, safeX - (safeWidth * 0.12).round());
    final expandedY = math.max(0, safeY - (safeHeight * 0.12).round());
    final expandedWidth = math.min(
      image.width - expandedX,
      safeWidth + (safeWidth * 0.24).round(),
    );
    final expandedHeight = math.min(
      image.height - expandedY,
      safeHeight + (safeHeight * 0.24).round(),
    );

    return img.copyCrop(
      image,
      x: expandedX,
      y: expandedY,
      width: math.max(1, expandedWidth),
      height: math.max(1, expandedHeight),
    );
  }

  List<double> _buildAppearanceVector(img.Image image) {
    final grayscale = img.grayscale(image);
    final resized = img.copyResize(
      grayscale,
      width: 16,
      height: 16,
      interpolation: img.Interpolation.average,
    );

    final values = <double>[];
    for (var y = 0; y < resized.height; y++) {
      for (var x = 0; x < resized.width; x++) {
        final pixel = resized.getPixel(x, y);
        values.add(pixel.r / 255);
      }
    }

    return FaceSignatureMath.normalize(values);
  }

  List<double> _buildGeometryVector(Face face) {
    final bounds = face.boundingBox;
    final width = bounds.width == 0 ? 1 : bounds.width;
    final height = bounds.height == 0 ? 1 : bounds.height;

    math.Point<double>? relative(FaceLandmarkType type) {
      final landmark = face.landmarks[type];
      if (landmark == null) {
        return null;
      }
      return math.Point<double>(
        (landmark.position.x - bounds.left) / width,
        (landmark.position.y - bounds.top) / height,
      );
    }

    final leftEye = relative(FaceLandmarkType.leftEye);
    final rightEye = relative(FaceLandmarkType.rightEye);
    final nose = relative(FaceLandmarkType.noseBase);
    final leftMouth = relative(FaceLandmarkType.leftMouth);
    final rightMouth = relative(FaceLandmarkType.rightMouth);

    double deltaX(math.Point<double>? a, math.Point<double>? b) =>
        a == null || b == null ? 0 : b.x - a.x;
    double deltaY(math.Point<double>? a, math.Point<double>? b) =>
        a == null || b == null ? 0 : b.y - a.y;
    double averageY(math.Point<double>? a, math.Point<double>? b) =>
        a == null || b == null ? 0 : (a.y + b.y) / 2;
    double averageX(math.Point<double>? a, math.Point<double>? b) =>
        a == null || b == null ? 0 : (a.x + b.x) / 2;

    return FaceSignatureMath.normalize([
      deltaX(leftEye, rightEye),
      deltaY(leftEye, rightEye),
      deltaX(leftMouth, rightMouth),
      averageY(leftEye, rightEye),
      averageY(leftMouth, rightMouth),
      nose?.x ?? 0,
      nose?.y ?? 0,
      averageX(leftEye, rightEye),
      face.headEulerAngleX ?? 0,
      face.headEulerAngleY ?? 0,
      (face.leftEyeOpenProbability ?? 0.5),
      (face.rightEyeOpenProbability ?? 0.5),
    ]);
  }
}

class FaceBiometricTemplate {
  const FaceBiometricTemplate({
    required this.template,
    required this.samplesCount,
  });

  final List<double> template;
  final int samplesCount;
}

class FaceBiometricCapture {
  const FaceBiometricCapture({
    required this.signature,
  });

  final List<double> signature;
}
