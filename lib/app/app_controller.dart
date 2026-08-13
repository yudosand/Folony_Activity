import 'dart:async';

import 'package:flutter/material.dart';

import '../core/enums/app_role.dart';
import '../core/models/announcement.dart';
import '../core/models/app_session.dart';
import '../core/models/app_user.dart';
import '../core/models/attendance_record.dart';
import '../core/models/face_profile.dart';
import '../core/models/face_verification_result.dart';
import '../core/models/heat_map_snapshot.dart';
import '../core/models/network_entry.dart';
import '../core/models/network_profile.dart';
import '../core/models/network_profile_mapper.dart';
import '../core/models/performance_summary.dart';
import '../core/models/approval_step.dart';
import '../core/models/leave_request_record.dart' as leave_model;
import '../core/models/remote_attachment.dart';
import '../core/models/survey_models.dart';
import '../core/models/territory_option.dart';
import '../core/models/wfa_request_record.dart' as wfa_model;
import '../core/repositories/announcement_repository.dart';
import '../core/repositories/approval_repository.dart';
import '../core/repositories/attendance_repository.dart';
import '../core/repositories/auth_repository.dart';
import '../core/repositories/face_profile_repository.dart';
import '../core/repositories/heat_map_repository.dart';
import '../core/repositories/leave_repository.dart';
import '../core/repositories/mock/mock_attendance_repository.dart';
import '../core/repositories/mock/mock_face_profile_repository.dart';
import '../core/repositories/mock/mock_heat_map_repository.dart';
import '../core/repositories/mock/mock_network_repository.dart';
import '../core/repositories/mock/mock_performance_repository.dart';
import '../core/repositories/mock/mock_approval_repository.dart';
import '../core/repositories/mock/mock_announcement_repository.dart';
import '../core/repositories/mock/mock_leave_repository.dart';
import '../core/repositories/mock/mock_territory_repository.dart';
import '../core/repositories/mock/mock_survey_repository.dart';
import '../core/repositories/mock/mock_wfa_repository.dart';
import '../core/repositories/mock/mock_upload_repository.dart';
import '../core/repositories/network_repository.dart';
import '../core/repositories/performance_repository.dart';
import '../core/repositories/survey_repository.dart';
import '../core/repositories/territory_repository.dart';
import '../core/repositories/upload_repository.dart';
import '../core/repositories/wfa_repository.dart';
import '../core/services/attendance_policy.dart';
import '../core/services/push_notification_service.dart';
import '../features/face/data/face_biometric_analyzer.dart';

class AppController extends ChangeNotifier {
  static const String multiRoleTesterIdentifier = 'allrole';
  static const String multiRoleTesterPassword = '123456';

  AppController({
    AuthRepository? authRepository,
    NetworkRepository? networkRepository,
    AttendanceRepository? attendanceRepository,
    LeaveRepository? leaveRepository,
    WfaRepository? wfaRepository,
    ApprovalRepository? approvalRepository,
    AnnouncementRepository? announcementRepository,
    HeatMapRepository? heatMapRepository,
    UploadRepository? uploadRepository,
    PerformanceRepository? performanceRepository,
    SurveyRepository? surveyRepository,
    TerritoryRepository? territoryRepository,
    FaceProfileRepository? faceProfileRepository,
    FaceBiometricAnalyzer? faceBiometricAnalyzer,
    PushNotificationService? pushNotificationService,
    bool useRemoteAuth = false,
    bool allowDemoMode = false,
    bool useCanonicalWorkflowIds = false,
    bool seedWorkflowDemoData = true,
  })  : _authRepository = authRepository,
        _networkRepository = networkRepository ?? MockNetworkRepository(),
        _attendanceRepository =
            attendanceRepository ?? MockAttendanceRepository(),
        _leaveRepository = leaveRepository ?? MockLeaveRepository(),
        _wfaRepository = wfaRepository ?? MockWfaRepository(),
        _approvalRepository = approvalRepository ?? MockApprovalRepository(),
        _announcementRepository =
            announcementRepository ?? const MockAnnouncementRepository(),
        _heatMapRepository = heatMapRepository ?? const MockHeatMapRepository(),
        _uploadRepository = uploadRepository ?? const MockUploadRepository(),
        _performanceRepository =
            performanceRepository ?? const MockPerformanceRepository(),
        _surveyRepository = surveyRepository ?? MockSurveyRepository(),
        _territoryRepository =
            territoryRepository ?? const MockTerritoryRepository(),
        _faceProfileRepository =
            faceProfileRepository ?? MockFaceProfileRepository(),
        _faceBiometricAnalyzer =
            faceBiometricAnalyzer ?? FaceBiometricAnalyzer(),
        _pushNotificationService = pushNotificationService,
        _useRemoteAuth = useRemoteAuth,
        _allowDemoMode = allowDemoMode,
        _useCanonicalWorkflowIds = useCanonicalWorkflowIds,
        _seedWorkflowDemoData = seedWorkflowDemoData {
    if (_seedWorkflowDemoData) {
      _seedDemoFggEntries();
      _seedDemoWorkflowRequests();
    }
    _pushTokenSubscription = _pushNotificationService?.tokenStream.listen((_) {
      if (_session != null && _useRemoteAuth) {
        unawaited(_syncPushTokenRegistration());
      }
    });
    unawaited(_restoreSession());
  }

  AppSession? _session;
  final AuthRepository? _authRepository;
  final NetworkRepository _networkRepository;
  final AttendanceRepository _attendanceRepository;
  final LeaveRepository _leaveRepository;
  final WfaRepository _wfaRepository;
  final ApprovalRepository _approvalRepository;
  final AnnouncementRepository _announcementRepository;
  final HeatMapRepository _heatMapRepository;
  final UploadRepository _uploadRepository;
  final PerformanceRepository _performanceRepository;
  final SurveyRepository _surveyRepository;
  final TerritoryRepository _territoryRepository;
  final FaceProfileRepository _faceProfileRepository;
  final FaceBiometricAnalyzer _faceBiometricAnalyzer;
  final PushNotificationService? _pushNotificationService;
  final bool _useRemoteAuth;
  final bool _allowDemoMode;
  final bool _useCanonicalWorkflowIds;
  final bool _seedWorkflowDemoData;
  bool _isAuthenticating = false;
  bool _isBootstrapping = true;
  final Map<String, List<NetworkEntry>> _networkEntriesByOwner = {};
  final Map<String, List<NetworkEntry>> _teamUkmEntriesByAreaManager = {};
  final Map<String, List<AttendanceRecord>> _attendanceRecordsByOwner = {};
  final Map<String, PerformanceSummary?> _performanceSummaryByOwner = {};
  final Map<String, List<leave_model.LeaveRequestRecord>>
      _leaveRequestsByOwner = {};
  final Map<String, List<wfa_model.WfaRequestRecord>> _wfaRequestsByOwner = {};
  final Map<String, List<leave_model.LeaveRequestRecord>>
      _leaveApprovalRequestsByApprover = {};
  final Map<String, List<wfa_model.WfaRequestRecord>>
      _wfaApprovalRequestsByApprover = {};
  List<Announcement> _announcements = const [];
  SurveyOptions? _surveyOptions;
  final Map<String, double> _leaveBalanceByUserId = {};
  final Map<String, FaceProfile> _faceProfilesByOwner = {};
  List<TerritoryOption>? _territoryProvinceCache;
  final Map<String, List<TerritoryOption>> _territoryCityCache = {};
  final Map<String, List<TerritoryOption>> _territoryDistrictCache = {};
  final Map<String, List<TerritoryOption>> _territorySubdistrictCache = {};
  StreamSubscription<String>? _pushTokenSubscription;

  AppSession? get session => _session;
  bool get isAuthenticated => _session != null;
  bool get isAuthenticating => _isAuthenticating;
  bool get isBootstrapping => _isBootstrapping;
  bool get isRemoteAuthEnabled => _useRemoteAuth;
  bool get isDemoModeEnabled => _allowDemoMode && !_useRemoteAuth;
  bool canSwitchRolesForSession(AppSession session) =>
      !_useRemoteAuth || session.canSwitchRoles;
  List<AppRole> switchableRolesForSession(AppSession session) =>
      session.canSwitchRoles ? session.availableRoles : AppRole.values;

  void signInAs(
    AppRole role, {
    String? userName,
  }) {
    _activateSession(
      AppSession.mock(role, userName: userName),
      notify: true,
    );
  }

