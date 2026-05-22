import '../models/app_session.dart';
import '../models/performance_summary.dart';

abstract class PerformanceRepository {
  Future<PerformanceSummary?> currentSummary({
    required AppSession session,
  });
}
