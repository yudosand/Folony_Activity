import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../app/app_controller.dart';
import '../../../core/models/app_session.dart';
import '../../../core/models/attendance_record.dart';
import '../../../core/models/remote_attachment.dart';
import '../../../core/services/attendance_policy.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({
    super.key,
    required this.session,
    required this.controller,
  });

  final AppSession session;
  final AppController controller;

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  String? _locationError;
  bool _gpsActive = true;
  bool _isVerifyingFace = false;

  List<AttendanceRecord> get _todayRecords {
    final now = DateTime.now();
    return widget.controller
        .attendanceRecordsForSession(widget.session)
        .where((item) => _isSameDate(item.workDate, now))
        .toList();
  }

  AttendanceDayInsight get _attendanceInsight => AttendancePolicy.evaluate(
        attendanceRecords: widget.controller.attendanceRecordsForSession(
          widget.session,
        ),
        wfaRequests: widget.controller.wfaRequestsForSession(widget.session),
      );

  AttendanceRecord? get _checkInRecord {
    AttendanceRecord? record;
    for (final item in _todayRecords.reversed) {
      if (item.action == AttendanceAction.checkIn &&
          item.status == AttendanceRecordStatus.success) {
        record = item;
      }
    }
    return record;
  }

  AttendanceRecord? get _checkOutRecord {
    for (final item in _todayRecords) {
      if (item.action == AttendanceAction.checkOut &&
          item.status == AttendanceRecordStatus.success) {
        return item;
      }
    }
    return null;
  }

  AttendanceRecord? get _latestRecord {
    if (_todayRecords.isEmpty) {
      return null;
    }
    return _todayRecords.first;
  }

  String? get _latestFaceCapturePath {
    for (final item in _todayRecords) {
      final path = item.verification?.capture?.url;
      if (path != null && path.isNotEmpty) {
        return path;
      }
    }
    return null;
  }

  List<_AttendanceEvent> get _events =>
      _todayRecords.map(_mapEventFromRecord).toList();

  bool get _isCheckedIn => _checkInRecord != null;
  bool get _isFinished => _checkOutRecord != null;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final insight = _attendanceInsight;
        final status = _isFinished
            ? const StatusBadge(label: 'Selesai', color: Colors.green)
            : _isCheckedIn
                ? const StatusBadge(label: 'Aktif', color: Colors.orange)
                : const StatusBadge(label: 'Belum check-in', color: Colors.blue);

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Absensi Face Verification',
                style: theme.textTheme.titleMedium,
              ),
            ),
            status,
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Scan wajah berjalan langsung dari aplikasi. Jam kerja standar adalah ${AttendancePolicy.officeStart} sampai ${AttendancePolicy.officeEnd}, dan lokasi user wajib terekam sebelum absensi disimpan.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE7E5E4)),
          ),
          child: Column(
            children: [
              if (_sessionSummary != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _isFinished
                          ? Icons.task_alt_rounded
                          : Icons.verified_user_rounded,
                      size: 18,
                      color: _isFinished ? Colors.teal : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _sessionSummary!,
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _sessionSubSummary,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
              ],
              _MetricLine(
                label: 'Check-in',
                value: _formatTime(_checkInRecord?.recordedAt),
                note: insight.arrivalNote,
              ),
              const Divider(height: 24),
              _MetricLine(
                label: 'Lokasi',
                value: _locationMetricValue,
                note: _locationMetricNote,
              ),
              const Divider(height: 24),
              _MetricLine(
                label: 'Rule Hari Ini',
                value: insight.summaryLabel,
                note: insight.departureNote,
              ),
              const Divider(height: 24),
              _MetricLine(
                label: 'Verifikasi Wajah',
                value: _latestFaceCapturePath == null ? 'Belum ada' : 'Lolos',
                note: _latestFaceCapturePath == null
                    ? 'Scan wajah dibutuhkan saat aksi absensi'
                    : 'Capture audit sudah siap',
              ),
              const Divider(height: 24),
              _MetricLine(
                label: 'Durasi',
                value: _durationText,
                note: insight.summaryNote,
              ),
            ],
          ),
        ),
        if (insight.contextNotes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.28,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sinkronisasi WFA', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (var i = 0; i < insight.contextNotes.length; i++) ...[
                  _RuleTile(text: insight.contextNotes[i]),
                  if (i != insight.contextNotes.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        _FacePreviewLine(
          faceCapturePath: _latestFaceCapturePath,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isCheckedIn ? null : _toggleGps,
                child: Text(_gpsActive ? 'GPS Aktif' : 'GPS Nonaktif'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _primaryAction,
                child: Text(_primaryActionLabel),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Riwayat Singkat', style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          'Urutan aktivitas terbaru dari verifikasi wajah, pencatatan lokasi, sampai check-in atau check-out.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (_events.isEmpty)
          const EmptyState(
            icon: Icons.history_rounded,
            title: 'Belum ada riwayat',
            message:
                'Aktivitas verifikasi wajah, check-in, dan check-out akan muncul di sini.',
          )
        else
          for (final event in _events) ...[
            _TimelineItem(event: event),
            if (event != _events.last) const SizedBox(height: 14),
          ],
        const SizedBox(height: 20),
        Text('Business Rules', style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          'Aturan mock saat ini untuk menjaga alur absensi wajah tetap konsisten.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        const Column(
          children: [
            _RuleTile(
              text: 'Face check-in hanya aktif jika GPS menyala dan verifikasi wajah lolos.',
            ),
            SizedBox(height: 10),
            _RuleTile(
              text: 'Setelah wajah lolos verifikasi, lokasi user wajib tercatat sebelum check-in atau check-out dieksekusi.',
            ),
            SizedBox(height: 10),
            _RuleTile(
              text:
                  'Jam kerja standar mock adalah masuk ${AttendancePolicy.officeStart} dan pulang ${AttendancePolicy.officeEnd}.',
            ),
            SizedBox(height: 10),
            _RuleTile(
              text: 'Satu user hanya boleh punya satu sesi aktif.',
            ),
            SizedBox(height: 10),
            _RuleTile(
              text: 'Capture wajah dan lokasi menjadi audit mock absensi.',
            ),
          ],
        ),
          ],
        );
      },
    );
  }

  VoidCallback? get _primaryAction {
    if (_isVerifyingFace) {
      return null;
    }
    if (!_isCheckedIn) {
      return _gpsActive ? _startFaceCheckIn : null;
    }
    if (!_isFinished) {
      return _startFaceCheckOut;
    }
    return _reset;
  }

  String get _primaryActionLabel {
    if (_isVerifyingFace) {
      return 'Memproses...';
    }
    if (!_isCheckedIn) {
      return 'Face Check-in';
    }
    if (!_isFinished) {
      return 'Face Check-out';
    }
    return 'Reset Mock';
  }

  String get _durationText {
    final checkInAt = _checkInRecord?.recordedAt;
    final checkOutAt = _checkOutRecord?.recordedAt;
    if (checkInAt == null || checkOutAt == null) {
      return '-';
    }
    final duration = checkOutAt.difference(checkInAt);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}j ${minutes}m';
  }

  String get _locationMetricValue {
    final location = _latestRecord?.location;
    if (location != null) {
      return _locationLabel(location);
    }
    if (!_gpsActive) {
      return 'Nonaktif';
    }
    return 'Belum tercatat';
  }

  String get _locationMetricNote {
    if (_latestRecord?.location != null) {
      return 'Lokasi terakhir tersimpan sebagai audit absensi';
    }
    if (_locationError != null) {
      return _locationError!;
    }
    if (_isVerifyingFace) {
      return 'Lokasi akan direkam otomatis setelah wajah lolos verifikasi';
    }
    return _gpsActive
        ? 'Lokasi akan direkam otomatis saat absensi'
        : 'Aktifkan GPS dulu';
  }

  String? get _sessionSummary {
    if (_isFinished) {
      return 'Check-out berhasil dan sesi kerja hari ini sudah ditutup.';
    }
    if (_isCheckedIn) {
      return 'Check-in berhasil. Sesi kerja aktif dan siap dipantau.';
    }
    return null;
  }

  String get _sessionSubSummary {
    if (_isFinished) {
      return 'Durasi tersimpan $_durationText dengan lokasi audit $_locationMetricValue.';
    }
    if (_attendanceInsight.nextStartRecommendation != null) {
      return 'Lokasi audit terakhir: $_locationMetricValue. Rekomendasi masuk esok hari ${_attendanceInsight.nextStartRecommendation}.';
    }
    return 'Lokasi audit terakhir: $_locationMetricValue.';
  }

  void _toggleGps() {
    setState(() => _gpsActive = !_gpsActive);
  }

  Future<void> _startFaceCheckIn() async {
    final faceCapture = await _runFaceVerification(
      mode: _FaceVerificationMode.checkIn,
    );
    if (faceCapture == null || !mounted) {
      return;
    }
    final location = await _recordCurrentLocation(
      mode: _FaceVerificationMode.checkIn,
    );
    if (location == null || !mounted) {
      return;
    }
    await _checkIn(location, faceCapture);
  }

  Future<void> _startFaceCheckOut() async {
    final faceCapture = await _runFaceVerification(
      mode: _FaceVerificationMode.checkOut,
    );
    if (faceCapture == null || !mounted) {
      return;
    }
    final location = await _recordCurrentLocation(
      mode: _FaceVerificationMode.checkOut,
    );
    if (location == null || !mounted) {
      return;
    }
    await _checkOut(location, faceCapture);
  }

  Future<XFile?> _runFaceVerification({
    required _FaceVerificationMode mode,
  }) async {
    setState(() => _isVerifyingFace = true);

    try {
      final faceCapture = await Navigator.of(context).push<XFile>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => _FaceVerificationPage(
            mode: mode,
          ),
        ),
      );

      if (faceCapture == null) {
        return null;
      }

      setState(() {
        _locationError = null;
      });
      return faceCapture;
    } finally {
      if (mounted) {
        setState(() => _isVerifyingFace = false);
      }
    }
  }

  Future<_AttendanceLocation?> _recordCurrentLocation({
    required _FaceVerificationMode mode,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) {
          return null;
        }
        setState(() {
          _gpsActive = false;
          _locationError = 'Layanan lokasi device sedang nonaktif.';
        });
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) {
          return null;
        }
        setState(() {
          _locationError =
              'Izin lokasi dibutuhkan agar absensi bisa mencatat koordinat user.';
        });
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) {
        return null;
      }

      final location = _AttendanceLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      setState(() {
        _gpsActive = true;
        _locationError = null;
      });

      return location;
    } catch (_) {
      if (!mounted) {
        return null;
      }
      setState(() {
        _locationError =
            'Lokasi belum berhasil didapatkan. Pastikan sinyal GPS stabil.';
      });
      return null;
    }
  }

  Future<void> _checkIn(
    _AttendanceLocation location,
    XFile faceCapture,
  ) async {
    final now = DateTime.now();
    await widget.controller.createAttendanceRecord(
      widget.session,
      AttendanceRecord(
        id: 'attendance-checkin-${widget.session.ownerKey}-${now.microsecondsSinceEpoch}',
        userId: widget.session.ownerKey,
        workDate: DateTime(now.year, now.month, now.day),
        action: AttendanceAction.checkIn,
        status: AttendanceRecordStatus.success,
        recordedAt: now,
        location: AttendanceLocationRecord(
          latitude: location.latitude,
          longitude: location.longitude,
          recordedAt: now,
          addressLabel: location.label,
        ),
        verification: FaceVerificationRecord(
          verifiedAt: now,
          matchScore: 0.98,
          livenessScore: 0.97,
          capture: _captureAttachment(
            faceCapture: faceCapture,
            idPrefix: 'checkin',
          ),
        ),
        note:
            'Absensi masuk otomatis setelah wajah terverifikasi dan lokasi ${location.label} tercatat.',
      ),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Check-in berhasil disimpan')),
    );
  }

  Future<void> _checkOut(
    _AttendanceLocation location,
    XFile faceCapture,
  ) async {
    final now = DateTime.now();
    await widget.controller.createAttendanceRecord(
      widget.session,
      AttendanceRecord(
        id: 'attendance-checkout-${widget.session.ownerKey}-${now.microsecondsSinceEpoch}',
        userId: widget.session.ownerKey,
        workDate: DateTime(now.year, now.month, now.day),
        action: AttendanceAction.checkOut,
        status: AttendanceRecordStatus.success,
        recordedAt: now,
        location: AttendanceLocationRecord(
          latitude: location.latitude,
          longitude: location.longitude,
          recordedAt: now,
          addressLabel: location.label,
        ),
        verification: FaceVerificationRecord(
          verifiedAt: now,
          matchScore: 0.98,
          livenessScore: 0.97,
          capture: _captureAttachment(
            faceCapture: faceCapture,
            idPrefix: 'checkout',
          ),
        ),
        note:
            'Absensi keluar otomatis setelah wajah terverifikasi dan lokasi ${location.label} tercatat.',
      ),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Check-out berhasil disimpan')),
    );
  }

  Future<void> _reset() async {
    await widget.controller.resetAttendanceRecordsForSession(widget.session);
    if (!mounted) {
      return;
    }
    setState(() {
      _locationError = null;
      _gpsActive = true;
      _isVerifyingFace = false;
    });
  }

  RemoteAttachment _captureAttachment({
    required XFile faceCapture,
    required String idPrefix,
  }) {
    return RemoteAttachment(
      id: '$idPrefix-${DateTime.now().microsecondsSinceEpoch}',
      fileName: faceCapture.name,
      mimeType: 'image/jpeg',
      url: faceCapture.path,
    );
  }

  _AttendanceEvent _mapEventFromRecord(AttendanceRecord record) {
    final actionLabel =
        record.action == AttendanceAction.checkIn ? 'Check-in' : 'Check-out';
    final subtitle =
        '${actionLabel.toLowerCase()} tersimpan dengan lokasi ${_locationLabel(record.location)}.';

    return _AttendanceEvent(
      time: _formatTime(record.recordedAt),
      title: '$actionLabel berhasil',
      subtitle: record.note ?? subtitle,
    );
  }

  String _locationLabel(AttendanceLocationRecord location) {
    if (location.addressLabel != null && location.addressLabel!.isNotEmpty) {
      return location.addressLabel!;
    }
    return '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}';
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String _formatTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
        SizedBox(
          width: 108,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: theme.textTheme.titleMedium),
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

class _FacePreviewLine extends StatelessWidget {
  const _FacePreviewLine({
    required this.faceCapturePath,
  });

  final String? faceCapturePath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCapturePath = faceCapturePath;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            'Capture',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: selectedCapturePath == null
              ? Text(
                  'Belum ada capture wajah terbaru.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(selectedCapturePath),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Wajah terakhir terverifikasi',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.event});

  final _AttendanceEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            event.time,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                event.subtitle,
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

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_rounded, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _FaceVerificationPage extends StatefulWidget {
  const _FaceVerificationPage({
    required this.mode,
  });

  final _FaceVerificationMode mode;

  @override
  State<_FaceVerificationPage> createState() => _FaceVerificationPageState();
}

class _FaceVerificationPageState extends State<_FaceVerificationPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  CameraController? _cameraController;
  String? _cameraError;
  bool _isProcessing = false;
  bool _scanQueued = false;
  String _statusText =
      'Menyiapkan kamera depan. Scan wajah akan berjalan otomatis.';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCheckIn = widget.mode == _FaceVerificationMode.checkIn;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCheckIn ? 'Face Check-in' : 'Face Check-out'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          children: [
            Text(
              isCheckIn
                  ? 'Verifikasi wajah untuk check-in otomatis'
                  : 'Verifikasi wajah untuk check-out otomatis',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Expanded(
              flex: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FBF9),
                  ),
                  child: SizedBox.expand(
                    child: _buildCameraFrame(theme),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _statusText,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isProcessing ? null : () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                if (_showRetryButton) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _startScan,
                      child: const Text('Coba Lagi'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _canStartScan {
    final controller = _cameraController;
    return !_isProcessing &&
        _cameraError == null &&
        controller != null &&
        controller.value.isInitialized &&
        !controller.value.isTakingPicture;
  }

  bool get _showRetryButton {
    final controller = _cameraController;
    return !_isProcessing &&
        _cameraError == null &&
        !_scanQueued &&
        controller != null &&
        controller.value.isInitialized;
  }

  Widget _buildCameraFrame(ThemeData theme) {
    if (_cameraError != null) {
      return _buildCameraPlaceholder(
        theme,
        icon: Icons.videocam_off_rounded,
        message: _cameraError!,
      );
    }

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return _buildCameraPlaceholder(
        theme,
        icon: Icons.camera_alt_rounded,
        message: 'Menyiapkan kamera depan untuk face scan...',
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              1.08, 0, 0, 0, 12,
              0, 1.08, 0, 0, 12,
              0, 0, 1.08, 0, 12,
              0, 0, 0, 1, 0,
            ]),
            child: CameraPreview(controller),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFDDE8E2)),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.05),
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.03),
                ],
              ),
            ),
          ),
        ),
        Container(
          width: 190,
          height: 240,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(120),
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 16,
              ),
            ],
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Positioned(
              top: 36 + (170 * _controller.value),
              child: Container(
                width: 170,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const Positioned(
          bottom: 22,
          child: StatusBadge(
            label: 'Kamera Depan Aktif',
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildCameraPlaceholder(
    ThemeData theme, {
    required IconData icon,
    required String message,
  }) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE4F2ED),
            Color(0xFFF6F2EA),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) {
        return;
      }

      if (cameras.isEmpty) {
        setState(() {
          _cameraError = 'Kamera tidak ditemukan di device ini.';
        });
        return;
      }

      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();
      await controller.setFocusMode(FocusMode.auto);
      await controller.setExposureMode(ExposureMode.auto);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _cameraError = null;
        _statusText = 'Arahkan wajah ke frame. Scan otomatis akan dimulai.';
      });
      _queueAutoScan();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cameraError =
            'Kamera tidak bisa diakses. Pastikan izin kamera tersedia.';
      });
    }
  }

  void _queueAutoScan() {
    if (_scanQueued) {
      return;
    }

    _scanQueued = true;
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) {
        return;
      }
      _startScan();
    });
  }

  Future<void> _startScan() async {
    final controller = _cameraController;
    if (!_canStartScan || controller == null || !controller.value.isInitialized) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusText = 'Mendeteksi wajah secara live dari kamera depan...';
    });

    if (!mounted) {
      return;
    }

    try {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final photo = await controller.takePicture();

      if (!mounted) {
        return;
      }

      setState(() {
        _statusText = 'Mencocokkan pola wajah dan validasi liveness mock...';
      });
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      if (!mounted) {
        return;
      }

      Navigator.pop(context, photo);
    } catch (_) {
      setState(() {
        _scanQueued = false;
        _isProcessing = false;
        _statusText =
            'Scan wajah gagal. Pastikan wajah terlihat jelas lalu coba lagi.';
      });
    }
  }
}

enum _FaceVerificationMode {
  checkIn,
  checkOut,
}

class _AttendanceEvent {
  const _AttendanceEvent({
    required this.time,
    required this.title,
    required this.subtitle,
  });

  final String time;
  final String title;
  final String subtitle;
}

class _AttendanceLocation {
  const _AttendanceLocation({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  String get label =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}