  Future<void> signIn({
    required String identifier,
    required String password,
    required AppRole fallbackRole,
  }) async {
    if (_matchesMultiRoleTester(identifier: identifier, password: password)) {
      if (_useRemoteAuth || !_allowDemoMode) {
        throw StateError(
          'Akun allrole hanya tersedia di mode demo lokal. Gunakan akun Folony yang valid.',
        );
      }
      if (_authRepository != null) {
        await _authRepository.signOut();
      }
      await _activateSession(
        AppSession.multiRoleTester(fallbackRole),
      );
      return;
    }

    if (!_useRemoteAuth || _authRepository == null) {
      if (!_allowDemoMode) {
        throw StateError(
          'Mode demo tidak aktif. Login harus menggunakan akun Folony yang valid.',
        );
      }
      signInAs(fallbackRole, userName: identifier);
      return;
    }

    _isAuthenticating = true;
    notifyListeners();
    final authRepository = _authRepository;
    try {
      final user = await authRepository.signIn(
        identifier: identifier,
        password: password,
      );
      await _applySignedInUser(user);
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final authRepository = _authRepository;
    if (!_useRemoteAuth || authRepository == null) {
      throw StateError(
          'Ubah password hanya tersedia saat terhubung ke server Folony.');
    }

    await authRepository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      newPasswordConfirmation: newPasswordConfirmation,
    );
  }

  void switchRole(AppRole role) {
    if (_session == null) {
      signInAs(role);
      return;
    }

    if (_useRemoteAuth && !_session!.canSwitchRoles) {
      return;
    }

    unawaited(_activateSession(_session!.copyWith(
      userId: role.workflowDemoUserId,
      role: role,
      userName: role.mockUserName,
      areaName: role.defaultArea,
      email: null,
      jobTitle: role.label,
      spvId: role == AppRole.staff ? AppRole.spv.workflowDemoUserId : null,
      spvName: role == AppRole.staff ? AppRole.spv.mockUserName : null,
      managementId: switch (role) {
        AppRole.staff ||
        AppRole.spv ||
        AppRole.areaManager =>
          AppRole.management.workflowDemoUserId,
        _ => null,
      },
      managementName: switch (role) {
        AppRole.staff ||
        AppRole.spv ||
        AppRole.areaManager =>
          AppRole.management.mockUserName,
        _ => null,
      },
      leaveBalanceDays: role.defaultLeaveBalanceDays,
    )));
  }

  void logout() {
    unawaited(_logoutAsync());
  }

  List<NetworkEntry> ownNetworkEntriesForSession(AppSession session) {
    if (session.role != AppRole.fgg &&
        session.role != AppRole.areaManager &&
        session.role != AppRole.management) {
      return const [];
    }

    return List.unmodifiable(
        _networkEntriesByOwner[session.ownerKey] ?? const []);
  }

  List<NetworkEntry> teamUkmEntriesForAreaManager(AppSession session) {
    if (session.role != AppRole.areaManager) {
      return const [];
    }

    return List.unmodifiable(
      _teamUkmEntriesByAreaManager[session.ownerKey] ?? const [],
    );
  }

  List<AttendanceRecord> attendanceRecordsForSession(AppSession session) {
    return List.unmodifiable(
        _attendanceRecordsByOwner[session.ownerKey] ?? const []);
  }

  PerformanceSummary? performanceSummaryForSession(AppSession session) {
    if (session.role != AppRole.fgg && session.role != AppRole.areaManager) {
      return null;
    }

    return _performanceSummaryByOwner[session.ownerKey];
  }

  FaceProfile faceProfileForSession(AppSession session) {
    return _faceProfilesByOwner[session.ownerKey] ??
        FaceProfile.empty(userId: _workflowUserIdForSession(session));
  }

  List<Announcement> get announcements => List.unmodifiable(_announcements);
  SurveyOptions get surveyOptions => _surveyOptions ?? SurveyOptions.fallback;

  bool hasFaceEnrollmentForSession(AppSession session) {
    final cachedProfile = _faceProfilesByOwner[session.ownerKey];
    if (cachedProfile != null) {
      return cachedProfile.isEnrolled && cachedProfile.biometricTemplateReady;
    }

    return session.hasFaceEnrollment;
  }

  Future<List<TerritoryOption>> territoryProvinces() async {
    final cached = _territoryProvinceCache;
    if (cached != null) {
      return cached;
    }

    final provinces = await _territoryRepository.listProvinces();
    _territoryProvinceCache = provinces;
    return provinces;
  }

  Future<List<TerritoryOption>> territoryCities(String provinceCode) async {
    final cached = _territoryCityCache[provinceCode];
    if (cached != null) {
      return cached;
    }

    final cities = await _territoryRepository.listCities(
      provinceCode: provinceCode,
    );
    _territoryCityCache[provinceCode] = cities;
    return cities;
  }

  Future<List<TerritoryOption>> territoryDistricts(String cityCode) async {
    final cached = _territoryDistrictCache[cityCode];
    if (cached != null) {
      return cached;
    }

    final districts = await _territoryRepository.listDistricts(
      cityCode: cityCode,
    );
    _territoryDistrictCache[cityCode] = districts;
    return districts;
  }

  Future<List<TerritoryOption>> territorySubdistricts(
      String districtCode) async {
    final cached = _territorySubdistrictCache[districtCode];
    if (cached != null) {
      return cached;
    }

    final subdistricts = await _territoryRepository.listSubdistricts(
      districtCode: districtCode,
    );
    _territorySubdistrictCache[districtCode] = subdistricts;
    return subdistricts;
  }

  Future<void> createAttendanceRecord(
    AppSession session,
    AttendanceRecord record,
  ) async {
    final resolvedRecord = AttendanceRecord(
      id: record.id,
      userId: _workflowUserIdForSession(session),
      workDate: record.workDate,
      action: record.action,
      status: record.status,
      recordedAt: record.recordedAt,
      location: record.location,
      metadata: record.metadata,
      verification: record.verification,
      note: record.note,
    );
    await _attendanceRepository.createRecord(resolvedRecord);
    await _loadAttendanceData(session);
  }

  Future<void> resetAttendanceRecordsForSession(AppSession session) async {
    await _attendanceRepository.clearByUser(
      userId: _workflowUserIdForSession(session),
    );
    await _loadAttendanceData(session);
  }

  Future<FaceProfile> enrollFaceForSession(
    AppSession session, {
    required List<String> samplePaths,
  }) async {
    final biometricTemplate =
        await _faceBiometricAnalyzer.buildEnrollmentTemplate(samplePaths);
    if (biometricTemplate.template.length < 64) {
      throw StateError(
        'Template wajah belum lengkap. Ulangi scan wajah dengan pencahayaan yang lebih jelas.',
      );
    }

    final uploadedSamples = <RemoteAttachment>[];
    for (var index = 0; index < samplePaths.length; index++) {
      final samplePath = samplePaths[index];
      final attachment = await _uploadAttachmentIfNeeded(
        filePath: samplePath,
        label: 'Face Sample ${index + 1}',
      );
      if (attachment != null) {
        uploadedSamples.add(attachment);
      }
    }
    if (uploadedSamples.length < 3) {
      throw StateError(
        'Minimal 3 foto wajah harus berhasil diupload. Periksa koneksi lalu ulangi daftar wajah.',
      );
    }

    final profile = await _faceProfileRepository.enroll(
      samples: uploadedSamples,
      biometricTemplate: biometricTemplate.template,
      note:
          'Enrollment wajah diperbarui dari aplikasi mobile dengan lightweight signature v2.',
    );
    _faceProfilesByOwner[session.ownerKey] = profile;
    _session = _session?.copyWith(
      faceEnrollmentStatus: profile.status,
      faceSamplesCount: profile.samplesCount,
    );
    notifyListeners();
    return profile;
  }

  Future<FaceVerificationResult> verifyFaceForSession(
    AppSession session, {
    required String action,
    required String capturePath,
    double livenessScore = 100,
  }) async {
    final analyzedCapture =
        await _faceBiometricAnalyzer.analyzeCapture(capturePath);
    final uploadedCapture = await _uploadAttachmentIfNeeded(
      filePath: capturePath,
      label: 'Face $action ${DateTime.now().toIso8601String()}',
    );
    if (uploadedCapture == null) {
      throw StateError('Capture wajah tidak berhasil diunggah.');
    }

    final result = await _faceProfileRepository.verify(
      action: action,
      capture: uploadedCapture,
      signature: analyzedCapture.signature,
      livenessScore: livenessScore,
      note: 'Verifikasi wajah dipicu dari flow absensi mobile (signature v2).',
    );
    _faceProfilesByOwner[session.ownerKey] = result.profile;
    _session = _session?.copyWith(
      faceEnrollmentStatus: result.profile.status,
      faceSamplesCount: result.profile.samplesCount,
    );
    notifyListeners();
    return result;
  }

