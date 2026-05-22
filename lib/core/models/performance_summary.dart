import '../enums/app_role.dart';

class PerformanceMetricProgress {
  const PerformanceMetricProgress({
    required this.key,
    required this.label,
    required this.description,
    required this.unit,
    required this.actualValue,
    required this.targetValue,
    required this.remainingValue,
    required this.progressRatio,
    required this.displayValue,
  });

  final String key;
  final String label;
  final String description;
  final String unit;
  final int actualValue;
  final int targetValue;
  final int remainingValue;
  final double progressRatio;
  final String displayValue;

  factory PerformanceMetricProgress.fromJson(Map<String, dynamic> json) {
    return PerformanceMetricProgress(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      description: json['description'] as String? ?? '',
      unit: json['unit'] as String? ?? 'item',
      actualValue: (json['actual_value'] as num?)?.toInt() ?? 0,
      targetValue: (json['target_value'] as num?)?.toInt() ?? 0,
      remainingValue: (json['remaining_value'] as num?)?.toInt() ?? 0,
      progressRatio: (json['progress_ratio'] as num?)?.toDouble() ?? 0,
      displayValue: json['display_value'] as String? ?? '0/0',
    );
  }
}

class PerformanceSummary {
  const PerformanceSummary({
    required this.periodMonth,
    required this.periodLabel,
    required this.role,
    required this.metrics,
  });

  final String periodMonth;
  final String periodLabel;
  final AppRole role;
  final List<PerformanceMetricProgress> metrics;

  bool get hasTargets => metrics.any((metric) => metric.targetValue > 0);

  factory PerformanceSummary.fromJson(Map<String, dynamic> json) {
    return PerformanceSummary(
      periodMonth: json['period_month'] as String? ?? '',
      periodLabel: json['period_label'] as String? ?? '',
      role: AppRole.values.firstWhere(
        (item) => item.name == json['role'],
        orElse: () => AppRole.fgg,
      ),
      metrics: (json['metrics'] is List)
          ? (json['metrics'] as List)
              .whereType<Map>()
              .map(
                (item) => PerformanceMetricProgress.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const [],
    );
  }
}
