import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app_controller.dart';
import '../../../core/enums/app_role.dart';
import '../../../core/models/app_session.dart';
import '../../../core/models/face_profile.dart';
import '../../../core/network/human_readable_error.dart';
import '../../../core/widgets/status_badge.dart';
import '../../face/presentation/face_scan_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.session,
    required this.controller,
  });

  final AppSession session;
  final AppController controller;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _imagePicker = ImagePicker();
  bool _isUpdatingPhoto = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final session = widget.controller.session ?? widget.session;
        final faceProfile = widget.controller.faceProfileForSession(session);

        return RefreshIndicator(
          onRefresh: () =>
              widget.controller.refreshProfileDataForSession(session),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _ProfileHeader(
                session: session,
                isUpdatingPhoto: _isUpdatingPhoto,
                onTapPhoto: () => _showPhotoOptions(session),
              ),
              const SizedBox(height: 16),
              _AccountDetailCard(
                session: session,
                leaveBalanceLabel: _formatBalanceDays(
                  widget.controller.leaveBalanceDaysForSession(session),
                ),
                joinedAtLabel: _formatDate(session.joinedAt),
              ),
              const SizedBox(height: 20),
              _FaceEnrollmentCard(
                session: session,
                controller: widget.controller,
                profile: faceProfile,
              ),
              const SizedBox(height: 20),
              Text('Pengaturan Berikutnya', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              _ChangePasswordTile(
                controller: widget.controller,
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
          ),
        );
      },
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }

    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    return '$day/$month/$year';
  }

  String _formatBalanceDays(double value) {
    final rounded = value.roundToDouble();
    if (rounded == value) {
      return '${value.toInt()} hari';
    }

    return '${value.toStringAsFixed(1)} hari';
  }

  Future<void> _showPhotoOptions(AppSession session) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: const Text('Pilih dari galeri'),
                  onTap: () => Navigator.pop(context, 'upload'),
                ),
                if (session.profilePhoto != null)
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded),
                    title: const Text('Hapus foto'),
                    textColor: Colors.redAccent,
                    iconColor: Colors.redAccent,
                    onTap: () => Navigator.pop(context, 'delete'),
                  ),
                ListTile(
                  leading: const Icon(Icons.close_rounded),
                  title: const Text('Batal'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == null || !mounted) {
      return;
    }

    if (action == 'delete') {
      await _deleteProfilePhoto(session);
      return;
    }

    await _pickAndUploadPhoto(session);
  }

  Future<void> _pickAndUploadPhoto(AppSession session) async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 72,
      maxWidth: 960,
    );
    if (image == null || !mounted) {
      return;
    }

    setState(() => _isUpdatingPhoto = true);
    try {
      await widget.controller.updateProfilePhotoForSession(
        session,
        filePath: image.path,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto profil berhasil diperbarui.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Upload foto profil gagal: ${humanReadableError(error, action: 'upload foto profil')}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingPhoto = false);
      }
    }
  }

  Future<void> _deleteProfilePhoto(AppSession session) async {
    setState(() => _isUpdatingPhoto = true);
    try {
      await widget.controller.deleteProfilePhotoForSession(session);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto profil berhasil dihapus.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hapus foto profil gagal: ${humanReadableError(error, action: 'hapus foto profil')}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingPhoto = false);
      }
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.session,
    required this.isUpdatingPhoto,
    required this.onTapPhoto,
  });

  final AppSession session;
  final bool isUpdatingPhoto;
  final VoidCallback onTapPhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        _ProfilePhotoAvatar(
          session: session,
          isUpdatingPhoto: isUpdatingPhoto,
          onTap: onTapPhoto,
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
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountDetailCard extends StatelessWidget {
  const _AccountDetailCard({
    required this.session,
    required this.leaveBalanceLabel,
    required this.joinedAtLabel,
  });

  final AppSession session;
  final String leaveBalanceLabel;
  final String joinedAtLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          leading: const Icon(Icons.badge_outlined),
          title: Text('Detail Akun', style: theme.textTheme.titleMedium),
          subtitle: Text(
            '${session.role.label} · ${session.areaName}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          children: [
            _InfoRow(
              label: 'Status User',
              value: session.isActive ? 'Aktif' : 'Nonaktif',
            ),
            const Divider(height: 24),
            _InfoRow(label: 'Role', value: session.role.label),
            const Divider(height: 24),
            _InfoRow(label: 'Jabatan', value: session.jobTitle ?? '-'),
            const Divider(height: 24),
            _InfoRow(label: 'Email', value: session.email ?? '-'),
            const Divider(height: 24),
            _InfoRow(label: 'Nomor HP', value: session.phoneNumber),
            const Divider(height: 24),
            _InfoRow(label: 'Area Kerja', value: session.areaName),
            const Divider(height: 24),
            _InfoRow(label: 'Lokasi Kerja', value: session.workLocation ?? '-'),
            const Divider(height: 24),
            _InfoRow(label: 'Saldo Cuti', value: leaveBalanceLabel),
            const Divider(height: 24),
            _InfoRow(label: 'Tgl Bergabung', value: joinedAtLabel),
            const Divider(height: 24),
            _InfoRow(label: 'Alamat', value: session.address ?? '-'),
            const Divider(height: 24),
            _InfoRow(
              label: 'Kontak Darurat',
              value: session.emergencyContactName ?? '-',
            ),
            const Divider(height: 24),
            _InfoRow(
              label: 'No. Darurat',
              value: session.emergencyContactPhone ?? '-',
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePhotoAvatar extends StatelessWidget {
  const _ProfilePhotoAvatar({
    required this.session,
    required this.isUpdatingPhoto,
    required this.onTap,
  });

  final AppSession session;
  final bool isUpdatingPhoto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl =
        session.profilePhoto?.thumbnailUrl ?? session.profilePhoto?.url;
    final initials = session.userName.trim().isEmpty
        ? '?'
        : session.userName.trim().characters.first.toUpperCase();

    Widget child;
    if (photoUrl != null && photoUrl.startsWith('http')) {
      child = Image.network(photoUrl, fit: BoxFit.cover);
    } else if (photoUrl != null && File(photoUrl).existsSync()) {
      child = Image.file(File(photoUrl), fit: BoxFit.cover);
    } else {
      child = Center(
        child: Text(initials, style: theme.textTheme.titleMedium),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: isUpdatingPhoto ? null : onTap,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
              width: 56,
              height: 56,
              color: theme.colorScheme.primaryContainer,
              child: child,
            ),
          ),
          if (isUpdatingPhoto)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66FFFFFF),
                child: Center(
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            )
          else
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.edit_rounded, size: 13),
              ),
            ),
        ],
      ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: const Icon(Icons.face_retouching_natural_rounded),
            title: Text('Face ID MVP', style: theme.textTheme.titleMedium),
            subtitle: Text(
              profile.isEnrolled
                  ? '${profile.samplesCount} sampel terdaftar'
                  : 'Belum terdaftar',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            children: [
              Row(
                children: [
                  StatusBadge(
                    label: profile.isEnrolled ? 'Terdaftar' : 'Belum terdaftar',
                    color: profile.isEnrolled ? Colors.green : Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 10),
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
        ),
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
        SnackBar(
          content: Text(
            'Enrollment wajah gagal: ${humanReadableError(error, action: 'mendaftarkan wajah')}',
          ),
        ),
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
                          if (value.trim() !=
                              newPasswordController.text.trim()) {
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
        SnackBar(
          content: Text(
            'Ubah password gagal: ${humanReadableError(error, action: 'mengubah password')}',
          ),
        ),
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