  Future<RemoteAttachment> uploadAttachment({
    required String filePath,
    required String label,
  }) async {
    final attachment = await _uploadAttachmentIfNeeded(
      filePath: filePath,
      label: label,
    );
    if (attachment == null) {
      throw StateError('Lampiran tidak berhasil diunggah.');
    }
    return attachment;
  }

  Future<void> updateProfilePhotoForSession(
    AppSession session, {
    required String filePath,
  }) async {
    final attachment = await _uploadAttachmentIfNeeded(
      filePath: filePath,
      label: 'Foto Profil ${session.userName}',
    );
    if (attachment == null) {
      throw StateError('Foto profil tidak berhasil diunggah.');
    }

    final authRepository = _authRepository;
    if (_useRemoteAuth && authRepository != null) {
      final user = await authRepository.updateProfilePhoto(attachment);
      _session = AppSession.fromUser(user);
    } else {
      _session = _session?.copyWith(profilePhoto: attachment);
    }

    notifyListeners();
  }

  Future<void> deleteProfilePhotoForSession(AppSession session) async {
    final authRepository = _authRepository;
    if (_useRemoteAuth && authRepository != null) {
      final user = await authRepository.deleteProfilePhoto();
      _session = AppSession.fromUser(user);
    } else {
      _session = _session?.withProfilePhoto(null);
    }

    notifyListeners();
  }

  Future<void> upsertNetworkEntryForSession(
    AppSession session,
    NetworkEntry entry,
  ) async {
    final uploadedPhoto = await _uploadAttachmentIfNeeded(
      filePath: entry.photoPath,
      label: '${entry.type.shortLabel} ${entry.name}',
    );
    final resolvedEntry = uploadedPhoto == null
        ? entry
        : entry.copyWith(photoPath: uploadedPhoto.url);

    final storedProfile = await _networkRepository.upsert(
      resolvedEntry.toNetworkProfile(
        ownerId: _workflowUserIdForSession(session),
      ),
    );
    if (resolvedEntry.latitude != null &&
        resolvedEntry.longitude != null &&
        (storedProfile.latitude == null || storedProfile.longitude == null)) {
      throw StateError(
        'Koordinat belum ikut tersimpan di server. Pastikan izin lokasi aktif lalu coba lagi.',
      );
    }
    await _refreshNetworkCachesAfterMutation(
      session: session,
      ownerRole: storedProfile.ownerRole,
    );
  }

  Future<void> refreshNetworkDataForSession(AppSession session) async {
    await _loadNetworkEntries(session);
  }

  Future<void> refreshSurveyOptions() async {
    _surveyOptions = await _surveyRepository.loadOptions();
    notifyListeners();
  }

  Future<void> submitKioskSurvey({
    required AppSession session,
    required String photoPath,
    required String territoryProvince,
    required String territoryCity,
    required String territoryDistrict,
    required String territorySubdistrict,
    required String kioskName,
    required String phoneNumber,
    required String ownerName,
    required List<String> productIds,
    required String otherProduct,
    required List<String> buildingTypes,
    required List<String> kioskSizes,
  }) async {
    final photo = await uploadAttachment(
      filePath: photoPath,
      label: 'Survey Kios $kioskName',
    );

    await _surveyRepository.submitKioskSurvey(
      KioskSurveySubmission(
        photo: photo,
        territoryProvince: territoryProvince,
        territoryCity: territoryCity,
        territoryDistrict: territoryDistrict,
        territorySubdistrict: territorySubdistrict,
        kioskName: kioskName,
        phoneNumber: phoneNumber,
        ownerName: ownerName,
        productIds: productIds,
        otherProduct: otherProduct,
        buildingTypes: buildingTypes,
        kioskSizes: kioskSizes,
      ),
    );
  }

  Future<void> submitPriceSurvey({
    required AppSession session,
    required String photoPath,
    required String marketName,
    required String territoryProvince,
    required String territoryCity,
    required String territoryDistrict,
    required String territorySubdistrict,
    required List<CommodityPriceSubmission> commodityPrices,
  }) async {
    final photo = await uploadAttachment(
      filePath: photoPath,
      label: 'Survey Harga $marketName',
    );

    await _surveyRepository.submitPriceSurvey(
      PriceSurveySubmission(
        photo: photo,
        marketName: marketName,
        territoryProvince: territoryProvince,
        territoryCity: territoryCity,
        territoryDistrict: territoryDistrict,
        territorySubdistrict: territorySubdistrict,
        commodityPrices: commodityPrices,
      ),
    );
  }

  Future<void> refreshPerformanceSummaryForSession(AppSession session) async {
    await _loadPerformanceSummary(session);
  }

  Future<void> refreshAttendanceDataForSession(AppSession session) async {
    await Future.wait([
      refreshCurrentUserProfile(),
      _loadAttendanceData(session),
      _loadFaceProfileData(session),
    ]);
  }

  Future<void> refreshWorkflowDataForSession(AppSession session) async {
    await Future.wait([
      refreshCurrentUserProfile(),
      _loadWorkflowData(session),
    ]);
  }

  Future<void> refreshProfileDataForSession(AppSession session) async {
    await Future.wait([
      refreshCurrentUserProfile(),
      _loadWorkflowData(session),
      _loadFaceProfileData(session),
    ]);
  }

  Future<void> refreshHomeDataForSession(AppSession session) async {
    await Future.wait([
      refreshCurrentUserProfile(),
      _loadAttendanceData(session),
      _loadWorkflowData(session),
      _loadAnnouncements(),
      if (session.role == AppRole.fgg ||
          session.role == AppRole.areaManager ||
          session.role == AppRole.management)
        _loadNetworkEntries(session),
      if (session.role == AppRole.fgg || session.role == AppRole.areaManager)
        _loadPerformanceSummary(session),
    ]);
  }

  Future<void> refreshCurrentSessionData([AppSession? targetSession]) async {
    final session = targetSession ?? _session;
    if (session == null) {
      return;
    }

    await Future.wait([
      refreshCurrentUserProfile(),
      _loadAttendanceData(session),
      _loadFaceProfileData(session),
      _loadWorkflowData(session),
      _loadAnnouncements(),
      if (session.role == AppRole.fgg ||
          session.role == AppRole.areaManager ||
          session.role == AppRole.management)
        _loadNetworkEntries(session),
      if (session.role == AppRole.fgg || session.role == AppRole.areaManager)
        _loadPerformanceSummary(session),
    ]);
  }

  Future<void> _loadAttendanceData(AppSession session) async {
    _attendanceRecordsByOwner[session.ownerKey] =
        await _attendanceRepository.listByUser(
      userId: _workflowUserIdForSession(session),
    );
    notifyListeners();
  }

  Future<void> _loadAnnouncements() async {
    _announcements = await _announcementRepository.listActive();
    notifyListeners();
  }

  List<leave_model.LeaveRequestRecord> leaveRequestsForSession(
      AppSession session) {
    return List.unmodifiable(
        _leaveRequestsByOwner[session.ownerKey] ?? const []);
  }

  List<wfa_model.WfaRequestRecord> wfaRequestsForSession(AppSession session) {
    return List.unmodifiable(_wfaRequestsByOwner[session.ownerKey] ?? const []);
  }

  double leaveBalanceDaysForSession(AppSession session) {
    return _leaveBalanceByUserId[_workflowUserIdForSession(session)] ??
        session.leaveBalanceDays;
  }

  List<leave_model.LeaveRequestRecord> leaveApprovalsForSession(
      AppSession session) {
    if (session.role != AppRole.spv && session.role != AppRole.management) {
      return const [];
    }

    return List.unmodifiable(
      _leaveApprovalRequestsByApprover[session.ownerKey] ?? const [],
    );
  }

  List<wfa_model.WfaRequestRecord> wfaApprovalsForSession(AppSession session) {
    if (session.role != AppRole.spv && session.role != AppRole.management) {
      return const [];
    }

    return List.unmodifiable(
      _wfaApprovalRequestsByApprover[session.ownerKey] ?? const [],
    );
  }

