import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app_controller.dart';
import '../../../core/enums/app_role.dart';
import '../../../core/models/announcement.dart';
import '../../../core/models/app_session.dart';
import '../../../core/models/daily_work_update.dart';
import '../../../core/widgets/adaptive_image.dart';
import '../../../core/models/attendance_record.dart';
import '../../../core/models/leave_request_record.dart' as leave_model;
import '../../../core/models/network_entry.dart';
import '../../../core/models/performance_summary.dart';
import '../../../core/models/wfa_request_record.dart' as wfa_model;
import '../../../core/network/human_readable_error.dart';
import '../../fgg/presentation/fgg_shipping_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.session,
    required this.controller,
    this.onRefresh,
    this.onOpenAttendance,
    this.onOpenWfa,
    this.onOpenLeave,
    this.onOpenNetwork,
    this.homeMenus = const [],
  });

  final AppSession session;
  final AppController controller;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onOpenAttendance;
  final VoidCallback? onOpenWfa;
  final VoidCallback? onOpenLeave;
  final VoidCallback? onOpenNetwork;
  final List<HomeMenuShortcut> homeMenus;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _imagePicker = ImagePicker();
  final _workController = TextEditingController();
  bool _isUploadingPhoto = false;
  File? _workPhoto;
  bool _isWorkActive = false;
  DateTime? _workStartedAt;
  final List<DailyWorkUpdate> _workUpdates = [];
  bool _isSavingWork = false;
  bool _isLoadingWork = true;
  String? _workLoadError;
  String? _pendingWorkId;

  @override
  void initState() {
    super.initState();
    unawaited(_loadWork());
  }

  Future<void> _loadWork() async {
    if ((widget.controller.session ?? widget.session).role == AppRole.fgg) {
      if (mounted) setState(() => _isLoadingWork = false);
      return;
    }
    try {
      final updates = await widget.controller.dailyWorkRepository
          .load(widget.session.userId);
      if (!mounted) return;
      setState(() {
        _workUpdates
          ..clear()
          ..addAll(updates);
        _isWorkActive = updates.isNotEmpty && !updates.first.isFinished;
        _workStartedAt = _isWorkActive ? updates.first.startedAt : null;
        _workLoadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _workLoadError =
          humanReadableError(error, action: 'memuat aktifitas karyawan'));
    } finally {
      if (mounted) setState(() => _isLoadingWork = false);
    }
  }

  @override
  void dispose() {
    _workController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final session = widget.controller.session ?? widget.session;
        final attendance = widget.controller.attendanceRecordsForSession(
          session,
        );
        final leaves = widget.controller.leaveRequestsForSession(
          session,
        );
        final wfas = widget.controller.wfaRequestsForSession(session);
        final ownNetworkEntries =
            widget.controller.ownNetworkEntriesForSession(session);
        final performanceSummary =
            widget.controller.performanceSummaryForSession(session);
        final announcements = widget.controller.announcements;
        final usesNetworkSummary = session.role == AppRole.fgg;

        return RefreshIndicator(
          onRefresh: () async {
            await _loadWork();
            await widget.onRefresh?.call();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _HeroCard(
                session: session,
                isUploading: _isUploadingPhoto,
                onOpenPhotoOptions: () => _showPhotoOptions(session),
              ),
              const SizedBox(height: 18),
              if (session.role == AppRole.fgg &&
                  widget.controller.fggRepository != null) ...[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: const Text('FGG Pengiriman'),
                    subtitle:
                        const Text('Hubungkan akun HUB dan kelola pengiriman'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => FggShippingPage(
                        repository: widget.controller.fggRepository!,
                      ),
                    )),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (session.role != AppRole.fgg) ...[
                _TodayWorkCard(
                  isBusy: _isSavingWork || _isLoadingWork,
                  controller: _workController,
                  selectedPhoto: _workPhoto,
                  isActive: _isWorkActive,
                  startedAt: _workStartedAt,
                  updates: _workUpdates,
                  onCapturePhoto: _captureWorkPhoto,
                  onClearPhoto: _clearWorkPhoto,
                  onSaveUpdate: _saveWorkUpdate,
                  onFinishWork: _finishWork,
                ),
                if (_workLoadError != null)
                  ListTile(
                    title: Text(_workLoadError!),
                    trailing: TextButton(
                        onPressed: _loadWork, child: const Text('Coba lagi')),
                  ),
                const SizedBox(height: 18),
              ],
              Text(
                usesNetworkSummary
                    ? 'Ringkasan Jaringan'
                    : 'Ringkasan Hari Ini',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              if (usesNetworkSummary)
                _FggSummaryGrid(
                  entries: ownNetworkEntries,
                  performanceSummary: performanceSummary,
                  onOpenNetwork: widget.onOpenNetwork,
                )
              else
                _TodaySummaryGrid(
                  attendance: attendance,
                  leaveBalanceLabel: _formatBalanceDays(
                    widget.controller.leaveBalanceDaysForSession(session),
                  ),
                  latestLeave: _latestLeave(leaves),
                  latestWfa: _latestWfa(wfas),
                  onOpenAttendance: widget.onOpenAttendance,
                  onOpenWfa: widget.onOpenWfa,
                  onOpenLeave: widget.onOpenLeave,
                ),
              if (widget.homeMenus.isNotEmpty) ...[
                const SizedBox(height: 22),
                Text('Menu Utama', style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                _ShortcutCard(items: widget.homeMenus),
              ],
              const SizedBox(height: 22),
              Text('Announcement', style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              _AnnouncementCard(announcements: announcements),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
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
    if (!mounted) {
      return;
    }

    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 72,
      maxWidth: 960,
    );
    if (image == null || !mounted) {
      return;
    }

    setState(() => _isUploadingPhoto = true);
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
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _deleteProfilePhoto(AppSession session) async {
    setState(() => _isUploadingPhoto = true);
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
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _captureWorkPhoto() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 72,
      maxWidth: 1280,
    );
    if (image == null || !mounted) {
      return;
    }

    setState(() => _workPhoto = File(image.path));
  }

  void _clearWorkPhoto() {
    setState(() => _workPhoto = null);
  }

  Future<void> _saveWorkUpdate() async {
    final note = _workController.text.trim();
    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Isi dulu pekerjaan yang akan dilakukan.')),
      );
      return;
    }

    await _persistWork(note: note, isFinished: false);
  }

  Future<void> _finishWork() async {
    if (!_isWorkActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada pekerjaan aktif hari ini.')),
      );
      return;
    }

    await _persistWork(
      note: _workController.text.trim().isEmpty
          ? 'Pekerjaan selesai.'
          : _workController.text.trim(),
      isFinished: true,
    );
  }

  Future<void> _persistWork(
      {required String note, required bool isFinished}) async {
    if (_isSavingWork || _isLoadingWork) return;
    setState(() => _isSavingWork = true);
    _pendingWorkId ??=
        '${widget.session.userId}-${DateTime.now().microsecondsSinceEpoch}';
    try {
      String? photoUrl;
      if (_workPhoto != null) {
        photoUrl = widget.controller.isRemoteAuthEnabled
            ? (await widget.controller.uploadAttachment(
                    filePath: _workPhoto!.path,
                    label: 'Foto aktifitas karyawan'))
                .url
            : _workPhoto!.path;
      }
      final saved = await widget.controller.dailyWorkRepository.save(
        userId: widget.session.userId,
        requestId: _pendingWorkId!,
        note: note,
        photoUrl: photoUrl,
        isFinished: isFinished,
      );
      if (!mounted) return;
      setState(() {
        _workUpdates.insert(0, saved);
        _isWorkActive = !saved.isFinished;
        _workStartedAt = _isWorkActive ? saved.startedAt : null;
        _workController.clear();
        _workPhoto = null;
        _pendingWorkId = null;
        _workLoadError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
        saved.isFinished
            ? 'Pekerjaan hari ini selesai.'
            : 'Update pekerjaan hari ini tersimpan.',
      )));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
        humanReadableError(error, action: 'menyimpan aktifitas karyawan'),
      )));
    } finally {
      if (mounted) setState(() => _isSavingWork = false);
    }
  }

  leave_model.LeaveRequestRecord? _latestLeave(
    List<leave_model.LeaveRequestRecord> records,
  ) {
    if (records.isEmpty) {
      return null;
    }
    final sorted = [...records]
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return sorted.first;
  }

  wfa_model.WfaRequestRecord? _latestWfa(
    List<wfa_model.WfaRequestRecord> records,
  ) {
    if (records.isEmpty) {
      return null;
    }
    final sorted = [...records]
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return sorted.first;
  }

  String _formatBalanceDays(double value) {
    final rounded = value.roundToDouble();
    if (rounded == value) {
      return '${value.toInt()} hari';
    }

    return '${value.toStringAsFixed(1)} hari';
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.session,
    required this.isUploading,
    required this.onOpenPhotoOptions,
  });

  final AppSession session;
  final bool isUploading;
  final VoidCallback onOpenPhotoOptions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = [
      if (session.role.label.trim().isNotEmpty) session.role.label,
      if ((session.jobTitle ?? '').trim().isNotEmpty) session.jobTitle!.trim(),
    ].join(' - ');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF5ED), Color(0xFFFFF6E8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFD9E7D8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileAvatar(
            session: session,
            isUploading: isUploading,
            onTap: onOpenPhotoOptions,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, ${session.userName} 👋',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  title.isEmpty ? session.role.label : title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Area Kerja: ${session.territoryLabel ?? session.areaName}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.session,
    required this.isUploading,
    required this.onTap,
  });

  final AppSession session;
  final bool isUploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF17493D),
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: isUploading ? null : onTap,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 68,
              height: 68,
              color: const Color(0xFFA3F0DA),
              child: child,
            ),
          ),
          if (isUploading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66FFFFFF),
                child: Center(
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            )
          else
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.edit_rounded, size: 14),
              ),
            ),
        ],
      ),
    );
  }
}

