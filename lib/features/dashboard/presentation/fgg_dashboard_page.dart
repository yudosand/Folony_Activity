import 'package:flutter/material.dart';

import '../../../core/enums/app_role.dart';
import '../../../core/models/app_session.dart';
import '../../../core/widgets/status_badge.dart';

class FieldDashboardPage extends StatelessWidget {
  const FieldDashboardPage({
    super.key,
    required this.session,
  });

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAreaManager = session.role == AppRole.areaManager;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isAreaManager ? 'Performa Area Hari Ini' : 'Performa UKM Hari Ini',
                style: theme.textTheme.titleMedium,
              ),
            ),
            StatusBadge(
              label: isAreaManager ? 'Area On Track' : 'FGG Aktif',
              color: Colors.green,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          isAreaManager
              ? 'Ringkasan target area, kunjungan, dan UKM yang sedang dipantau.'
              : 'Ringkasan target UKM, kunjungan, dan follow-up yang sedang berjalan.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _MetricLine(
          label: isAreaManager ? 'Target area' : 'Target kunjungan',
          value: isAreaManager ? '12' : '8',
          note: isAreaManager ? 'UKM dan mitra hari ini' : 'UKM yang perlu dikunjungi',
        ),
        const Divider(height: 24),
        _MetricLine(
          label: isAreaManager ? 'Tercapai' : 'Progress',
          value: isAreaManager ? '7' : '5',
          note: isAreaManager ? '58% target area' : '5 UKM sudah difollow-up',
        ),
        const Divider(height: 24),
        _MetricLine(
          label: isAreaManager ? 'Tim aktif' : 'UKM saya',
          value: isAreaManager ? '4 FGG' : '9',
          note: isAreaManager
              ? 'FGG yang mengirim data hari ini'
              : 'UKM aktif milik FGG ini',
        ),
        const Divider(height: 24),
        _MetricLine(
          label: 'Data baru',
          value: isAreaManager ? '5' : '3',
          note: isAreaManager ? 'UKM dan mitra baru' : 'UKM baru masuk minggu ini',
        ),
        const SizedBox(height: 20),
        Text('Progress Utama', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _ProgressRow(
          label: isAreaManager ? 'Follow-up UKM tim' : 'Follow-up UKM saya',
          value: isAreaManager ? 0.68 : 0.58,
        ),
        const Divider(height: 24),
        _ProgressRow(
          label: isAreaManager ? 'Data mitra lengkap' : 'Data UKM lengkap',
          value: isAreaManager ? 0.52 : 0.63,
        ),
        const Divider(height: 24),
        _ProgressRow(
          label: 'Titik koordinat valid',
          value: isAreaManager ? 0.76 : 0.71,
        ),
        const SizedBox(height: 20),
        Text('Aktivitas Terbaru', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        if (isAreaManager) ...const [
          _FeedItem(
            title: 'UKM baru dari Bima FGG',
            subtitle: 'Data masuk ke monitoring Area Manager dan siap ditinjau.',
          ),
          Divider(height: 24),
          _FeedItem(
            title: 'Mitra Hub diperbarui',
            subtitle: 'Dokumen survey lokasi dinyatakan lengkap.',
          ),
          Divider(height: 24),
          _FeedItem(
            title: 'Heat map area diperiksa',
            subtitle: 'Rute kunjungan ulang area disesuaikan untuk besok.',
          ),
        ] else ...const [
          _FeedItem(
            title: 'Tambah data UKM baru',
            subtitle: 'Data UKM masuk ke daftar UKM saya.',
          ),
          Divider(height: 24),
          _FeedItem(
            title: 'Kunjungan follow-up dicatat',
            subtitle: 'Catatan kunjungan tersimpan di detail UKM.',
          ),
          Divider(height: 24),
          _FeedItem(
            title: 'Area Manager melihat data UKM',
            subtitle: 'Data UKM otomatis ikut terbaca di monitoring area.',
          ),
        ],
      ],
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(value, style: theme.textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(
                note,
                style: theme.textTheme.bodySmall?.copyWith(
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

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final percentage = (value * 100).round();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Text(
              '$percentage%',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: value, minHeight: 10),
      ],
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
        const Icon(Icons.place_outlined, size: 18),
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
