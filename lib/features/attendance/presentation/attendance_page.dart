import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../app/app_controller.dart';
import '../../../core/models/app_session.dart';
import '../../../core/models/attendance_record.dart';
import '../../../core/models/face_verification_result.dart';
import '../../../core/services/attendance_policy.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import 'attendance_feedback.dart';
import '../../face/presentation/face_scan_page.dart';

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
        .where(
          (item) =>
              _isSameDate(item.workDate.toLocal(), now) ||
              _isSameDate(item.recordedAt.toLocal(), now),
        )
        .toList();
  }

  List<AttendanceRecord> get _statusRecords {
    if (_todayRecords.isNotEmpty) {
      return _todayRecords;
    }

    final allRecords = widget.controller.attendanceRecordsForSession(widget.session);
    final now = DateTime.now();
    AttendanceRecord? latestCheckIn;
    for (final item in allRecords) {
      if (item.action == AttendanceAction.checkIn &&
          item.status == AttendanceRecordStatus.success &&
          (_isSameDate(item.workDate.toLocal(), now) ||
              _isSameDate(item.recordedAt.toLocal(), now))) {
        latestCheckIn = item;
        break;
      }
    }

    if (latestCheckIn == null) {
      return const [];
    }

    return allRecords
        .where(
          (item) => !item.recordedAt.isBefore(latestCheckIn!.recordedAt),
        )
        .toList();
  }

  AttendanceDayInsight get _attendanceInsight => AttendancePolicy.evaluate(
        attendanceRecords: widget.controller.attendanceRecordsForSession(
          widget.session,
        ),
        wfaRequests: widget.controller.wfaRequestsForSession(widget.session),
      );

  _AttendanceSessionState get _sessionState =>
      _AttendanceSessionState.fromRecords(_statusRecords);

  AttendanceRecord? get _checkInRecord {
    return _sessionState.displayCheckIn;
  }

  AttendanceRecord? get _checkOutRecord {
    return _sessionState.displayCheckOut;
  }

  AttendanceRecord? get _latestRecord {
    if (_statusRecords.isEmpty) {
      return null;
    }
    return _statusRecords.first;
  }

  String? get _latestFaceCapturePath {
    for (final item in _statusRecords) {
      final path = item.verification?.capture?.url;
      if (path != null && path.isNotEmpty) {
        return path;
      }
    }
    return null;
  }

  List<_AttendanceEvent> get _events =>
      _statusRecords.map(_mapEventFromRecord).toList();

  bool get _isCheckedIn => _sessionState.activeCheckIn != null;
  bool get _isFinished =>
      !_isCheckedIn && _sessionState.latestCompletedCheckOut != null;

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
        if (_isVerifyingFace) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Memverifikasi wajah, mengunggah capture, dan menyimpan absensi...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
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
              text: 'Satu user hanya boleh punya satu sesi aktif dalam satu waktu.',
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
    if (_isCheckedIn) {
      return _startFaceCheckOut;
    }
    return _gpsActive ? _startFaceCheckIn : null;
  }

  String get _primaryActionLabel {
    if (_isVerifyingFace) {
      return 'Memproses...';
    }
    if (_isCheckedIn) {
      return 'Face Check-out';
    }
    return 'Face Check-in';
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
      return 'Check-out berhasil. Anda bisa memulai sesi check-in baru kapan saja.';
    }
    if (_isCheckedIn) {
      return 'Check-in berhasil. Sesi kerja aktif dan siap dipantau.';
    }
    return null;
  }

  String get _sessionSubSummary {
    if (_isFinished) {
      return 'Durasi sesi terakhir tersimpan $_durationText dengan lokasi audit $_locationMetricValue.';
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
    await _handleFaceAttendance(
      mode: _FaceVerificationMode.checkIn,
      action: 'checkIn',
      actionLabel: 'check-in',
      onVerified: _checkIn,
    );
  }

  Future<void> _startFaceCheckOut() async {
    await _handleFaceAttendance(
      mode: _FaceVerificationMode.checkOut,
      action: 'checkOut',
      actionLabel: 'check-out',
      onVerified: _checkOut,
    );
  }

  Future<void> _handleFaceAttendance({
    required _FaceVerificationMode mode,
    required String action,
    required String actionLabel,
    required Future<void> Function(
      _AttendanceLocation location,
      FaceVerificationResult verificationResult,
    )
    onVerified,
  }) async {
    final enrollmentBlock = _faceEnrollmentBlockReason(actionLabel);
    if (enrollmentBlock != null) {
      _showAttendanceSnackBar(enrollmentBlock);
      return;
    }

    setState(() {
      _isVerifyingFace = true;
      _locationError = null;
    });

    try {
      final faceScanResult = await _runFaceVerification(mode: mode);
      if (faceScanResult == null || !mounted) {
        return;
      }

      final primaryCapturePath = faceScanResult.primaryCapturePath;
      if (primaryCapturePath == null || primaryCapturePath.isEmpty) {
        _showAttendanceSnackBar(
          'Capture wajah belum berhasil dibuat. Coba scan sekali lagi.',
        );
        return;
      }

      final verificationResult = await widget.controller.verifyFaceForSession(
        widget.session,
        action: action,
        capturePath: primaryCapturePath,
        livenessScore: faceScanResult.livenessScore,
      );
      if (!mounted) {
        return;
      }

      if (!verificationResult.verified) {
        _showAttendanceSnackBar(
          _verificationRejectedMessage(verificationResult),
        );
        return;
      }

      final location = await _recordCurrentLocation(mode: mode);
      if (location == null || !mounted) {
        return;
      }

      await onVerified(location, verificationResult);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showAttendanceSnackBar(
        describeAttendanceActionError(error, actionLabel: actionLabel),
      );
    } finally {
      if (mounted) {
        setState(() => _isVerifyingFace = false);
      }
    }
  }

  Future<FaceScanResult?> _runFaceVerification({
    required _FaceVerificationMode mode,
  }) async {
    return Navigator.of(context).push<FaceScanResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => FaceScanPage.verification(
          verificationPurpose: mode == _FaceVerificationMode.checkIn
              ? FaceScanVerificationPurpose.checkIn
              : FaceScanVerificationPurpose.checkOut,
        ),
      ),
    );
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
    FaceVerificationResult verificationResult,
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
          decision: verificationResult.decision,
          matchScore: verificationResult.matchScore,
          livenessScore: verificationResult.livenessScore,
          capture: verificationResult.capture,
          note: verificationResult.note,
        ),
        note:
            'Absensi masuk otomatis setelah wajah terverifikasi dan lokasi ${location.label} tercatat.',
      ),
    );
    if (!mounted) {
      return;
    }
    _showAttendanceSnackBar(
      'Check-in berhasil disimpan. ${_verificationSummary(verificationResult)}',
    );
  }

  Future<void> _checkOut(
    _AttendanceLocation location,
    FaceVerificationResult verificationResult,
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
          decision: verificationResult.decision,
          matchScore: verificationResult.matchScore,
          livenessScore: verificationResult.livenessScore,
          capture: verificationResult.capture,
          note: verificationResult.note,
        ),
        note:
            'Absensi keluar otomatis setelah wajah terverifikasi dan lokasi ${location.label} tercatat.',
      ),
    );
    if (!mounted) {
      return;
    }
    _showAttendanceSnackBar(
      'Check-out berhasil disimpan. ${_verificationSummary(verificationResult)}',
    );
  }

  String? _faceEnrollmentBlockReason(String actionLabel) {
    final profile = widget.controller.faceProfileForSession(widget.session);
    if (profile.id.isEmpty) {
      return widget.session.hasFaceEnrollment
          ? null
          : 'Daftarkan wajah dulu dari menu Akun sebelum $actionLabel.';
    }

    return faceEnrollmentBlockReason(
      profile,
      actionLabel: actionLabel,
    );
  }

  String _verificationRejectedMessage(FaceVerificationResult result) {
    final details = <String>[];
    if (result.shouldRetry) {
      details.add('scan ulang disarankan');
    }
    if (result.matchScore != null) {
      details.add('match ${result.matchScore!.toStringAsFixed(1)}');
    }
    if (result.livenessScore != null) {
      details.add('liveness ${result.livenessScore!.toStringAsFixed(1)}');
    }

    final scoreSummary = details.isEmpty ? '' : ' (${details.join(' | ')})';
    return '${result.note ?? 'Verifikasi wajah gagal.'}$scoreSummary';
  }

  String _verificationSummary(FaceVerificationResult result) {
    final details = <String>[];
    details.add(result.decision);
    if (result.matchScore != null) {
      details.add('match ${result.matchScore!.toStringAsFixed(1)}');
    }
    if (result.livenessScore != null) {
      details.add('liveness ${result.livenessScore!.toStringAsFixed(1)}');
    }
    if (details.isEmpty) {
      return 'Verifikasi wajah lolos.';
    }
    return 'Verifikasi wajah lolos dengan ${details.join(' | ')}.';
  }

  void _showAttendanceSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
    final localValue = value.toLocal();
    final hour = localValue.hour.toString().padLeft(2, '0');
    final minute = localValue.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _AttendanceSessionState {
  const _AttendanceSessionState({
    this.activeCheckIn,
    this.latestCompletedCheckIn,
    this.latestCompletedCheckOut,
  });

  final AttendanceRecord? activeCheckIn;
  final AttendanceRecord? latestCompletedCheckIn;
  final AttendanceRecord? latestCompletedCheckOut;

  AttendanceRecord? get displayCheckIn => activeCheckIn ?? latestCompletedCheckIn;
  AttendanceRecord? get displayCheckOut =>
      activeCheckIn == null ? latestCompletedCheckOut : null;

  static _AttendanceSessionState fromRecords(List<AttendanceRecord> records) {
    final sorted = [...records]
      ..sort((left, right) => left.recordedAt.compareTo(right.recordedAt));

    AttendanceRecord? openCheckIn;
    AttendanceRecord? latestCompletedCheckIn;
    AttendanceRecord? latestCompletedCheckOut;

    for (final record in sorted) {
      if (record.status != AttendanceRecordStatus.success) {
        continue;
      }

      if (record.action == AttendanceAction.checkIn) {
        openCheckIn = record;
        continue;
      }

      if (record.action == AttendanceAction.checkOut && openCheckIn != null) {
        latestCompletedCheckIn = openCheckIn;
        latestCompletedCheckOut = record;
        openCheckIn = null;
      }
    }

    return _AttendanceSessionState(
      activeCheckIn: openCheckIn,
      latestCompletedCheckIn: latestCompletedCheckIn,
      latestCompletedCheckOut: latestCompletedCheckOut,
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
    final isRemoteResource = selectedCapturePath != null &&
        (selectedCapturePath.startsWith('http://') ||
            selectedCapturePath.startsWith('https://'));

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
                      child: isRemoteResource
                          ? Image.network(
                              selectedCapturePath,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const _FacePreviewFallback(),
                            )
                          : Image.file(
                              File(selectedCapturePath),
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const _FacePreviewFallback(),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isRemoteResource
                            ? 'Wajah terakhir terverifikasi'
                            : 'Wajah terakhir tersimpan di device',
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

class _FacePreviewFallback extends StatelessWidget {
  const _FacePreviewFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      color: const Color(0xFFF3F4F6),
      alignment: Alignment.center,
      child: const Icon(
        Icons.face_retouching_natural_rounded,
        size: 20,
        color: Color(0xFF6B7280),
      ),
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