  Future<void> submitLeaveRequest(
      AppSession session, leave_model.LeaveRequestRecord request,
      {String? evidencePath}) async {
    final uploadedAttachment = await _uploadAttachmentIfNeeded(
      filePath: evidencePath,
      label:
          'Leave ${request.category.name} ${DateTime.now().toIso8601String()}',
    );
    final resolvedRequest = request.copyWith(
      requesterId: _workflowUserIdForSession(session),
      requesterName: _workflowUserNameForSession(session),
      attachments: uploadedAttachment == null
          ? request.attachments
          : [uploadedAttachment],
    );
    if (_usesLeaveBalance(resolvedRequest) &&
        resolvedRequest.durationValue > leaveBalanceDaysForSession(session)) {
      throw StateError('Saldo cuti tidak mencukupi untuk pengajuan ini.');
    }
    await _leaveRepository.submit(
      resolvedRequest,
    );
    if (!_useRemoteAuth) {
      _consumeLeaveBalanceIfNeeded(
        userId: _workflowUserIdForSession(session),
        role: session.role,
        request: resolvedRequest,
      );
    }
    await _loadWorkflowData(session);
    await _refreshWorkflowForLeaveParticipants(resolvedRequest);
    await refreshCurrentUserProfile();
  }

  Future<void> submitWfaRequest(
    AppSession session,
    wfa_model.WfaRequestRecord request,
  ) async {
    final resolvedRequest = request.copyWith(
      requesterId: _workflowUserIdForSession(session),
      requesterName: _workflowUserNameForSession(session),
    );
    await _wfaRepository.submit(
      resolvedRequest,
    );
    await _loadWorkflowData(session);
    await _refreshWorkflowForWfaParticipants(resolvedRequest);
  }

  Future<void> approveLeaveRequest(
    AppSession session, {
    required String requestId,
    String? note,
  }) async {
    final request = _findLeaveRequestById(requestId);
    await _approvalRepository.approve(
      approvalId: 'leave::$requestId',
      approverId: _workflowUserIdForSession(session),
      approverName: _workflowUserNameForSession(session),
      note: note,
    );
    await _loadWorkflowData(session);
    if (request != null) {
      await _refreshWorkflowForLeaveParticipants(request);
    }
  }

  Future<void> rejectLeaveRequest(
    AppSession session, {
    required String requestId,
    String? note,
  }) async {
    final request = _findLeaveRequestById(requestId);
    await _approvalRepository.reject(
      approvalId: 'leave::$requestId',
      approverId: _workflowUserIdForSession(session),
      approverName: _workflowUserNameForSession(session),
      note: note,
    );
    if (request != null) {
      if (!_useRemoteAuth) {
        _restoreLeaveBalanceIfNeeded(request);
      }
      await _refreshWorkflowForLeaveParticipants(request);
    }
    await _loadWorkflowData(session);
    await refreshCurrentUserProfile();
  }

  Future<void> approveWfaRequest(
    AppSession session, {
    required String requestId,
    String? note,
  }) async {
    final request = _findWfaRequestById(requestId);
    await _approvalRepository.approve(
      approvalId: 'wfa::$requestId',
      approverId: _workflowUserIdForSession(session),
      approverName: _workflowUserNameForSession(session),
      note: note,
    );
    await _loadWorkflowData(session);
    if (request != null) {
      await _refreshWorkflowForWfaParticipants(request);
    }
  }

  Future<void> rejectWfaRequest(
    AppSession session, {
    required String requestId,
    String? note,
  }) async {
    final request = _findWfaRequestById(requestId);
    await _approvalRepository.reject(
      approvalId: 'wfa::$requestId',
      approverId: _workflowUserIdForSession(session),
      approverName: _workflowUserNameForSession(session),
      note: note,
    );
    await _loadWorkflowData(session);
    if (request != null) {
      await _refreshWorkflowForWfaParticipants(request);
    }
  }

  Future<void> startWfaSession(
    AppSession session, {
    required wfa_model.WfaRequestRecord request,
  }) async {
    final now = DateTime.now();
    await _wfaRepository.updateStatus(
      requestId: request.id,
      status: wfa_model.WorkflowStatus.active,
      actualStartAt: now,
      note: request.mode == wfa_model.WfaRequestMode.overtime
          ? 'Sesi overtime dimulai sesuai approval.'
          : 'Sesi WFA dimulai sesuai approval.',
    );
    await _wfaRepository.appendTaskUpdate(
      requestId: request.id,
      update: wfa_model.WfaTaskUpdateRecord(
        id: '${request.id}-start-${now.microsecondsSinceEpoch}',
        message: request.mode == wfa_model.WfaRequestMode.overtime
            ? 'Sesi overtime dimulai sesuai approval.'
            : 'Sesi WFA dimulai sesuai approval.',
        createdAt: now,
        actorId: _workflowUserIdForSession(session),
      ),
    );
    await _loadWorkflowData(session);
  }

  Future<void> appendWfaTaskUpdate(
    AppSession session, {
    required String requestId,
    required String message,
    String? attachmentPath,
    String? attachmentLabel,
  }) async {
    final now = DateTime.now();
    final uploadedAttachment = await _uploadAttachmentIfNeeded(
      filePath: attachmentPath,
      label: attachmentLabel ?? 'Lampiran aktivitas',
    );
    final attachments = uploadedAttachment == null
        ? const <RemoteAttachment>[]
        : [uploadedAttachment];

    await _wfaRepository.appendTaskUpdate(
      requestId: requestId,
      update: wfa_model.WfaTaskUpdateRecord(
        id: '$requestId-update-${now.microsecondsSinceEpoch}',
        message: message,
        createdAt: now,
        actorId: _workflowUserIdForSession(session),
        attachments: attachments,
      ),
    );
    await _loadWorkflowData(session);
  }

  Future<void> finishWfaSession(
    AppSession session, {
    required wfa_model.WfaRequestRecord request,
  }) async {
    final now = DateTime.now();
    await _wfaRepository.updateStatus(
      requestId: request.id,
      status: wfa_model.WorkflowStatus.completed,
      actualEndAt: now,
      note: request.mode == wfa_model.WfaRequestMode.overtime
          ? 'Sesi overtime selesai dan siap direview untuk kompensasi.'
          : 'Sesi WFA selesai dengan output akhir tercatat.',
    );
    await _wfaRepository.appendTaskUpdate(
      requestId: request.id,
      update: wfa_model.WfaTaskUpdateRecord(
        id: '${request.id}-finish-${now.microsecondsSinceEpoch}',
        message: request.mode == wfa_model.WfaRequestMode.overtime
            ? 'Sesi overtime selesai dan siap direview untuk kompensasi.'
            : 'Sesi WFA selesai dengan output akhir tercatat.',
        createdAt: now,
        actorId: _workflowUserIdForSession(session),
      ),
    );
    await _loadWorkflowData(session);
  }

  Future<void> resetWorkflowMocksForSession(AppSession session) async {
    await _seedDemoWorkflowRequestsAsync(force: true);
    await _loadWorkflowData(session);
  }

  Future<void> deleteNetworkEntryForSession(
    AppSession session,
    String entryId,
  ) async {
    final ownEntries = _networkEntriesByOwner[session.ownerKey] ?? const [];
    final targetEntry = ownEntries.cast<NetworkEntry?>().firstWhere(
          (item) => item?.id == entryId,
          orElse: () => null,
        );
    await _networkRepository.delete(entryId);
    await _refreshNetworkCachesAfterMutation(
      session: session,
      ownerRole: targetEntry?.ownerRole ?? session.role,
    );
  }

  Future<void> addFollowUpToEntry({
    required NetworkEntry entry,
    required NetworkFollowUp followUp,
    String? status,
    Color? statusColor,
  }) async {
    final activeSession = _session;
    final profile = await _networkRepository.appendFollowUp(
      profileId: entry.id,
      nextStatus: _profileStatusFromLabel(status ?? entry.status),
      followUp: NetworkFollowUpRecord(
        id: followUp.id ??
            '${entry.id}-${followUp.createdAt.microsecondsSinceEpoch}',
        title: followUp.title,
        note: followUp.note,
        actorId: activeSession == null
            ? entry.ownerKey
            : _workflowUserIdForSession(activeSession),
        actorName: followUp.actorName,
        createdAt: followUp.createdAt,
      ),
    );
    _replaceEntryInVisibleCaches(profile.toNetworkEntry());
    if (activeSession != null) {
      await _refreshNetworkCachesAfterMutation(
        session: activeSession,
        ownerRole: profile.ownerRole,
      );
    } else {
      notifyListeners();
    }
  }

