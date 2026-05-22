import '../../enums/app_role.dart';
import '../../models/app_session.dart';
import '../../models/performance_summary.dart';
import '../performance_repository.dart';

class MockPerformanceRepository implements PerformanceRepository {
  const MockPerformanceRepository();

  @override
  Future<PerformanceSummary?> currentSummary({
    required AppSession session,
  }) async {
    switch (session.role) {
      case AppRole.fgg:
        return const PerformanceSummary(
          periodMonth: '2026-05',
          periodLabel: '05/2026',
          role: AppRole.fgg,
          metrics: [
            PerformanceMetricProgress(
              key: 'fgg_new_ukm',
              label: 'UKM Baru',
              description: 'Jumlah UKM baru yang dibuat FGG pada bulan aktif.',
              unit: 'UKM',
              actualValue: 5,
              targetValue: 50,
              remainingValue: 45,
              progressRatio: 0.1,
              displayValue: '5/50',
            ),
            PerformanceMetricProgress(
              key: 'fgg_follow_up_visit',
              label: 'Kunjungan',
              description: 'Jumlah follow-up baru yang disimpan FGG pada bulan aktif.',
              unit: 'kunjungan',
              actualValue: 12,
              targetValue: 20,
              remainingValue: 8,
              progressRatio: 0.6,
              displayValue: '12/20',
            ),
          ],
        );
      case AppRole.areaManager:
        return const PerformanceSummary(
          periodMonth: '2026-05',
          periodLabel: '05/2026',
          role: AppRole.areaManager,
          metrics: [
            PerformanceMetricProgress(
              key: 'area_manager_team_new_ukm',
              label: 'UKM Baru Tim',
              description: 'Akumulasi UKM baru dari seluruh FGG di wilayah Area Manager ditambah UKM baru buatan Area Manager sendiri.',
              unit: 'UKM',
              actualValue: 15,
              targetValue: 100,
              remainingValue: 85,
              progressRatio: 0.15,
              displayValue: '15/100',
            ),
            PerformanceMetricProgress(
              key: 'area_manager_new_mitra',
              label: 'Mitra Baru',
              description: 'Jumlah mitra baru yang dibuat langsung oleh Area Manager pada bulan aktif.',
              unit: 'mitra',
              actualValue: 10,
              targetValue: 20,
              remainingValue: 10,
              progressRatio: 0.5,
              displayValue: '10/20',
            ),
            PerformanceMetricProgress(
              key: 'area_manager_team_follow_up_visit',
              label: 'Kunjungan Tim',
              description: 'Akumulasi follow-up baru dari seluruh FGG di wilayah Area Manager pada bulan aktif.',
              unit: 'kunjungan',
              actualValue: 50,
              targetValue: 100,
              remainingValue: 50,
              progressRatio: 0.5,
              displayValue: '50/100',
            ),
          ],
        );
      default:
        return null;
    }
  }
}
