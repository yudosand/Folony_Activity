import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../core/enums/app_role.dart';
import '../../../core/models/app_session.dart';
import '../../../core/models/performance_summary.dart';
import '../../../core/widgets/status_badge.dart';

class FieldDashboardPage extends StatefulWidget {
  const FieldDashboardPage({
    super.key,
    required this.session,
    required this.controller,
  });

  final AppSession session;
  final AppController controller;

  @override
  State<FieldDashboardPage> createState() => _FieldDashboardPageState();
}

class _FieldDashboardPageState extends State<FieldDashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.controller.refreshPerformanceSummaryForSession(widget.session));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAreaManager = widget.session.role == AppRole.areaManager;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final summary = widget.controller.performanceSummaryForSession(widget.session);
        final metrics = summary?.metrics ?? const <PerformanceMetricProgress>[];
        final hasTargets = summary?.hasTargets ?? false;

        return RefreshIndicator(
          onRefresh: () => widget.controller.refreshPerformanceSummaryForSession(widget.session),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isAreaManager ? 'Target Area Bulan Ini' : 'Target FGG Bulan Ini',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  StatusBadge(
                    label: hasTargets ? 'Target Aktif' : 'Belum Diset',
                    color: hasTargets ? Colors.green : Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isAreaManager
                    ? 'Progress target area dihitung otomatis dari UKM baru, mitra baru, dan follow-up tim FGG di wilayah kerja Anda.'
                    : 'Progress target FGG dihitung otomatis dari UKM baru dan follow-up yang Anda simpan pada bulan aktif.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        summary == null
                            ? 'Memuat realisasi bulan berjalan...'
                            : 'Realisasi bulan berjalan: ${summary.periodLabel}',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (metrics.isEmpty)
                const _EmptyTargetState()
              else ...[
                for (final metric in metrics) ...[
                  _MetricCard(metric: metric),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 8),
                Text('Catatan', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                if (isAreaManager) ...const [
                  _FeedItem(
                    title: 'UKM Baru Tim',
                    subtitle: 'Menggabungkan UKM baru dari semua FGG di wilayah Anda dan UKM baru yang Anda buat sendiri.',
                  ),
                  Divider(height: 24),
                  _FeedItem(
                    title: 'Mitra Baru',
                    subtitle: 'Hanya menghitung mitra baru yang Anda tambahkan sendiri pada bulan aktif.',
                  ),
                  Divider(height: 24),
                  _FeedItem(
                    title: 'Kunjungan Tim',
                    subtitle: 'Setiap follow-up baru dari FGG di wilayah Anda dihitung 1 kunjungan, tanpa membedakan status draft, follow-up, atau lengkap.',
                  ),
                ] else ...const [
                  _FeedItem(
                    title: 'UKM Baru',
                    subtitle: 'Hanya UKM yang benar-benar dibuat pada bulan aktif yang masuk progres target.',
                  ),
                  Divider(height: 24),
                  _FeedItem(
                    title: 'Kunjungan',
                    subtitle: 'Setiap follow-up baru yang Anda simpan dihitung 1 kunjungan, untuk UKM maupun mitra, di semua status.',
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.metric,
  });

  final PerformanceMetricProgress metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = metric.targetValue > 0
        ? (metric.progressRatio * 100).round()
        : 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(metric.label, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      metric.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                metric.displayValue,
                style: theme.textTheme.headlineSmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: metric.targetValue > 0 ? metric.progressRatio.clamp(0, 1) : 0,
            minHeight: 12,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _MiniInfo(
                label: 'Tercapai',
                value: '${metric.actualValue} ${metric.unit}',
              ),
              _MiniInfo(
                label: 'Sisa',
                value: '${metric.remainingValue} ${metric.unit}',
              ),
              _MiniInfo(
                label: 'Progress',
                value: '$percent%',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _EmptyTargetState extends StatelessWidget {
  const _EmptyTargetState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Target aktif belum diatur', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Web admin perlu mengisi target aktif UKM baru, mitra baru, atau kunjungan. Setelah diset, target itu akan terus dipakai sampai diubah lagi dan progress bulan berjalan tampil otomatis di sini.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedItem extends StatelessWidget {
  const _FeedItem({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.insights_rounded, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