  Future<void> _loadWorkflowData(AppSession session) async {
    await _ensureWorkflowSeedForSession(session);
    _leaveBalanceByUserId.putIfAbsent(
      _workflowUserIdForSession(session),
      () => session.leaveBalanceDays,
    );

    _leaveRequestsByOwner[session.ownerKey] = await _leaveRepository.listByUser(
      userId: _workflowUserIdForSession(session),
    );
    _wfaRequestsByOwner[session.ownerKey] = await _wfaRepository.listByUser(
      userId: _workflowUserIdForSession(session),
    );

    if (session.role == AppRole.spv || session.role == AppRole.management) {
      _leaveApprovalRequestsByApprover[session.ownerKey] =
          await _leaveRepository.listForApprover(
        approverId: _workflowUserIdForSession(session),
      );
      _wfaApprovalRequestsByApprover[session.ownerKey] =
          await _wfaRepository.listForApprover(
        approverId: _workflowUserIdForSession(session),
      );
    } else {
      _leaveApprovalRequestsByApprover[session.ownerKey] = const [];
      _wfaApprovalRequestsByApprover[session.ownerKey] = const [];
    }

    notifyListeners();
  }

  Future<void> _loadFaceProfileData(AppSession session) async {
    final profile = await _faceProfileRepository.currentProfile();
    _faceProfilesByOwner[session.ownerKey] = profile;
    _session = _session?.copyWith(
      faceEnrollmentStatus: profile.status,
      faceSamplesCount: profile.samplesCount,
    );
    notifyListeners();
  }

  Future<void> _ensureWorkflowSeedForSession(AppSession session) async {
    if (!_seedWorkflowDemoData) {
      return;
    }

    final existingLeave = await _leaveRepository.listByUser(
      userId: session.ownerKey,
    );
    if (existingLeave.isEmpty) {
      for (final request in _seedOwnLeaveRecords(session)) {
        await _leaveRepository.submit(request);
      }
    }

    final existingWfa = await _wfaRepository.listByUser(
      userId: session.ownerKey,
    );
    if (existingWfa.isEmpty) {
      for (final request in _seedOwnWfaRecords(session)) {
        await _wfaRepository.submit(request);
      }
    }
  }

  Future<void> _loadNetworkEntries(AppSession session) async {
    await _ensureSeedForSession(session);

    final ownProfiles = await _networkRepository.listOwnedByUser(
      userId: _workflowUserIdForSession(session),
    );
    _networkEntriesByOwner[session.ownerKey] =
        ownProfiles.map((item) => item.toNetworkEntry()).toList();

    if (session.role == AppRole.areaManager) {
      final teamProfiles = await _networkRepository.listTeamUkm(
        areaManagerId: _workflowUserIdForSession(session),
      );
      _teamUkmEntriesByAreaManager[session.ownerKey] =
          teamProfiles.map((item) => item.toNetworkEntry()).toList();
    }

    notifyListeners();
  }

  Future<void> _loadPerformanceSummary(AppSession session) async {
    if (session.role != AppRole.fgg && session.role != AppRole.areaManager) {
      _performanceSummaryByOwner.remove(session.ownerKey);
      notifyListeners();
      return;
    }

    final summary =
        await _performanceRepository.currentSummary(session: session);
    _performanceSummaryByOwner[session.ownerKey] = summary;
    notifyListeners();
  }

  Future<void> _refreshNetworkCachesAfterMutation({
    required AppSession session,
    required AppRole ownerRole,
  }) async {
    await _loadNetworkEntries(session);
    await _loadPerformanceSummary(session);
    if (ownerRole == AppRole.fgg) {
      await _refreshTeamUkmCaches();
    }
    notifyListeners();
  }

  Future<void> _refreshTeamUkmCaches() async {
    final cachedAreaManagerKeys = _teamUkmEntriesByAreaManager.keys.toList();
    for (final areaManagerKey in cachedAreaManagerKeys) {
      final teamProfiles = await _networkRepository.listTeamUkm(
        areaManagerId: areaManagerKey,
      );
      _teamUkmEntriesByAreaManager[areaManagerKey] =
          teamProfiles.map((item) => item.toNetworkEntry()).toList();
    }
  }

  void _replaceEntryInVisibleCaches(NetworkEntry updatedEntry) {
    for (final entries in _networkEntriesByOwner.values) {
      final index = entries.indexWhere((item) => item.id == updatedEntry.id);
      if (index != -1) {
        entries[index] = updatedEntry;
      }
    }
    for (final entries in _teamUkmEntriesByAreaManager.values) {
      final index = entries.indexWhere((item) => item.id == updatedEntry.id);
      if (index != -1) {
        entries[index] = updatedEntry;
      }
    }
  }

  Future<void> _ensureSeedForSession(AppSession session) async {
    if (_useRemoteAuth) {
      return;
    }

    final existing = await _networkRepository.listOwnedByUser(
      userId: _workflowUserIdForSession(session),
    );
    if (existing.isNotEmpty) {
      return;
    }

    for (final profile in _seedOwnNetworkProfiles(session)) {
      await _networkRepository.upsert(profile);
    }
  }

  List<NetworkProfile> _seedOwnNetworkProfiles(AppSession session) {
    switch (session.role) {
      case AppRole.areaManager:
        return [
          NetworkEntry.mock(
            ownerKey: session.ownerKey,
            ownerName: session.userName,
            ownerRole: session.role,
            type: NetworkEntryType.ukm,
            name: 'UKM Pasar Lenteng',
            address: 'Lenteng Agung',
            businessType: 'Kuliner',
            phone: '081234567890',
            status: 'Follow-up',
            statusColor: Colors.orange,
            followUps: [
              NetworkFollowUp(
                title: 'Kunjungan awal',
                note: 'Butuh verifikasi omset dan jam buka toko.',
                actorName: session.userName,
                createdAt: DateTime.now().subtract(const Duration(days: 1)),
              ),
            ],
          ).toNetworkProfile(ownerId: session.ownerKey),
          NetworkEntry.mock(
            ownerKey: session.ownerKey,
            ownerName: session.userName,
            ownerRole: session.role,
            type: NetworkEntryType.mitraHub,
            name: 'Mitra Hub Budi Jaya',
            address: 'Jagakarsa',
            businessType: 'Gudang dan distribusi',
            phone: '081298765432',
            reference: session.userName,
            status: 'Lengkap',
            statusColor: Colors.green,
            personalityScore: 78,
            followUps: [
              NetworkFollowUp(
                title: 'Dokumen dicek',
                note: 'Dokumen survey lokasi sudah lengkap.',
                actorName: session.userName,
                createdAt: DateTime.now().subtract(const Duration(hours: 6)),
              ),
            ],
          ).toNetworkProfile(ownerId: session.ownerKey),
        ];
      case AppRole.fgg:
        return [
          NetworkEntry.mock(
            ownerKey: session.ownerKey,
            ownerName: session.userName,
            ownerRole: session.role,
            type: NetworkEntryType.ukm,
            name: 'UKM Toko Harapan',
            address: 'Pasar Minggu',
            businessType: 'Sembako',
            phone: '081234567890',
            status: 'Draft',
            statusColor: Colors.teal,
            followUps: [
              NetworkFollowUp(
                title: 'Input awal',
                note: 'Data dasar UKM sudah masuk dari kunjungan pertama.',
                actorName: session.userName,
                createdAt: DateTime.now().subtract(const Duration(hours: 4)),
              ),
            ],
          ).toNetworkProfile(ownerId: session.ownerKey),
        ];
      default:
        return [];
    }
  }

  void _seedDemoFggEntries() {
    final demoSessions = [
      AppSession.mock(AppRole.fgg, userName: 'Bima FGG'),
      AppSession.mock(AppRole.fgg, userName: 'Reno FGG'),
    ];

    unawaited(_seedDemoFggEntriesAsync(demoSessions));
  }

  void _seedDemoWorkflowRequests() {
    unawaited(_seedDemoWorkflowRequestsAsync());
  }

