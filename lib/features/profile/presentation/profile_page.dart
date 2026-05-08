import 'package:flutter/material.dart';

import '../../../core/enums/app_role.dart';
import '../../../core/models/app_session.dart';
import '../../../core/widgets/status_badge.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.session,
  });

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _ProfileHeader(session: session),
        const SizedBox(height: 16),
        Text('Informasi Akun', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        const _InfoRow(label: 'Status User', value: 'Aktif'),
        const Divider(height: 24),
        const _InfoRow(label: 'Role', value: 'Dinamis sesuai simulasi'),
        const Divider(height: 24),
        const _InfoRow(label: 'Nomor HP', value: '081234567890'),
        const Divider(height: 24),
        const _InfoRow(label: 'Area Kerja', value: 'Terhubung ke profil user'),
        const SizedBox(height: 20),
        Text('Pengaturan Berikutnya', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        const _SettingTile(
          icon: Icons.lock_outline_rounded,
          title: 'Keamanan akun',
          subtitle: 'Password, session, dan device binding.',
        ),
        const Divider(height: 24),
        const _SettingTile(
          icon: Icons.notifications_none_rounded,
          title: 'Notifikasi',
          subtitle: 'Reminder check-out, WFA, dan approval.',
        ),
        const Divider(height: 24),
        const _SettingTile(
          icon: Icons.language_rounded,
          title: 'Preferensi aplikasi',
          subtitle: 'Bahasa, tema, dan kebutuhan operasional.',
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            session.userName.isNotEmpty ? session.userName[0] : '?',
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(session.userName, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                '${session.role.label} - ${session.phoneNumber}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                session.areaName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              const StatusBadge(
                label: 'Simulasi profil aktif',
                color: Colors.teal,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
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
