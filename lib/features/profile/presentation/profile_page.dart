import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../core/enums/app_role.dart';
import '../../../core/models/app_session.dart';
import '../../../core/models/face_profile.dart';
import '../../../core/widgets/status_badge.dart';
import '../../face/presentation/face_scan_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.session,
    required this.controller,
  });

  final AppSession session;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final faceProfile = controller.faceProfileForSession(session);

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _ProfileHeader(session: session),
            const SizedBox(height: 16),
            Text('Informasi Akun', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            const _InfoRow(label: 'Status User', value: 'Aktif'),
            const Divider(height: 24),
            _InfoRow(label: 'Role', value: session.role.label),
            const Divider(height: 24),
            _InfoRow(label: 'Nomor HP', value: session.phoneNumber),
            const Divider(height: 24),
            _InfoRow(label: 'Area Kerja', value: session.areaName),
            const SizedBox(height: 20),
            _FaceEnrollmentCard(
              session: session,
              controller: controller,
              profile: faceProfile,
            ),
            const SizedBox(height: 20),
            Text('Pengaturan Berikutnya', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _ChangePasswordTile(
              controller: controller,
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
      },
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
                label: 'Profil aktif',
                color: Colors.teal,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FaceEnrollmentCard extends StatefulWidget {
  const _FaceEnrollmentCard({
    required this.session,
    required this.controller,
    required this.profile,
  });

  final AppSession session;
  final AppController controller;
  final FaceProfile profile;

  @override
  State<_FaceEnrollmentCard> createState() => _FaceEnrollmentCardState();
}

class _FaceEnrollmentCardState extends State<_FaceEnrollmentCard> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = widget.profile;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Face ID MVP', style: theme.textTheme.titleMedium),
              ),
              StatusBadge(
                label: profile.isEnrolled ? 'Terdaftar' : 'Belum terdaftar',
                color: profile.isEnrolled ? Colors.green : Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tahap ini memindai wajah dari beberapa arah, lalu menyimpan hasil capture referensi sebagai fondasi Face ID yang lebih rapi. Pencocokan identitas final akan masuk di tahap berikutnya tanpa mengubah flow user.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(
            label: 'Status',
            value: profile.isEnrolled
                ? 'Aktif (${profile.samplesCount} sampel)'
                : 'Belum aktif',
          ),
          const Divider(height: 24),
          _InfoRow(
            label: 'Terakhir verifikasi',
            value: _formatDateTime(profile.lastVerifiedAt),
          ),
          const Divider(height: 24),
          _InfoRow(
            label: 'Mode',
            value: profile.verificationMode ?? 'mvp_capture_gate',
          ),
          if ((profile.note ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              profile.note!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isProcessing ? null : _startEnrollment,
            icon: const Icon(Icons.face_retouching_natural_rounded),
            label: Text(
              _isProcessing
                  ? 'Memproses...'
                  : profile.isEnrolled
                      ? 'Perbarui Wajah'
                      : 'Daftarkan Wajah',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startEnrollment() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isProcessing = true);

    try {
      final scanResult = await Navigator.of(context).push<FaceScanResult>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => const FaceScanPage.enrollment(),
        ),
      );
      if (scanResult == null || scanResult.samplePaths.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Enrollment dibatalkan sebelum scan wajah selesai.'),
          ),
        );
        return;
      }

      await widget.controller.enrollFaceForSession(
        widget.session,
        samplePaths: scanResult.samplePaths,
      );
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Enrollment wajah MVP berhasil disimpan.'),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Enrollment wajah gagal: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Belum ada';
    }
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
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
      crossAxisAlignment: CrossAxisAlignment.start,
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

class _ChangePasswordTile extends StatefulWidget {
  const _ChangePasswordTile({
    required this.controller,
  });

  final AppController controller;

  @override
  State<_ChangePasswordTile> createState() => _ChangePasswordTileState();
}

class _ChangePasswordTileState extends State<_ChangePasswordTile> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return _SettingTile(
      icon: Icons.lock_outline_rounded,
      title: 'Keamanan akun',
      subtitle: 'Password, session, dan device binding.',
      trailing: FilledButton.tonal(
        onPressed: _isSubmitting ? null : _showChangePasswordDialog,
        child: Text(_isSubmitting ? 'Memproses...' : 'Ubah Password'),
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool showCurrentPassword = false;
    bool showNewPassword = false;
    bool showConfirmPassword = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Ubah Password'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: currentPasswordController,
                        obscureText: !showCurrentPassword,
                        decoration: InputDecoration(
                          labelText: 'Password saat ini',
                          suffixIcon: IconButton(
                            onPressed: () => setDialogState(
                              () => showCurrentPassword = !showCurrentPassword,
                            ),
                            icon: Icon(
                              showCurrentPassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Password saat ini wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: !showNewPassword,
                        decoration: InputDecoration(
                          labelText: 'Password baru',
                          suffixIcon: IconButton(
                            onPressed: () => setDialogState(
                              () => showNewPassword = !showNewPassword,
                            ),
                            icon: Icon(
                              showNewPassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Password baru wajib diisi';
                          }
                          if (value.trim().length < 6) {
                            return 'Password baru minimal 6 karakter';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: !showConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Konfirmasi password baru',
                          suffixIcon: IconButton(
                            onPressed: () => setDialogState(
                              () => showConfirmPassword = !showConfirmPassword,
                            ),
                            icon: Icon(
                              showConfirmPassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Konfirmasi password wajib diisi';
                          }
                          if (value.trim() != newPasswordController.text.trim()) {
                            return 'Konfirmasi password belum sama';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.controller.changePassword(
        currentPassword: currentPasswordController.text.trim(),
        newPassword: newPasswordController.text.trim(),
        newPasswordConfirmation: confirmPasswordController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password berhasil diperbarui.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ubah password gagal: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

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
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}
