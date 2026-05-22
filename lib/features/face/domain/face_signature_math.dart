import 'dart:math' as math;

class FaceSignatureMath {
  static List<double> normalize(List<double> values) {
    if (values.isEmpty) {
      return const [];
    }

    final mean = values.reduce((left, right) => left + right) / values.length;
    final centered = values.map((value) => value - mean).toList(growable: false);
    final norm = math.sqrt(
      centered.fold<double>(0, (sum, value) => sum + (value * value)),
    );

    if (norm == 0) {
      return List<double>.filled(values.length, 0);
    }

    return centered
        .map((value) => double.parse((value / norm).toStringAsFixed(6)))
        .toList(growable: false);
  }

  static List<double> averageVectors(List<List<double>> vectors) {
    if (vectors.isEmpty) {
      return const [];
    }

    final length = vectors.first.length;
    final sums = List<double>.filled(length, 0);
    var counted = 0;

    for (final vector in vectors) {
      if (vector.length != length) {
        continue;
      }
      for (var index = 0; index < length; index++) {
        sums[index] += vector[index];
      }
      counted += 1;
    }

    if (counted == 0) {
      return const [];
    }

    final averages = sums
        .map((value) => value / counted)
        .toList(growable: false);
    return normalize(averages);
  }

  static double cosineSimilarity(List<double> left, List<double> right) {
    if (left.isEmpty || right.isEmpty || left.length != right.length) {
      return 0;
    }

    var dot = 0.0;
    var leftNorm = 0.0;
    var rightNorm = 0.0;

    for (var index = 0; index < left.length; index++) {
      dot += left[index] * right[index];
      leftNorm += left[index] * left[index];
      rightNorm += right[index] * right[index];
    }

    if (leftNorm == 0 || rightNorm == 0) {
      return 0;
    }

    final similarity = dot / (math.sqrt(leftNorm) * math.sqrt(rightNorm));
    return similarity.clamp(-1.0, 1.0);
  }

  static double cosineSimilarityScore(List<double> left, List<double> right) {
    final similarity = cosineSimilarity(left, right);
    return ((similarity + 1) / 2 * 100).clamp(0, 100);
  }
}
