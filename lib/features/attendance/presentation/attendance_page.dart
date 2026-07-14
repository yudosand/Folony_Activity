import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

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
  final ImagePicker _picker = ImagePicker();
  StreamSubscription<Position>? _positionSubscription;
  Position? _livePosition;
  String? _locationError;
  bool _gpsActive = true;
  bool _isVerifyingFace = false;
  bool _isOutsideOfficeSubmitting = false;

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

    final allRecords =
        widget.controller.attendanceRecordsForSession(widget.session);
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
    return _hasActiveOutsideOffice ||
            _sessionState.latestCompletedOutsideOfficeFinish != null
        ? _sessionState.displayOutsideOfficeStart
        : _sessionState.displayCheckIn;
  }

  AttendanceRecord? get _checkOutRecord {
    return _hasActiveOutsideOffice ||
            _sessionState.latestCompletedOutsideOfficeFinish != null
        ? _sessionState.displayOutsideOfficeFinish
        : _sessionState.displayCheckOut;
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

  bool get _isCheckedIn => _sessionState.activeRegularCheckIn != null;
  bool get _hasActiveOutsideOffice =>
      _sessionState.activeOutsideOfficeStart != null;
  bool get _isFinished =>
      !_isCheckedIn &&
      !_hasActiveOutsideOffice &&
      (_sessionState.latestCompletedCheckOut != null ||
          _sessionState.latestCompletedOutsideOfficeFinish != null);

  bool get _hasAttendanceArea =>
      widget.session.officeLatitude != null &&
      widget.session.officeLongitude != null &&
      widget.session.attendanceRadiusMeters != null;

  double? get _liveDistanceMeters {
    final position = _livePosition;
    final officeLatitude = widget.session.officeLatitude;
    final officeLongitude = widget.session.officeLongitude;
    if (position == null || officeLatitude == null || officeLongitude == null) {
      return null;
    }

    return Geolocator.distanceBetween(
      officeLatitude,
      officeLongitude,
      position.latitude,
      position.longitude,
    );
  }

  bool get _isInsideAttendanceRadius {
    final distance = _liveDistanceMeters;
    final radius = widget.session.attendanceRadiusMeters;
    if (distance == null || radius == null) {
      return false;
    }

    return distance <= radius;
  }

  bool get _canUseNormalAttendance =>
      _gpsActive && _hasAttendanceArea && _isInsideAttendanceRadius;

  String get _attendanceAreaName =>
      widget.session.workLocation?.trim().isNotEmpty == true
          ? widget.session.workLocation!.trim()
          : 'Area kerja';

  @override
  void initState() {
    super.initState();
    _startLiveLocationTracking();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final insight = _attendanceInsight;
        final status = _isFinished
            ? const StatusBadge(label: 'Selesai', color: Colors.green)
            : _hasActiveOutsideOffice
                ? const StatusBadge(
                    label: 'Kunjungan Aktif',
                    color: Colors.deepOrange,
                  )
                : _isCheckedIn
                    ? const StatusBadge(label: 'Aktif', color: Colors.orange)
                    : const StatusBadge(
                        label: 'Belum check-in', color: Colors.blue);

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
              'Scan wajah berjalan langsung dari aplikasi. Jam kerja standar adalah ${AttendancePolicy.officeStart} sampai ${AttendancePolicy.officeEnd}. Check-in/check-out normal hanya aktif saat lokasi live berada di radius area kerja.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _LiveLocationRadiusCard(
              areaName: _attendanceAreaName,
              hasAttendanceArea: _hasAttendanceArea,
              gpsActive: _gpsActive,
              isInsideRadius: _isInsideAttendanceRadius,
              currentLatitude: _livePosition?.latitude,
              currentLongitude: _livePosition?.longitude,
              officeLatitude: widget.session.officeLatitude,
              officeLongitude: widget.session.officeLongitude,
              distanceMeters: _liveDistanceMeters,
              radiusMeters: widget.session.attendanceRadiusMeters,
              errorText: _locationError,
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
                          color: _isFinished
                              ? Colors.teal
                              : theme.colorScheme.primary,
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
                    label: _hasActiveOutsideOffice ||
                            _sessionState.latestCompletedOutsideOfficeFinish !=
                                null
                        ? 'Mulai Kunjungan'
                        : 'Check-in',
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
                    value: _hasActiveOutsideOffice ||
                            _sessionState.latestCompletedOutsideOfficeFinish !=
                                null
                        ? 'Absensi luar kantor'
                        : insight.summaryLabel,
                    note: _hasActiveOutsideOffice ||
                            _sessionState.latestCompletedOutsideOfficeFinish !=
                                null
                        ? _outsideOfficeSummaryNote
                        : insight.departureNote,
                  ),
                  const Divider(height: 24),
                  _MetricLine(
                    label: 'Verifikasi Wajah',
                    value:
                        _latestFaceCapturePath == null ? 'Belum ada' : 'Lolos',
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
                    Text('Sinkronisasi WFA',
                        style: theme.textTheme.titleMedium),
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
                    onPressed: (_isCheckedIn || _hasActiveOutsideOffice)
                        ? null
                        : _toggleGps,
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
            if (!_isCheckedIn && !_hasActiveOutsideOffice) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _isOutsideOfficeSubmitting
                    ? null
                    : _startOutsideOfficeAttendance,
                icon: const Icon(Icons.storefront_rounded),
                label: Text(
                  _isOutsideOfficeSubmitting
                      ? 'Memproses...'
                      : 'Absensi diluar kantor',
                ),
              ),
            ],
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
                  text:
                      'Face check-in hanya aktif jika GPS menyala dan verifikasi wajah lolos.',
                ),
                SizedBox(height: 10),
                _RuleTile(
                  text:
                      'Setelah wajah lolos verifikasi, lokasi user wajib tercatat sebelum check-in atau check-out dieksekusi.',
                ),
                SizedBox(height: 10),
                _RuleTile(
                  text:
                      'Jam kerja standar mock adalah masuk ${AttendancePolicy.officeStart} dan pulang ${AttendancePolicy.officeEnd}.',
                ),
                SizedBox(height: 10),
                _RuleTile(
                  text:
                      'Satu user hanya boleh punya satu sesi aktif dalam satu waktu.',
                ),
                SizedBox(height: 10),
                _RuleTile(
                  text: 'Capture wajah dan lokasi menjadi audit mock absensi.',
                ),
                SizedBox(height: 10),
                _RuleTile(
                  text:
                      'Area Manager juga bisa memakai absensi luar kantor untuk kunjungan client atau lokasi visit.',
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  VoidCallback? get _primaryAction {
    if (_isVerifyingFace || _isOutsideOfficeSubmitting) {
      return null;
    }
    if (_hasActiveOutsideOffice) {
      return _finishOutsideOfficeAttendance;
    }
    if (_isCheckedIn) {
      return _canUseNormalAttendance ? _startFaceCheckOut : null;
    }
    return _canUseNormalAttendance ? _startFaceCheckIn : null;
  }

  String get _primaryActionLabel {
    if (_isVerifyingFace || _isOutsideOfficeSubmitting) {
      return 'Memproses...';
    }
    if (_hasActiveOutsideOffice) {
      return 'Check-out luar kantor';
    }
    if (!_hasAttendanceArea) {
      return 'Area belum diset';
    }
    if (!_gpsActive) {
      return 'GPS belum aktif';
    }
    if (!_isInsideAttendanceRadius) {
      return 'Di luar radius kantor';
    }
    if (_isCheckedIn) {
      return 'Face Check-out';
    }
    return 'Face Check-in';
  }

  String get _durationText {
    final checkInAt = _checkInRecord?.recordedAt;
    final checkOutAt = _checkOutRecord?.recordedAt;
    if (_hasActiveOutsideOffice && checkInAt != null) {
      return _formatDuration(DateTime.now().difference(checkInAt));
    }
    if (checkInAt == null || checkOutAt == null) {
      return '-';
    }
    return _formatDuration(checkOutAt.difference(checkInAt));
  }

  String get _locationMetricValue {
    final location = _latestRecord?.location;
    if (location != null) {
      return _locationLabel(location);
    }
    if (!_gpsActive) {
      return 'Nonaktif';
    }
    if (_hasAttendanceArea && _liveDistanceMeters != null) {
      return _isInsideAttendanceRadius ? 'Dalam radius' : 'Di luar radius';
    }
    return 'Belum tercatat';
  }

  String get _locationMetricNote {
    if (_latestRecord?.location != null) {
      return 'Lokasi terakhir tersimpan sebagai audit absensi';
    }
    if (_hasAttendanceArea && _liveDistanceMeters != null) {
      return _isInsideAttendanceRadius
          ? 'Anda berada di dalam radius $_attendanceAreaName.'
          : 'Masuk ke radius $_attendanceAreaName untuk absensi normal.';
    }
    if (!_hasAttendanceArea) {
      return 'Area absensi belum diset oleh HR.';
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
    if (_hasActiveOutsideOffice) {
      return 'Absensi luar kantor aktif. Lanjutkan dengan check-out luar kantor saat aktivitas selesai.';
    }
    if (_isFinished) {
      return 'Check-out berhasil. Anda bisa memulai sesi check-in baru kapan saja.';
    }
    if (_isCheckedIn) {
      return 'Check-in berhasil. Sesi kerja aktif dan siap dipantau.';
    }
    return null;
  }

  String get _sessionSubSummary {
    if (_hasActiveOutsideOffice) {
      final metadata = _sessionState.activeOutsideOfficeStart?.metadata;
      final placeDescription = metadata?.placeDescription;
      if (placeDescription != null && placeDescription.isNotEmpty) {
        return 'Aktivitas luar kantor aktif untuk $placeDescription. Lokasi audit terakhir: $_locationMetricValue.';
      }
      return 'Absensi luar kantor sedang aktif. Lengkapi check-out luar kantor saat aktivitas selesai.';
    }
    if (_isFinished) {
      return 'Durasi sesi terakhir tersimpan $_durationText dengan lokasi audit $_locationMetricValue.';
    }
    if (_attendanceInsight.nextStartRecommendation != null) {
      return 'Lokasi audit terakhir: $_locationMetricValue. Rekomendasi masuk esok hari ${_attendanceInsight.nextStartRecommendation}.';
    }
    return 'Lokasi audit terakhir: $_locationMetricValue.';
  }

  String get _outsideOfficeSummaryNote {
    final metadata = _sessionState.activeOutsideOfficeStart?.metadata ??
        _sessionState.latestCompletedOutsideOfficeFinish?.metadata ??
        _sessionState.latestCompletedOutsideOfficeStart?.metadata;
    if (metadata == null) {
      return 'Lokasi, foto, dan ringkasan kunjungan disimpan sebagai audit lapangan.';
    }

    final subject =
        metadata.placeDescription ?? metadata.ukmName ?? 'aktivitas lapangan';
    return 'Audit luar kantor untuk $subject.';
  }

  void _toggleGps() {
    setState(() => _gpsActive = !_gpsActive);
    if (_gpsActive) {
      _startLiveLocationTracking();
    } else {
      _positionSubscription?.cancel();
      _positionSubscription = null;
    }
  }

  Future<void> _startLiveLocationTracking() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) {
          return;
        }
        setState(() {
          _gpsActive = false;
          _locationError = 'Layanan lokasi device sedang nonaktif.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) {
          return;
        }
        setState(() {
          _locationError =
              'Izin lokasi dibutuhkan agar absensi bisa mencatat koordinat user.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _syncLivePosition(position);

      await _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(_syncLivePosition);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _locationError =
            'Lokasi live belum berhasil didapatkan. Pastikan GPS aktif dan sinyal stabil.';
      });
    }
  }

  void _syncLivePosition(Position position) {
    if (!mounted) {
      return;
    }
    setState(() {
      _livePosition = position;
      _gpsActive = true;
      _locationError = null;
    });
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
    ) onVerified,
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
    bool requireOfficeRadius = true,
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

      final location = _buildAttendanceLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        requireOfficeRadius: requireOfficeRadius,
      );

      if (requireOfficeRadius && location.withinRadius != true) {
        setState(() {
          _gpsActive = true;
          _locationError = 'Anda tidak berada di area kantor.';
        });
        _showAttendanceSnackBar('Anda tidak berada di area kantor.');
        return null;
      }

      setState(() {
        _gpsActive = true;
        _locationError = null;
        _livePosition = position;
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

  _AttendanceLocation _buildAttendanceLocation({
    required double latitude,
    required double longitude,
    required bool requireOfficeRadius,
  }) {
    final officeLatitude = widget.session.officeLatitude;
    final officeLongitude = widget.session.officeLongitude;
    final radiusMeters = widget.session.attendanceRadiusMeters;

    if (officeLatitude == null ||
        officeLongitude == null ||
        radiusMeters == null) {
      return _AttendanceLocation(
        latitude: latitude,
        longitude: longitude,
      );
    }

    final distanceMeters = Geolocator.distanceBetween(
      officeLatitude,
      officeLongitude,
      latitude,
      longitude,
    );

    return _AttendanceLocation(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters.toDouble(),
      distanceMeters: distanceMeters,
      withinRadius: distanceMeters <= radiusMeters,
      areaName: requireOfficeRadius ? _attendanceAreaName : null,
    );
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
          radiusMeters: location.radiusMeters,
          withinRadius: location.withinRadius,
          distanceMeters: location.distanceMeters,
          workAreaName: location.areaName,
          workAreaLatitude: widget.session.officeLatitude,
          workAreaLongitude: widget.session.officeLongitude,
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
          radiusMeters: location.radiusMeters,
          withinRadius: location.withinRadius,
          distanceMeters: location.distanceMeters,
          workAreaName: location.areaName,
          workAreaLatitude: widget.session.officeLatitude,
          workAreaLongitude: widget.session.officeLongitude,
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

  Future<void> _startOutsideOfficeAttendance() async {
    final enrollmentBlock = _faceEnrollmentBlockReason(
      'memulai absensi luar kantor',
    );
    if (enrollmentBlock != null) {
      _showAttendanceSnackBar(enrollmentBlock);
      return;
    }

    bool shouldOpenFinishSheet = false;

    setState(() {
      _isOutsideOfficeSubmitting = true;
      _locationError = null;
    });

    try {
      final faceScanResult = await _runFaceVerification(
        mode: _FaceVerificationMode.checkIn,
      );
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
        action: 'checkIn',
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

      final location = await _recordCurrentLocation(
        mode: _FaceVerificationMode.checkIn,
        requireOfficeRadius: false,
      );
      if (location == null || !mounted) {
        return;
      }

      final result = await _showOutsideOfficeFormSheet(
        title: 'Check-in luar kantor',
        submitLabel: 'Simpan check-in',
      );
      if (!mounted || result == null) {
        return;
      }

      final attachment = await widget.controller.uploadAttachment(
        filePath: result.evidencePath,
        label: 'Outside office start ${result.placeDescription}',
      );

      final now = DateTime.now();
      await widget.controller.createAttendanceRecord(
        widget.session,
        AttendanceRecord(
          id: 'attendance-outside-start-${widget.session.ownerKey}-${now.microsecondsSinceEpoch}',
          userId: widget.session.ownerKey,
          workDate: DateTime(now.year, now.month, now.day),
          action: AttendanceAction.outsideOfficeStart,
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
          metadata: AttendanceMetadata(
            attendanceMode: 'outside_office',
            placeDescription: result.placeDescription,
            evidenceAttachment: attachment,
            startedAt: now,
          ),
          note:
              'Absensi luar kantor dimulai untuk ${result.placeDescription} setelah wajah terverifikasi dan lokasi ${location.label} tercatat.',
        ),
      );

      if (!mounted) {
        return;
      }
      _showAttendanceSnackBar(
        'Check-in luar kantor berhasil disimpan. ${_verificationSummary(verificationResult)}',
      );
      shouldOpenFinishSheet = false;
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showAttendanceSnackBar('Absensi luar kantor gagal: $error');
    } finally {
      if (mounted) {
        setState(() => _isOutsideOfficeSubmitting = false);
      }
    }

    if (mounted && shouldOpenFinishSheet) {
      await _finishOutsideOfficeAttendance();
    }
  }

  Future<void> _finishOutsideOfficeAttendance() async {
    final enrollmentBlock = _faceEnrollmentBlockReason(
      'menyelesaikan absensi luar kantor',
    );
    if (enrollmentBlock != null) {
      _showAttendanceSnackBar(enrollmentBlock);
      return;
    }

    setState(() {
      _isOutsideOfficeSubmitting = true;
      _locationError = null;
    });

    try {
      final faceScanResult = await _runFaceVerification(
        mode: _FaceVerificationMode.checkOut,
      );
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
        action: 'checkOut',
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

      final result = await _showOutsideOfficeFormSheet(
        title: 'Check-out luar kantor',
        submitLabel: 'Simpan check-out',
      );
      if (!mounted || result == null) {
        return;
      }

      final location = await _recordCurrentLocation(
        mode: _FaceVerificationMode.checkOut,
        requireOfficeRadius: false,
      );
      if (location == null || !mounted) {
        return;
      }

      final attachment = await widget.controller.uploadAttachment(
        filePath: result.evidencePath,
        label: 'Outside office finish ${result.placeDescription}',
      );

      final now = DateTime.now();
      await widget.controller.createAttendanceRecord(
        widget.session,
        AttendanceRecord(
          id: 'attendance-outside-finish-${widget.session.ownerKey}-${now.microsecondsSinceEpoch}',
          userId: widget.session.ownerKey,
          workDate: DateTime(now.year, now.month, now.day),
          action: AttendanceAction.outsideOfficeFinish,
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
          metadata: AttendanceMetadata(
            attendanceMode: 'outside_office',
            placeDescription: result.placeDescription,
            evidenceAttachment: attachment,
            finishedAt: now,
          ),
          note: 'Absensi luar kantor selesai untuk ${result.placeDescription}.',
        ),
      );

      if (!mounted) {
        return;
      }
      _showAttendanceSnackBar(
        'Check-out luar kantor berhasil disimpan. ${_verificationSummary(verificationResult)}',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showAttendanceSnackBar('Gagal menyimpan check-out luar kantor: $error');
    } finally {
      if (mounted) {
        setState(() => _isOutsideOfficeSubmitting = false);
      }
    }
  }

  Future<_OutsideOfficeDraft?> _showOutsideOfficeFormSheet({
    required String title,
    required String submitLabel,
  }) async {
    final placeController = TextEditingController();
    String? evidencePath;

    return showModalBottomSheet<_OutsideOfficeDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickEvidence(ImageSource source) async {
              final file = await _picker.pickImage(
                source: source,
                imageQuality: 58,
                maxWidth: 1280,
                maxHeight: 1280,
              );
              if (file == null) {
                return;
              }
              setModalState(() => evidencePath = file.path);
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: placeController,
                        decoration: const InputDecoration(
                          labelText: 'Absen dimana hari ini?',
                          hintText: 'Contoh: Kunjungan ke client di Tomang',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => pickEvidence(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_rounded),
                            label: const Text('Kamera'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => pickEvidence(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_rounded),
                            label: const Text('Galeri'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (evidencePath == null)
                        Text(
                          'Dokumentasi foto kamera atau galeri wajib diisi.',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            File(evidencePath!),
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                          ),
                        ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Batal'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                if (placeController.text.trim().isEmpty ||
                                    evidencePath == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Lengkapi lokasi/keperluan dan foto dokumentasi.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                Navigator.of(context).pop(
                                  _OutsideOfficeDraft(
                                    placeDescription:
                                        placeController.text.trim(),
                                    evidencePath: evidencePath!,
                                  ),
                                );
                              },
                              child: Text(submitLabel),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
    final actionLabel = switch (record.action) {
      AttendanceAction.checkIn => 'Check-in',
      AttendanceAction.checkOut => 'Check-out',
      AttendanceAction.outsideOfficeStart => 'Mulai kunjungan',
      AttendanceAction.outsideOfficeFinish => 'Selesai kunjungan',
    };
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

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours <= 0) {
      return '${minutes}m';
    }
    return '${hours}j ${minutes}m';
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
    this.activeRegularCheckIn,
    this.latestCompletedCheckIn,
    this.latestCompletedCheckOut,
    this.activeOutsideOfficeStart,
    this.latestCompletedOutsideOfficeStart,
    this.latestCompletedOutsideOfficeFinish,
  });

  final AttendanceRecord? activeRegularCheckIn;
  final AttendanceRecord? latestCompletedCheckIn;
  final AttendanceRecord? latestCompletedCheckOut;
  final AttendanceRecord? activeOutsideOfficeStart;
  final AttendanceRecord? latestCompletedOutsideOfficeStart;
  final AttendanceRecord? latestCompletedOutsideOfficeFinish;

  AttendanceRecord? get displayCheckIn =>
      activeRegularCheckIn ?? latestCompletedCheckIn;
  AttendanceRecord? get displayCheckOut =>
      activeRegularCheckIn == null ? latestCompletedCheckOut : null;
  AttendanceRecord? get displayOutsideOfficeStart =>
      activeOutsideOfficeStart ?? latestCompletedOutsideOfficeStart;
  AttendanceRecord? get displayOutsideOfficeFinish =>
      activeOutsideOfficeStart == null
          ? latestCompletedOutsideOfficeFinish
          : null;

  static _AttendanceSessionState fromRecords(List<AttendanceRecord> records) {
    final sorted = [...records]
      ..sort((left, right) => left.recordedAt.compareTo(right.recordedAt));

    AttendanceRecord? openCheckIn;
    AttendanceRecord? latestCompletedCheckIn;
    AttendanceRecord? latestCompletedCheckOut;
    AttendanceRecord? activeOutsideOfficeStart;
    AttendanceRecord? latestCompletedOutsideOfficeStart;
    AttendanceRecord? latestCompletedOutsideOfficeFinish;

    for (final record in sorted) {
      if (record.status != AttendanceRecordStatus.success) {
        continue;
      }

      switch (record.action) {
        case AttendanceAction.checkIn:
          openCheckIn = record;
          break;
        case AttendanceAction.checkOut:
          if (openCheckIn != null) {
            latestCompletedCheckIn = openCheckIn;
            latestCompletedCheckOut = record;
            openCheckIn = null;
          }
          break;
        case AttendanceAction.outsideOfficeStart:
          activeOutsideOfficeStart = record;
          break;
        case AttendanceAction.outsideOfficeFinish:
          if (activeOutsideOfficeStart != null) {
            latestCompletedOutsideOfficeStart = activeOutsideOfficeStart;
            latestCompletedOutsideOfficeFinish = record;
            activeOutsideOfficeStart = null;
          }
          break;
      }
    }

    return _AttendanceSessionState(
      activeRegularCheckIn: openCheckIn,
      latestCompletedCheckIn: latestCompletedCheckIn,
      latestCompletedCheckOut: latestCompletedCheckOut,
      activeOutsideOfficeStart: activeOutsideOfficeStart,
      latestCompletedOutsideOfficeStart: latestCompletedOutsideOfficeStart,
      latestCompletedOutsideOfficeFinish: latestCompletedOutsideOfficeFinish,
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

class _LiveLocationRadiusCard extends StatelessWidget {
  const _LiveLocationRadiusCard({
    required this.areaName,
    required this.hasAttendanceArea,
    required this.gpsActive,
    required this.isInsideRadius,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.officeLatitude,
    required this.officeLongitude,
    required this.distanceMeters,
    required this.radiusMeters,
    required this.errorText,
  });

  final String areaName;
  final bool hasAttendanceArea;
  final bool gpsActive;
  final bool isInsideRadius;
  final double? currentLatitude;
  final double? currentLongitude;
  final double? officeLatitude;
  final double? officeLongitude;
  final double? distanceMeters;
  final int? radiusMeters;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = !hasAttendanceArea || !gpsActive
        ? Colors.orange
        : isInsideRadius
            ? Colors.green
            : Colors.red;
    final statusLabel = !hasAttendanceArea
        ? 'Area belum diset HR'
        : !gpsActive
            ? 'GPS belum aktif'
            : isInsideRadius
                ? 'Di dalam radius'
                : 'Di luar radius';
    final coordinateLabel = currentLatitude == null || currentLongitude == null
        ? 'Mencari lokasi live...'
        : '${currentLatitude!.toStringAsFixed(6)}, ${currentLongitude!.toStringAsFixed(6)}';
    final distanceLabel = distanceMeters == null
        ? '-'
        : distanceMeters! >= 1000
            ? '${(distanceMeters! / 1000).toStringAsFixed(2)} km'
            : '${distanceMeters!.round()} m';
    final radiusLabel = radiusMeters == null
        ? '-'
        : radiusMeters! >= 1000
            ? '${(radiusMeters! / 1000).toStringAsFixed(1)} km'
            : '$radiusMeters m';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.my_location_rounded, color: statusColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  areaName,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              StatusBadge(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 12),
          _LocationMapPreview(
            areaName: areaName,
            currentLatitude: currentLatitude,
            currentLongitude: currentLongitude,
            officeLatitude: officeLatitude,
            officeLongitude: officeLongitude,
            radiusMeters: radiusMeters,
            isInsideRadius: isInsideRadius,
            statusColor: statusColor,
          ),
          const SizedBox(height: 12),
          Text(
            coordinateLabel,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Jarak dari titik area: $distanceLabel dari radius $radiusLabel.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              errorText!,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}

class _LocationMapPreview extends StatelessWidget {
  const _LocationMapPreview({
    required this.areaName,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.officeLatitude,
    required this.officeLongitude,
    required this.radiusMeters,
    required this.isInsideRadius,
    required this.statusColor,
  });

  final String areaName;
  final double? currentLatitude;
  final double? currentLongitude;
  final double? officeLatitude;
  final double? officeLongitude;
  final int? radiusMeters;
  final bool isInsideRadius;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUserPosition = currentLatitude != null && currentLongitude != null;
    final hasOfficePosition = officeLatitude != null && officeLongitude != null;

    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Stack(
        children: [
          if (hasOfficePosition && radiusMeters != null)
            Positioned.fill(
              child: _SlippyMapLayer(
                currentLatitude: currentLatitude,
                currentLongitude: currentLongitude,
                officeLatitude: officeLatitude!,
                officeLongitude: officeLongitude!,
                radiusMeters: radiusMeters!,
                isInsideRadius: isInsideRadius,
                statusColor: statusColor,
              ),
            ),
          Positioned(
            left: 14,
            top: 12,
            right: 14,
            child: Row(
              children: [
                const Icon(Icons.business_rounded, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Titik area: $areaName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!hasOfficePosition || radiusMeters == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'Area absensi belum lengkap. HR perlu mengisi titik lokasi dan radius.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            )
          else if (!hasUserPosition)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Mencari titik lokasi kamu...',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Row(
              children: [
                _RadarLegendDot(
                  color: const Color(0xFF06B6D4),
                  label: 'Titik area',
                ),
                const SizedBox(width: 12),
                _RadarLegendDot(
                  color: statusColor,
                  label: 'Posisi kamu',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlippyMapLayer extends StatelessWidget {
  const _SlippyMapLayer({
    required this.currentLatitude,
    required this.currentLongitude,
    required this.officeLatitude,
    required this.officeLongitude,
    required this.radiusMeters,
    required this.isInsideRadius,
    required this.statusColor,
  });

  final double? currentLatitude;
  final double? currentLongitude;
  final double officeLatitude;
  final double officeLongitude;
  final int radiusMeters;
  final bool isInsideRadius;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final hasUser = currentLatitude != null && currentLongitude != null;
        final centerLatitude =
            hasUser ? (officeLatitude + currentLatitude!) / 2 : officeLatitude;
        final centerLongitude = hasUser
            ? (officeLongitude + currentLongitude!) / 2
            : officeLongitude;
        final userDistance = hasUser
            ? Geolocator.distanceBetween(
                officeLatitude,
                officeLongitude,
                currentLatitude!,
                currentLongitude!,
              )
            : 0.0;
        final zoom = _MapMath.bestZoomFor(
          latitude: centerLatitude,
          radiusMeters: math.max(radiusMeters.toDouble(), userDistance),
          shortestSide: math.max(180, math.min(size.width, size.height)),
        );
        final centerWorld = _MapMath.latLngToWorldPixel(
          centerLatitude,
          centerLongitude,
          zoom,
        );
        final officeWorld = _MapMath.latLngToWorldPixel(
          officeLatitude,
          officeLongitude,
          zoom,
        );
        final officeOffset = Offset(
          size.width / 2 + officeWorld.dx - centerWorld.dx,
          size.height / 2 + officeWorld.dy - centerWorld.dy,
        );
        final userOffset = hasUser
            ? (() {
                final userWorld = _MapMath.latLngToWorldPixel(
                  currentLatitude!,
                  currentLongitude!,
                  zoom,
                );
                return Offset(
                  size.width / 2 + userWorld.dx - centerWorld.dx,
                  size.height / 2 + userWorld.dy - centerWorld.dy,
                );
              })()
            : null;
        final metersPerPixel = _MapMath.metersPerPixel(centerLatitude, zoom);
        final radiusPx = radiusMeters / metersPerPixel;
        final tiles = _visibleTiles(
          centerWorld: centerWorld,
          size: size,
          zoom: zoom,
        );

        return Stack(
          children: [
            Positioned.fill(
              child: Container(color: const Color(0xFFF4F1EA)),
            ),
            for (final tile in tiles)
              Positioned(
                left: tile.screenOffset.dx,
                top: tile.screenOffset.dy,
                width: _MapMath.tileSize,
                height: _MapMath.tileSize,
                child: Image.network(
                  'https://tile.openstreetmap.org/$zoom/${tile.x}/${tile.y}.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFFE9E4DB),
                      child: CustomPaint(
                        painter: _FallbackMapTilePainter(),
                      ),
                    );
                  },
                ),
              ),
            Positioned.fill(
              child: CustomPaint(
                painter: _MapOverlayPainter(
                  officeOffset: officeOffset,
                  userOffset: userOffset,
                  radiusPx: radiusPx,
                  isInsideRadius: isInsideRadius,
                  statusColor: statusColor,
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'OSM',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<_MapTile> _visibleTiles({
    required Offset centerWorld,
    required Size size,
    required int zoom,
  }) {
    final leftWorld = centerWorld.dx - size.width / 2;
    final topWorld = centerWorld.dy - size.height / 2;
    final rightWorld = centerWorld.dx + size.width / 2;
    final bottomWorld = centerWorld.dy + size.height / 2;
    final minTileX = (leftWorld / _MapMath.tileSize).floor() - 1;
    final maxTileX = (rightWorld / _MapMath.tileSize).floor() + 1;
    final minTileY = (topWorld / _MapMath.tileSize).floor() - 1;
    final maxTileY = (bottomWorld / _MapMath.tileSize).floor() + 1;
    final maxTile = 1 << zoom;
    final tiles = <_MapTile>[];

    for (var x = minTileX; x <= maxTileX; x++) {
      for (var y = minTileY; y <= maxTileY; y++) {
        if (y < 0 || y >= maxTile) {
          continue;
        }
        final wrappedX = ((x % maxTile) + maxTile) % maxTile;
        tiles.add(
          _MapTile(
            x: wrappedX,
            y: y,
            screenOffset: Offset(
              x * _MapMath.tileSize - leftWorld,
              y * _MapMath.tileSize - topWorld,
            ),
          ),
        );
      }
    }

    return tiles;
  }
}

class _MapTile {
  const _MapTile({
    required this.x,
    required this.y,
    required this.screenOffset,
  });

  final int x;
  final int y;
  final Offset screenOffset;
}

class _MapMath {
  static const double tileSize = 256;

  static int bestZoomFor({
    required double latitude,
    required double radiusMeters,
    required double shortestSide,
  }) {
    final targetRadiusPx = shortestSide * 0.26;
    for (var zoom = 19; zoom >= 12; zoom--) {
      final radiusPx = radiusMeters / metersPerPixel(latitude, zoom);
      if (radiusPx <= targetRadiusPx) {
        return zoom;
      }
    }
    return 12;
  }

  static double metersPerPixel(double latitude, int zoom) {
    return 156543.03392 *
        math.cos(latitude * math.pi / 180) /
        math.pow(2, zoom);
  }

  static Offset latLngToWorldPixel(
    double latitude,
    double longitude,
    int zoom,
  ) {
    final sinLatitude = math.sin(latitude * math.pi / 180);
    final scale = tileSize * math.pow(2, zoom);
    final x = (longitude + 180) / 360 * scale;
    final y = (0.5 -
            math.log((1 + sinLatitude) / (1 - sinLatitude)) / (4 * math.pi)) *
        scale;

    return Offset(x.toDouble(), y.toDouble());
  }
}

class _RadarLegendDot extends StatelessWidget {
  const _RadarLegendDot({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _FallbackMapTilePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    final buildingPaint = Paint()
      ..color = const Color(0xFFD6CFC5)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < 6; i++) {
      final left = (i * 46).toDouble();
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left + 8, 16, 28, 36),
          const Radius.circular(3),
        ),
        buildingPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left + 18, 104, 34, 42),
          const Radius.circular(3),
        ),
        buildingPaint,
      );
    }

    canvas.drawLine(
      Offset(size.width * 0.22, -20),
      Offset(size.width * 0.42, size.height + 20),
      roadPaint,
    );
    canvas.drawLine(
      Offset(-20, size.height * 0.58),
      Offset(size.width + 20, size.height * 0.34),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FallbackMapTilePainter oldDelegate) => false;
}

class _MapOverlayPainter extends CustomPainter {
  const _MapOverlayPainter({
    required this.officeOffset,
    required this.userOffset,
    required this.radiusPx,
    required this.isInsideRadius,
    required this.statusColor,
  });

  final Offset officeOffset;
  final Offset? userOffset;
  final double radiusPx;
  final bool isInsideRadius;
  final Color statusColor;

  @override
  void paint(Canvas canvas, Size size) {
    final clippedRadius = math.min(radiusPx, math.max(size.width, size.height));
    final boundaryPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;
    final boundaryStroke = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    canvas.drawCircle(officeOffset, clippedRadius, boundaryPaint);
    canvas.drawCircle(officeOffset, clippedRadius, boundaryStroke);

    _drawPin(
      canvas,
      officeOffset,
      fillColor: const Color(0xFF06B6D4),
      iconColor: Colors.white,
      iconKind: _MapPinKind.office,
    );

    final userPoint = userOffset;
    if (userPoint == null) {
      return;
    }

    final linePaint = Paint()
      ..color = statusColor.withValues(alpha: 0.54)
      ..strokeWidth = 2;
    canvas.drawLine(officeOffset, userPoint, linePaint);

    final userGlow = Paint()
      ..color = statusColor.withValues(alpha: isInsideRadius ? 0.22 : 0.28);
    canvas.drawCircle(userPoint, 18, userGlow);
    _drawPin(
      canvas,
      userPoint,
      fillColor: statusColor,
      iconColor: Colors.white,
      iconKind: _MapPinKind.user,
    );
  }

  void _drawPin(
    Canvas canvas,
    Offset point, {
    required Color fillColor,
    required Color iconColor,
    required _MapPinKind iconKind,
  }) {
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final pinPath = Path()
      ..moveTo(point.dx, point.dy + 25)
      ..cubicTo(point.dx - 20, point.dy + 5, point.dx - 16, point.dy - 20,
          point.dx, point.dy - 20)
      ..cubicTo(point.dx + 16, point.dy - 20, point.dx + 20, point.dy + 5,
          point.dx, point.dy + 25)
      ..close();
    canvas.drawPath(pinPath.shift(const Offset(0, 2)), shadowPaint);
    canvas.drawPath(pinPath, Paint()..color = fillColor);
    canvas.drawCircle(point.translate(0, -3), 11, Paint()..color = iconColor);

    final detailPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    if (iconKind == _MapPinKind.office) {
      canvas.drawRect(
        Rect.fromCenter(center: point.translate(0, -3), width: 10, height: 7),
        detailPaint,
      );
      canvas.drawLine(
        point.translate(-6, -6),
        point.translate(0, -11),
        detailPaint,
      );
      canvas.drawLine(
        point.translate(6, -6),
        point.translate(0, -11),
        detailPaint,
      );
    } else {
      canvas.drawCircle(point.translate(0, -6), 3, detailPaint);
      canvas.drawArc(
        Rect.fromCenter(center: point.translate(0, 2), width: 11, height: 8),
        math.pi,
        math.pi,
        false,
        detailPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MapOverlayPainter oldDelegate) {
    return oldDelegate.officeOffset != officeOffset ||
        oldDelegate.userOffset != userOffset ||
        oldDelegate.radiusPx != radiusPx ||
        oldDelegate.isInsideRadius != isInsideRadius ||
        oldDelegate.statusColor != statusColor;
  }
}

enum _MapPinKind {
  office,
  user,
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
    this.radiusMeters,
    this.withinRadius,
    this.distanceMeters,
    this.areaName,
  });

  final double latitude;
  final double longitude;
  final double? radiusMeters;
  final bool? withinRadius;
  final double? distanceMeters;
  final String? areaName;

  String get label {
    if (areaName != null && areaName!.isNotEmpty) {
      return areaName!;
    }
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }

  _AttendanceLocation copyWith({
    double? latitude,
    double? longitude,
    double? radiusMeters,
    bool? withinRadius,
    double? distanceMeters,
    String? areaName,
  }) {
    return _AttendanceLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      withinRadius: withinRadius ?? this.withinRadius,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      areaName: areaName ?? this.areaName,
    );
  }
}

class _OutsideOfficeDraft {
  const _OutsideOfficeDraft({
    required this.placeDescription,
    required this.evidencePath,
  });

  final String placeDescription;
  final String evidencePath;
}
