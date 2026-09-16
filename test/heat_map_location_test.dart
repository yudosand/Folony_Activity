import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:folony_activity/features/heatmap/data/heat_map_location.dart';

void main() {
  test('a failed provider does not hide a valid cached device fix', () async {
    final pendingGps = Completer<HeatMapCoordinate?>();
    final result = await firstHeatMapLocation([
      Future.error(StateError('Fused provider unavailable')),
      pendingGps.future,
      Future.value(const HeatMapCoordinate(latitude: -6.2, longitude: 106.8)),
    ]);
    expect(result.latitude, -6.2);
    pendingGps.complete(null);
  });

  test('GPS failures end with a retryable error', () async {
    await expectLater(firstHeatMapLocation([Future.value(null), Future.error(StateError('GPS'))]),
        throwsA(isA<TimeoutException>()));
  });

  test('stale or inaccurate fixes are not presented as current position', () {
    bool usable(double accuracy, Duration age) => isUsableHeatMapLocation(
        latitude: -6.2, longitude: 106.8, accuracy: accuracy, age: age);
    expect(usable(100, const Duration(seconds: 20)), isTrue);
    expect(usable(100, const Duration(hours: 1)), isFalse);
    expect(usable(5000, Duration.zero), isFalse);
    expect(usable(double.nan, Duration.zero), isFalse);
  });
}