  Future<void> _seedDemoWorkflowRequestsAsync({
    bool force = false,
  }) async {
    final nadiaSession =
        AppSession.mock(AppRole.staff, userName: 'Nadia Staff');
    final bagasSession = AppSession.mock(AppRole.spv, userName: 'Bagas SPV');
    final rakaSession = AppSession.mock(
      AppRole.areaManager,
      userName: 'Raka Area Manager',
    );

    final leaveSeeds = [
      _buildLeaveRecord(
        session: nadiaSession,
        id: 'leave-seed-nadia-approved',
        category: leave_model.LeaveCategory.izinPerHari,
        compensation: leave_model.LeaveCompensationOption.tidakPotongGaji,
        startAt: DateTime(2026, 4, 11),
        endAt: DateTime(2026, 4, 11),
        durationValue: 1,
        reason: 'Kontrol kesehatan keluarga',
        delegateTo: 'Rani',
        status: leave_model.WorkflowStatus.approved,
        note: 'Izin harian sudah disetujui dan delegasi ke Rani.',
      ),
      _buildLeaveRecord(
        session: nadiaSession,
        id: 'leave-seed-nadia-pending',
        category: leave_model.LeaveCategory.izinPerHari,
        compensation: leave_model.LeaveCompensationOption.tidakPotongGaji,
        startAt: DateTime(2026, 4, 24),
        endAt: DateTime(2026, 4, 25),
        durationValue: 2,
        reason: 'Keperluan keluarga',
        delegateTo: 'Dian Pratama',
        status: leave_model.WorkflowStatus.pending,
        note: 'Pengajuan staff menunggu approval SPV lalu Management.',
      ),
      _buildLeaveRecord(
        session: bagasSession,
        id: 'leave-seed-bagas-pending',
        category: leave_model.LeaveCategory.sakit,
        compensation: leave_model.LeaveCompensationOption.tidakPotongGaji,
        startAt: DateTime(2026, 4, 29),
        endAt: DateTime(2026, 4, 29),
        durationValue: 1,
        reason: 'Izin keperluan medis',
        delegateTo: 'Sari',
        status: leave_model.WorkflowStatus.pending,
        note: 'Pengajuan SPV menunggu approval Management.',
      ),
      _buildLeaveRecord(
        session: rakaSession,
        id: 'leave-seed-raka-pending',
        category: leave_model.LeaveCategory.cuti,
        compensation: leave_model.LeaveCompensationOption.potongSaldoCuti,
        startAt: DateTime(2026, 5, 2),
        endAt: DateTime(2026, 5, 2),
        durationValue: 1,
        reason: 'Acara keluarga inti',
        delegateTo: 'Area backup tim selatan',
        status: leave_model.WorkflowStatus.pending,
        note: 'Pengajuan Area Manager menunggu approval Management.',
      ),
    ];

    final wfaSeeds = [
      _buildWfaRecord(
        session: nadiaSession,
        id: 'wfa-seed-nadia-approved',
        mode: wfa_model.WfaRequestMode.regular,
        compensation: wfa_model.WfaCompensationMode.normalShift,
        workDate: DateTime(2026, 4, 24),
        startTime: '08:30',
        endTime: '17:00',
        location: 'Rumah - Jakarta Selatan',
        reason:
            'Fokus koordinasi laporan dan follow-up vendor dari luar kantor.',
        initialTask: 'Review pipeline area, follow-up vendor, dan daily sync.',
        status: wfa_model.WorkflowStatus.approved,
        note:
            'WFA reguler disetujui untuk jam kerja utama dengan output harian wajib ter-update.',
      ),
      _buildWfaRecord(
        session: nadiaSession,
        id: 'wfa-seed-nadia-pending-regular',
        mode: wfa_model.WfaRequestMode.regular,
        compensation: wfa_model.WfaCompensationMode.normalShift,
        workDate: DateTime(2026, 4, 24),
        startTime: '08:30',
        endTime: '17:00',
        location: 'Rumah - Depok',
        reason: 'Menyelesaikan laporan bulanan dari luar kantor.',
        initialTask: 'Review laporan, koordinasi vendor, dan follow-up WA.',
        status: wfa_model.WorkflowStatus.pending,
        note: 'Menunggu persetujuan SPV sebelum diteruskan ke management.',
      ),
      _buildWfaRecord(
        session: nadiaSession,
        id: 'wfa-seed-nadia-pending-overtime',
        mode: wfa_model.WfaRequestMode.overtime,
        compensation: wfa_model.WfaCompensationMode.shiftMundur,
        workDate: DateTime(2026, 4, 24),
        startTime: '19:30',
        endTime: '21:00',
        location: 'Online meeting dari rumah',
        reason: 'Meeting malam dengan mitra regional.',
        initialTask: 'Presentasi progres dan follow-up hasil meeting malam.',
        status: wfa_model.WorkflowStatus.pending,
        note:
            'Jika disetujui, pengajuan ini akan ikut tercatat untuk kompensasi esok hari.',
      ),
      _buildWfaRecord(
        session: bagasSession,
        id: 'wfa-seed-bagas-pending',
        mode: wfa_model.WfaRequestMode.overtime,
        compensation: wfa_model.WfaCompensationMode.klaimLembur,
        workDate: DateTime(2026, 4, 24),
        startTime: '20:00',
        endTime: '22:00',
        location: 'Zoom call dari rumah',
        reason: 'Meeting evaluasi performa malam hari dengan pihak eksternal.',
        initialTask: 'Paparan hasil evaluasi dan tindak lanjut meeting.',
        status: wfa_model.WorkflowStatus.pending,
        note:
            'Overtime SPV menunggu approval management untuk kompensasi akhir.',
      ),
      _buildWfaRecord(
        session: rakaSession,
        id: 'wfa-seed-raka-pending',
        mode: wfa_model.WfaRequestMode.overtime,
        compensation: wfa_model.WfaCompensationMode.shiftMundur,
        workDate: DateTime(2026, 4, 25),
        startTime: '19:00',
        endTime: '21:30',
        location: 'Meeting hybrid area barat',
        reason: 'Koordinasi malam dengan tim area dan partner.',
        initialTask: 'Review target area dan tindak lanjut operasional.',
        status: wfa_model.WorkflowStatus.pending,
        note: 'Disiapkan sebagai simulasi approval overtime Area Manager.',
      ),
    ];

    for (final request in leaveSeeds) {
      final shouldWrite = force ||
          (await _leaveRepository.listByUser(userId: request.requesterId))
              .where((item) => item.id == request.id)
              .isEmpty;
      if (shouldWrite) {
        await _leaveRepository.submit(request);
      }
    }

    for (final request in wfaSeeds) {
      final shouldWrite = force ||
          (await _wfaRepository.listByUser(userId: request.requesterId))
              .where((item) => item.id == request.id)
              .isEmpty;
      if (shouldWrite) {
        await _wfaRepository.submit(request);
      }
    }
  }

