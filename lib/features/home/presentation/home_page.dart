import 'package:flutter/material.dart';

import '../../../core/models/app_session.dart';
import '../../../core/widgets/status_badge.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.session,
    this.onRefresh,
    this.homeMenus = const [],
  });

  final AppSession session;
  final Future<void> Function()? onRefresh;
  final List<HomeMenuShortcut> homeMenus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          _SummaryHeader(session: session),
          const SizedBox(height: 16),
          Text('Ringkasan', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          const _MetricRow(
            label: 'Status hari ini',
            value: 'Aktif',
            note: 'Jam kerja standar 08:30 - 17:00',
          ),
          const Divider(height: 24),
          const _MetricRow(
            label: 'Agenda utama',
            value: '3',
            note: 'Prioritas sebelum jam 15:00',
          ),
          const Divider(height: 24),
          const _MetricRow(
            label: 'Reminder',
            value: '2',
            note: 'Butuh tindak lanjut',
          ),
          if (homeMenus.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Menu Utama', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            for (var i = 0; i < homeMenus.length; i++) ...[
              _HomeMenuTile(item: homeMenus[i]),
              if (i != homeMenus.length - 1) const Divider(height: 24),
            ],
          ],
        ],
      ),
    );
  }
}

class HomeMenuShortcut {
  const HomeMenuShortcut({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Halo, ${session.userName}', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Area kerja: ${session.areaName}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        const StatusBadge(
          label: 'Role aktif',
          color: Colors.green,
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
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

class _HomeMenuTile extends StatelessWidget {
  const _HomeMenuTile({
    required this.item,
  });

  final HomeMenuShortcut item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(item.icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
