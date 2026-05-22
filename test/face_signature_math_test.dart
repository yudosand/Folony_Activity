import 'package:flutter_test/flutter_test.dart';

import 'package:folony_activity/features/face/domain/face_signature_math.dart';

void main() {
  test('average vectors returns normalized template', () {
    final template = FaceSignatureMath.averageVectors([
      [0.2, 0.4, 0.6],
      [0.1, 0.5, 0.4],
    ]);

    expect(template, hasLength(3));
    expect(template.any((value) => value != 0), isTrue);
  });

  test('cosine similarity score is higher for identical vectors', () {
    const vector = [0.1, 0.2, 0.3, 0.4];
    final sameScore = FaceSignatureMath.cosineSimilarityScore(vector, vector);
    final differentScore = FaceSignatureMath.cosineSimilarityScore(
      vector,
      const [-0.1, -0.2, -0.3, -0.4],
    );

    expect(sameScore, greaterThan(differentScore));
    expect(sameScore, greaterThanOrEqualTo(99));
  });
}