  Future<void> _seedDemoFggEntriesAsync(List<AppSession> demoSessions) async {
    for (final session in demoSessions) {
      final existing = await _networkRepository.listOwnedByUser(
        userId: _workflowUserIdForSession(session),
      );
      if (existing.isNotEmpty) {
        continue;
      }

      final profile = NetworkEntry.mock(
        ownerKey: session.ownerKey,
        ownerName: session.userName,
        ownerRole: session.role,
        type: NetworkEntryType.ukm,
        name: session.userName == 'Bima FGG'
            ? 'UKM Sumber Rejeki'
            : 'UKM Kopi Melati',
        address: session.userName == 'Bima FGG' ? 'Cilandak' : 'Lenteng Agung',
        businessType: session.userName == 'Bima FGG' ? 'Sembako' : 'Minuman',
        phone: session.userName == 'Bima FGG' ? '081288889999' : '081377778888',
        status: 'Follow-up',
        statusColor: Colors.orange,
        followUps: [
          NetworkFollowUp(
            title: 'Visit lapangan',
            note: session.userName == 'Bima FGG'
                ? 'Pemilik toko minta follow-up stok minggu depan.'
                : 'Pemilik tertarik lanjut, perlu validasi foto toko.',
            actorName: session.userName,
            createdAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
        ],
      ).toNetworkProfile(ownerId: _workflowUserIdForSession(session));

      await _networkRepository.upsert(profile);
    }
  }

  List<leave_model.LeaveRequestRecord> _seedOwnLeaveRecords(
      AppSession session) {
    switch (session.role) {
      case AppRole.staff:
        return [
          _buildLeaveRecord(
            session: session,
            id: '${session.ownerKey}-leave-approved',
            category: leave_model.LeaveCategory.izinPerHari,
            compensation: leave_model.LeaveCompensationOption.tidakPotongGaji,
            startAt: DateTime(2026, 4, 11),
            endAt: DateTime(2026, 4, 11),
            durationValue: 1,
            reason: 'Kontrol kesehatan keluarga',
            delegateTo: 'Rani',
            status: leave_model.WorkflowStatus.approved,
            note: 'Izin harian sudah disetujui dan delegasi ke Rani.',
          ),
        ];
      case AppRole.spv:
      case AppRole.areaManager:
        return [
          _buildLeaveRecord(
            session: session,
            id: '${session.ownerKey}-leave-approved',
            category: leave_model.LeaveCategory.cuti,
            compensation: leave_model.LeaveCompensationOption.potongSaldoCuti,
            startAt: DateTime(2026, 4, 18),
            endAt: DateTime(2026, 4, 18),
            durationValue: 1,
            reason: 'Keperluan keluarga inti',
            delegateTo: 'Backup operasional',
            status: leave_model.WorkflowStatus.approved,
            note: 'Pengajuan sebelumnya sudah selesai disetujui.',
          ),
        ];
      case AppRole.management:
        return [
          _buildLeaveRecord(
            session: session,
            id: '${session.ownerKey}-leave-approved',
            category: leave_model.LeaveCategory.izinPerHari,
            compensation: leave_model.LeaveCompensationOption.tidakPotongGaji,
            startAt: DateTime(2026, 4, 20),
            endAt: DateTime(2026, 4, 20),
            durationValue: 1,
            reason: 'Agenda eksternal manajemen',
            delegateTo: 'Tim office',
            status: leave_model.WorkflowStatus.approved,
            note: 'Dicatat sebagai referensi historis management.',
          ),
        ];
      default:
        return const [];
    }
  }

  List<wfa_model.WfaRequestRecord> _seedOwnWfaRecords(AppSession session) {
    switch (session.role) {
      case AppRole.staff:
      case AppRole.spv:
      case AppRole.areaManager:
      case AppRole.management:
        return [
          _buildWfaRecord(
            session: session,
            id: '${session.ownerKey}-wfa-approved',
            mode: wfa_model.WfaRequestMode.regular,
            compensation: wfa_model.WfaCompensationMode.normalShift,
            workDate: DateTime(2026, 4, 24),
            startTime: '08:30',
            endTime: '17:00',
            location: 'Rumah - ${session.areaName}',
            reason:
                'Fokus koordinasi laporan dan follow-up vendor dari luar kantor.',
            initialTask:
                'Review pipeline area, follow-up vendor, dan daily sync.',
            status: wfa_model.WorkflowStatus.approved,
            note:
                'WFA reguler disetujui untuk jam kerja utama dengan output harian wajib ter-update.',
          ),
          _buildWfaRecord(
            session: session,
            id: '${session.ownerKey}-wfa-pending',
            mode: wfa_model.WfaRequestMode.overtime,
            compensation: wfa_model.WfaCompensationMode.shiftMundur,
            workDate: DateTime(2026, 4, 24),
            startTime: '19:30',
            endTime: '21:00',
            location: 'Online meeting dari rumah',
            reason:
                'Meeting malam dengan mitra dan tim lintas area di luar jam kerja.',
            initialTask:
                'Presentasi progres area dan tindak lanjut hasil meeting malam.',
            status: session.role == AppRole.management
                ? wfa_model.WorkflowStatus.approved
                : wfa_model.WorkflowStatus.pending,
            note: session.role == AppRole.management
                ? 'WFA management dicatat langsung sebagai approved mock.'
                : 'Overtime menunggu approval. Rekomendasi kompensasi saat ini adalah pergeseran jam masuk esok hari.',
          ),
        ];
      default:
        return const [];
    }
  }

  leave_model.LeaveRequestRecord _buildLeaveRecord({
    required AppSession session,
    required String id,
    required leave_model.LeaveCategory category,
    required leave_model.LeaveCompensationOption compensation,
    required DateTime startAt,
    required DateTime endAt,
    required double durationValue,
    required String reason,
    required String delegateTo,
    required leave_model.WorkflowStatus status,
    required String note,
  }) {
    final steps = _buildApprovalSteps(session);
    final effectiveStatus =
        steps.isEmpty ? leave_model.WorkflowStatus.approved : status;

    return leave_model.LeaveRequestRecord(
      id: id,
      requesterId: session.ownerKey,
      requesterName: session.userName,
      requesterRole: session.role,
      category: category,
      compensationOption: compensation,
      startAt: startAt,
      endAt: endAt,
      durationValue: durationValue,
      reason: reason,
      delegateTo: delegateTo,
      status: effectiveStatus,
      approvalSteps: _seededStepsForStatus(steps, effectiveStatus),
      submittedAt: startAt.subtract(const Duration(days: 1)),
      note: note,
    );
  }

  wfa_model.WfaRequestRecord _buildWfaRecord({
    required AppSession session,
    required String id,
    required wfa_model.WfaRequestMode mode,
    required wfa_model.WfaCompensationMode compensation,
    required DateTime workDate,
    required String startTime,
    required String endTime,
    required String location,
    required String reason,
    required String initialTask,
    required wfa_model.WorkflowStatus status,
    required String note,
  }) {
    final steps = _buildApprovalSteps(session);
    final effectiveStatus =
        steps.isEmpty ? wfa_model.WorkflowStatus.approved : status;

    return wfa_model.WfaRequestRecord(
      id: id,
      requesterId: session.ownerKey,
      requesterName: session.userName,
      requesterRole: session.role,
      mode: mode,
      compensationMode: compensation,
      workDate: workDate,
      startTime: startTime,
      endTime: endTime,
      locationLabel: location,
      reason: reason,
      initialTask: initialTask,
      status: effectiveStatus,
      approvalSteps: _seededStepsForStatus(steps, effectiveStatus),
      taskUpdates: const [],
      submittedAt: workDate.subtract(const Duration(hours: 2)),
      note: note,
    );
  }

  List<ApprovalStep> _buildApprovalSteps(AppSession session) {
    switch (session.role) {
      case AppRole.staff:
        return [
          ApprovalStep(
            sequence: 1,
            approverRole: AppRole.spv,
            approverId: _ownerKeyFor(AppRole.spv, session.defaultSpv!),
            approverName: session.defaultSpv,
            status: ApprovalStepStatus.pending,
          ),
          ApprovalStep(
            sequence: 2,
            approverRole: AppRole.management,
            approverId:
                _ownerKeyFor(AppRole.management, session.defaultManagement!),
            approverName: session.defaultManagement,
            status: ApprovalStepStatus.pending,
          ),
        ];
      case AppRole.spv:
      case AppRole.areaManager:
        return [
          ApprovalStep(
            sequence: 1,
            approverRole: AppRole.management,
            approverId:
                _ownerKeyFor(AppRole.management, session.defaultManagement!),
            approverName: session.defaultManagement,
            status: ApprovalStepStatus.pending,
          ),
        ];
      default:
        return const [];
    }
  }

  List<ApprovalStep> _seededStepsForStatus(
    List<ApprovalStep> steps,
    Object status,
  ) {
    if (status == leave_model.WorkflowStatus.pending ||
        status == wfa_model.WorkflowStatus.pending) {
      return steps;
    }

    if (status == leave_model.WorkflowStatus.approved ||
        status == wfa_model.WorkflowStatus.approved) {
      return steps
          .map(
            (step) => step.copyWith(
              status: ApprovalStepStatus.approved,
              actedAt: DateTime(2026, 4, 24, 9),
            ),
          )
          .toList();
    }

    if (status == leave_model.WorkflowStatus.rejected ||
        status == wfa_model.WorkflowStatus.rejected) {
      var acted = false;
      return steps.map(
        (step) {
          if (!acted) {
            acted = true;
            return step.copyWith(
              status: ApprovalStepStatus.rejected,
              actedAt: DateTime(2026, 4, 24, 9),
            );
          }
          return step;
        },
      ).toList();
    }

    return steps;
  }

  String _ownerKeyFor(AppRole role, String userName) {
    return '${role.name}:${userName.trim().toLowerCase()}';
  }

  String _workflowUserIdForSession(AppSession session) {
    if (!_useCanonicalWorkflowIds) {
      return session.ownerKey;
    }

    return session.userId;
  }

  String _workflowUserNameForSession(AppSession session) {
    if (!_useCanonicalWorkflowIds) {
      return session.userName;
    }

    return session.userName;
  }

  Future<HeatMapSnapshot> loadHeatMap({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    String? type,
  }) {
    return _heatMapRepository.load(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      type: type,
    );
  }

  Future<RemoteAttachment?> _uploadAttachmentIfNeeded({
    required String? filePath,
    required String label,
  }) async {
    if (filePath == null || filePath.isEmpty) {
      return null;
    }
    if (_isRemoteResourcePath(filePath)) {
      return RemoteAttachment(
        id: 'remote-$label',
        fileName: label,
        mimeType: 'image/jpeg',
        url: filePath,
        thumbnailUrl: filePath,
      );
    }

    return _uploadRepository.uploadAttachment(
      filePath: filePath,
      label: label,
    );
  }

  bool _isRemoteResourcePath(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  leave_model.LeaveRequestRecord? _findLeaveRequestById(String requestId) {
    for (final requests in _leaveRequestsByOwner.values) {
      for (final request in requests) {
        if (request.id == requestId) {
          return request;
        }
      }
    }
    for (final requests in _leaveApprovalRequestsByApprover.values) {
      for (final request in requests) {
        if (request.id == requestId) {
          return request;
        }
      }
    }
    return null;
  }

  wfa_model.WfaRequestRecord? _findWfaRequestById(String requestId) {
    for (final requests in _wfaRequestsByOwner.values) {
      for (final request in requests) {
        if (request.id == requestId) {
          return request;
        }
      }
    }
    for (final requests in _wfaApprovalRequestsByApprover.values) {
      for (final request in requests) {
        if (request.id == requestId) {
          return request;
        }
      }
    }
    return null;
  }

  Future<void> _refreshWorkflowForLeaveParticipants(
    leave_model.LeaveRequestRecord request,
  ) async {
    final sessions = <AppSession>[
      _sessionForWorkflowUser(
        role: request.requesterRole,
        userId: request.requesterId,
        userName: request.requesterName,
      ),
      ...request.approvalSteps.map(
        (step) => _sessionForWorkflowUser(
          role: step.approverRole,
          userId: step.approverId ??
              _ownerKeyFor(
                step.approverRole,
                step.approverName ?? step.approverRole.mockUserName,
              ),
          userName: step.approverName ?? step.approverRole.mockUserName,
        ),
      ),
    ];

    for (final participant in sessions) {
      await _loadWorkflowData(participant);
    }
  }

  Future<void> _refreshWorkflowForWfaParticipants(
    wfa_model.WfaRequestRecord request,
  ) async {
    final sessions = <AppSession>[
      _sessionForWorkflowUser(
        role: request.requesterRole,
        userId: request.requesterId,
        userName: request.requesterName,
      ),
      ...request.approvalSteps.map(
        (step) => _sessionForWorkflowUser(
          role: step.approverRole,
          userId: step.approverId ??
              _ownerKeyFor(
                step.approverRole,
                step.approverName ?? step.approverRole.mockUserName,
              ),
          userName: step.approverName ?? step.approverRole.mockUserName,
        ),
      ),
    ];

    for (final participant in sessions) {
      await _loadWorkflowData(participant);
    }
  }

  AppSession _sessionForWorkflowUser({
    required AppRole role,
    required String userId,
    required String userName,
  }) {
    return AppSession.mock(role, userName: userName).copyWith(userId: userId);
  }

  bool _usesLeaveBalance(leave_model.LeaveRequestRecord request) {
    return request.category == leave_model.LeaveCategory.cuti &&
        request.compensationOption ==
            leave_model.LeaveCompensationOption.potongSaldoCuti;
  }

  void _consumeLeaveBalanceIfNeeded({
    required String userId,
    required AppRole role,
    required leave_model.LeaveRequestRecord request,
  }) {
    if (!_usesLeaveBalance(request)) {
      return;
    }

    final currentBalance =
        _leaveBalanceByUserId[userId] ?? role.defaultLeaveBalanceDays;
    _leaveBalanceByUserId[userId] =
        (currentBalance - request.durationValue).clamp(
      0,
      double.infinity,
    );
    notifyListeners();
  }

  void _restoreLeaveBalanceIfNeeded(leave_model.LeaveRequestRecord request) {
    if (!_usesLeaveBalance(request)) {
      return;
    }

    final currentBalance = _leaveBalanceByUserId[request.requesterId] ??
        request.requesterRole.defaultLeaveBalanceDays;
    _leaveBalanceByUserId[request.requesterId] =
        currentBalance + request.durationValue;
    notifyListeners();
  }

  Future<void> _restoreSession() async {
    if (!_useRemoteAuth || _authRepository == null) {
      _isBootstrapping = false;
      notifyListeners();
      return;
    }

    final authRepository = _authRepository;
    try {
      final user = await authRepository.currentUser();
      if (user != null) {
        await _applySignedInUser(user);
      }
    } catch (_) {
      _session = null;
    } finally {
      _isBootstrapping = false;
      notifyListeners();
    }
  }

  Future<void> _applySignedInUser(AppUser user) async {
    _applyUserSnapshot(user);
    await _activateSession(AppSession.fromUser(user));
    await _syncPushTokenRegistration();
  }

  Future<void> refreshCurrentUserProfile() async {
    final authRepository = _authRepository;
    final currentSession = _session;
    if (!_useRemoteAuth || authRepository == null || currentSession == null) {
      return;
    }

    try {
      final user = await authRepository.currentUser();
      if (user == null) {
        _session = null;
        notifyListeners();
        return;
      }

      _applyUserSnapshot(user);
      _session = AppSession.fromUser(user);
      notifyListeners();
    } catch (_) {
      // Keep the current session if profile refresh fails temporarily.
    }
  }

  void _applyUserSnapshot(AppUser user) {
    _leaveBalanceByUserId[user.id] =
        user.leaveBalanceDays ?? user.role.defaultLeaveBalanceDays;
  }

  Future<void> _logoutAsync() async {
    final authRepository = _authRepository;
    await _pushNotificationService?.cancelAttendanceReminders();
    if (authRepository != null && _useRemoteAuth) {
      final token = _pushNotificationService?.currentToken;
      if (token != null && token.isNotEmpty) {
        try {
          await authRepository.unregisterPushToken(token: token);
        } catch (_) {
          // best effort, keep logout flow running
        }
      }
      await authRepository.signOut();
    }
    _session = null;
    notifyListeners();
  }

  Future<void> _syncPushTokenRegistration() async {
    final authRepository = _authRepository;
    final pushNotificationService = _pushNotificationService;
    if (!_useRemoteAuth ||
        authRepository == null ||
        pushNotificationService == null) {
      return;
    }

    final token = await pushNotificationService.ensureToken();
    if (token == null || token.isEmpty) {
      return;
    }

    await authRepository.registerPushToken(
      token: token,
      platform: 'android',
      deviceName: 'android',
    );
  }

  @override
  void dispose() {
    _pushTokenSubscription?.cancel();
    super.dispose();
  }

  bool _matchesMultiRoleTester({
    required String identifier,
    required String password,
  }) {
    return identifier.trim().toLowerCase() == multiRoleTesterIdentifier &&
        password.trim() == multiRoleTesterPassword;
  }

  Future<void> _activateSession(
    AppSession session, {
    bool notify = true,
  }) async {
    _session = session;
    await _loadAttendanceData(session);
    await _loadFaceProfileData(session);
    await _loadWorkflowData(session);
    if (session.role == AppRole.fgg ||
        session.role == AppRole.areaManager ||
        session.role == AppRole.management) {
      await _loadNetworkEntries(session);
    }
    if (session.role == AppRole.fgg || session.role == AppRole.areaManager) {
      await _loadPerformanceSummary(session);
    }
    await _loadAnnouncements();
    await _syncAttendanceReminderSchedule(session);
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _syncAttendanceReminderSchedule(AppSession session) async {
    final pushNotificationService = _pushNotificationService;
    if (pushNotificationService == null) {
      return;
    }

    if (session.role == AppRole.staff) {
      await pushNotificationService.scheduleStaffAttendanceReminders(
        checkInTime: AttendancePolicy.officeStart,
        checkOutTime: AttendancePolicy.officeEnd,
      );
      return;
    }

    await pushNotificationService.cancelAttendanceReminders();
  }

  NetworkProfileStatus _profileStatusFromLabel(String label) {
    switch (label) {
      case 'Draft':
        return NetworkProfileStatus.draft;
      case 'Lengkap':
        return NetworkProfileStatus.completed;
      case 'Arsip':
        return NetworkProfileStatus.archived;
      case 'Follow-up':
      default:
        return NetworkProfileStatus.followUp;
    }
  }
}