class _TodayWorkCard extends StatelessWidget {
  const _TodayWorkCard({
    required this.isBusy,
    required this.controller,
    required this.selectedPhoto,
    required this.isActive,
    required this.startedAt,
    required this.updates,
    required this.onCapturePhoto,
    required this.onClearPhoto,
    required this.onSaveUpdate,
    required this.onFinishWork,
  });

  final TextEditingController controller;
  final File? selectedPhoto;
  final bool isActive;
  final DateTime? startedAt;
  final List<DailyWorkUpdate> updates;
  final bool isBusy;
  final VoidCallback onCapturePhoto;
  final VoidCallback onClearPhoto;
  final VoidCallback onSaveUpdate;
  final VoidCallback onFinishWork;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ingin mengerjakan apa hari ini?',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFE6F4EF)
                      : const Color(0xFFF6F2EA),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isActive ? 'Aktif' : 'Belum mulai',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isActive
                        ? const Color(0xFF00796B)
                        : const Color(0xFF7A6A58),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            startedAt == null
                ? 'Tulis rencana atau update pekerjaan. Bisa diupdate beberapa kali sampai pekerjaan selesai.'
                : 'Mulai ${_formatTime(startedAt!)}. Tambahkan update jika ada perkembangan.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5D6B66),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            enabled: !isBusy,
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              labelText: isActive ? 'Update pekerjaan' : 'Pekerjaan hari ini',
              hintText: 'Contoh: Follow up UKM Pasar Minggu',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          if (selectedPhoto != null) ...[
            const SizedBox(height: 12),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(
                    selectedPhoto!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filledTonal(
                    onPressed: onClearPhoto,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Hapus foto',
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: isBusy ? null : onCapturePhoto,
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('Foto kamera'),
              ),
              FilledButton.icon(
                onPressed: isBusy ? null : onSaveUpdate,
                icon: const Icon(Icons.check_rounded),
                label: Text(isBusy
                    ? 'Memproses...'
                    : isActive
                        ? 'Simpan update'
                        : 'Mulai kerja'),
              ),
              if (isActive)
                TextButton.icon(
                  onPressed: isBusy ? null : onFinishWork,
                  icon: const Icon(Icons.flag_rounded),
                  label: const Text('Pekerjaan selesai'),
                ),
            ],
          ),
          if (updates.isNotEmpty) ...[
            const SizedBox(height: 16),
            ExpansionTile(
              initiallyExpanded: false,
              tilePadding: EdgeInsets.zero,
              title: Text('Riwayat update', style: theme.textTheme.titleSmall),
              subtitle: Text('${updates.length} update'),
              children: [
                for (final update in updates) ...[
                  _WorkUpdateTile(update: update),
                  const SizedBox(height: 8),
                ]
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkUpdateTile extends StatelessWidget {
  const _WorkUpdateTile({required this.update});

  final DailyWorkUpdate update;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: update.isFinished
            ? const Color(0xFFEFF7F3)
            : const Color(0xFFF7F7F4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            update.isFinished
                ? Icons.task_alt_rounded
                : Icons.work_history_rounded,
            color: const Color(0xFF00796B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(update.note, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 4),
                Text(
                  _formatTime(update.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                ),
                if (update.photoPath != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AdaptiveImage(
                      path: update.photoPath!,
                      height: 72,
                      width: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Kept only to avoid migration churn while the new daily-work card is active.
// ignore: unused_element
class _LegacyDailyPickerCard extends StatelessWidget {
  const _LegacyDailyPickerCard({
    required this.selectedEmoji,
    required this.animationSeed,
    required this.onSelected,
  });

  final String? selectedEmoji;
  final int animationSeed;
  final ValueChanged<String> onSelected;

  static const _moods = [
    ('😄', 'Happy'),
    ('🙂', 'Baik'),
    ('😐', 'Biasa'),
    ('😓', 'Lelah'),
    ('💪', 'Semangat'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Aktivitas Hari Ini',
                    style: theme.textTheme.titleMedium),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Text(
                  selectedEmoji ?? '✨',
                  key: ValueKey('$selectedEmoji-$animationSeed'),
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mood in _moods)
                ChoiceChip(
                  label: Text('${mood.$1} ${mood.$2}'),
                  selected: selectedEmoji == mood.$1,
                  onSelected: (_) => onSelected(mood.$1),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodaySummaryGrid extends StatelessWidget {
  const _TodaySummaryGrid({
    required this.attendance,
    required this.leaveBalanceLabel,
    required this.latestLeave,
    required this.latestWfa,
    this.onOpenAttendance,
    this.onOpenWfa,
    this.onOpenLeave,
  });

  final List<AttendanceRecord> attendance;
  final String leaveBalanceLabel;
  final leave_model.LeaveRequestRecord? latestLeave;
  final wfa_model.WfaRequestRecord? latestWfa;
  final VoidCallback? onOpenAttendance;
  final VoidCallback? onOpenWfa;
  final VoidCallback? onOpenLeave;

  @override
  Widget build(BuildContext context) {
    final todayAttendance = attendance
        .where((record) => _isSameDate(record.workDate, DateTime.now()))
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final checkIn = _firstOrNull(todayAttendance.where((record) =>
        record.action == AttendanceAction.checkIn ||
        record.action == AttendanceAction.outsideOfficeStart));
    final checkOut = _firstOrNull(todayAttendance.where((record) =>
        record.action == AttendanceAction.checkOut ||
        record.action == AttendanceAction.outsideOfficeFinish));

    return Column(
      children: [
        _SummaryTile(
          icon: Icons.fingerprint_rounded,
          title: 'Absensi',
          value: checkIn == null
              ? 'Belum check-in'
              : checkOut == null
                  ? 'Sudah check-in'
                  : 'Check-out selesai',
          subtitle: checkOut != null
              ? 'Keluar ${_formatTime(checkOut.recordedAt)}'
              : checkIn != null
                  ? 'Masuk ${_formatTime(checkIn.recordedAt)}'
                  : 'Lakukan absen sesuai area kerja.',
          onTap: onOpenAttendance,
        ),
        const SizedBox(height: 10),
        _SummaryTile(
          icon: Icons.beach_access_rounded,
          title: 'Saldo Cuti',
          value: leaveBalanceLabel,
          subtitle: 'Sisa cuti aktif berdasarkan data HR.',
          onTap: onOpenLeave,
        ),
        const SizedBox(height: 10),
        _SummaryTile(
          icon: Icons.event_note_rounded,
          title: 'Pengajuan Terbaru',
          value: _latestRequestTitle(latestLeave, latestWfa),
          subtitle: _latestRequestSubtitle(latestLeave, latestWfa),
          onTap: _latestRequestOpener(latestLeave, latestWfa),
        ),
      ],
    );
  }

  VoidCallback? _latestRequestOpener(
    leave_model.LeaveRequestRecord? leave,
    wfa_model.WfaRequestRecord? wfa,
  ) {
    if (leave == null && wfa == null) {
      return null;
    }
    if (wfa == null ||
        (leave != null && leave.submittedAt.isAfter(wfa.submittedAt))) {
      return onOpenLeave;
    }
    return onOpenWfa;
  }

  String _latestRequestTitle(
    leave_model.LeaveRequestRecord? leave,
    wfa_model.WfaRequestRecord? wfa,
  ) {
    if (leave == null && wfa == null) {
      return 'Belum ada pengajuan';
    }
    if (wfa == null ||
        (leave != null && leave.submittedAt.isAfter(wfa.submittedAt))) {
      return 'Cuti/Izin ${leave!.status.name}';
    }
    return 'WFA ${wfa.status.name}';
  }

  String _latestRequestSubtitle(
    leave_model.LeaveRequestRecord? leave,
    wfa_model.WfaRequestRecord? wfa,
  ) {
    if (leave == null && wfa == null) {
      return 'Pengajuan WFA atau cuti terbaru akan tampil di sini.';
    }
    if (wfa == null ||
        (leave != null && leave.submittedAt.isAfter(wfa.submittedAt))) {
      return '${leave!.reason} • ${_formatDate(leave.submittedAt)}';
    }
    return '${wfa.reason} • ${_formatDate(wfa.submittedAt)}';
  }
}

class _FggSummaryGrid extends StatelessWidget {
  const _FggSummaryGrid({
    required this.entries,
    required this.performanceSummary,
    this.onOpenNetwork,
  });

  final List<NetworkEntry> entries;
  final PerformanceSummary? performanceSummary;
  final VoidCallback? onOpenNetwork;

  @override
  Widget build(BuildContext context) {
    final ukmEntries = entries
        .where((entry) => entry.type == NetworkEntryType.ukm)
        .toList(growable: false);
    final todayFollowUps = entries
        .expand((entry) => entry.followUps)
        .where((followUp) => _isSameDate(followUp.createdAt, DateTime.now()))
        .length;
    final latestEntry = _latestEntry(entries);
    final targetMetric = _primaryTargetMetric(performanceSummary);

    return Column(
      children: [
        _SummaryTile(
          icon: Icons.storefront_rounded,
          title: 'UKM Saya',
          value: '${ukmEntries.length} UKM',
          subtitle: latestEntry == null
              ? 'Data UKM yang kamu buat akan tampil di sini.'
              : 'Terbaru: ${latestEntry.name}',
          onTap: onOpenNetwork,
        ),
        const SizedBox(height: 10),
        _SummaryTile(
          icon: Icons.history_edu_rounded,
          title: 'Follow-up Hari Ini',
          value: '$todayFollowUps update',
          subtitle: todayFollowUps == 0
              ? 'Belum ada follow-up yang dicatat hari ini.'
              : 'Update kunjungan hari ini sudah tercatat.',
          onTap: onOpenNetwork,
        ),
        const SizedBox(height: 10),
        _SummaryTile(
          icon: Icons.flag_rounded,
          title: 'Target Bulan Ini',
          value: targetMetric?.displayValue ?? 'Belum diset',
          subtitle: targetMetric == null
              ? 'Target FGG akan tampil setelah HR menetapkan target.'
              : '${targetMetric.label} • sisa ${targetMetric.remainingValue} ${targetMetric.unit}',
          onTap: onOpenNetwork,
        ),
      ],
    );
  }

  NetworkEntry? _latestEntry(List<NetworkEntry> values) {
    if (values.isEmpty) {
      return null;
    }

    final sorted = [...values]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.first;
  }

  PerformanceMetricProgress? _primaryTargetMetric(
    PerformanceSummary? summary,
  ) {
    if (summary == null || summary.metrics.isEmpty) {
      return null;
    }

    for (final metric in summary.metrics) {
      if (metric.targetValue > 0) {
        return metric;
      }
    }

    return summary.metrics.first;
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE7E5E4)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 3),
                  Text(value, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({required this.items});

  final List<HomeMenuShortcut> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _HomeMenuTile(item: items[i]),
            if (i != items.length - 1) const Divider(height: 22),
          ],
        ],
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.announcements});

  final List<Announcement> announcements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (announcements.isEmpty) {
      return _SummaryTile(
        icon: Icons.campaign_rounded,
        title: 'Announcement HR',
        value: 'Belum ada pengumuman',
        subtitle: 'Informasi dari HR akan muncul di sini.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < announcements.length; i++) ...[
            Text(announcements[i].title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              announcements[i].body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (announcements[i].publishedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                _formatDate(announcements[i].publishedAt!),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (i != announcements.length - 1) const Divider(height: 24),
          ],
        ],
      ),
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
            Icon(item.icon, size: 20, color: theme.colorScheme.primary),
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

bool _isSameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${_formatTime(local)}';
}

T? _firstOrNull<T>(Iterable<T> values) {
  final iterator = values.iterator;
  return iterator.moveNext() ? iterator.current : null;
}
