import 'app_user.dart';
import '../enums/app_role.dart';
import 'territory_assignment.dart';

class AppSession {
  const AppSession({
    required this.userId,
    required this.userName,
    required this.phoneNumber,
    required this.areaName,
    required this.territoryScope,
    required this.territoryProvince,
    required this.territoryCity,
    required this.territoryDistrict,
    required this.territorySubdistrict,
    required this.territoryAssignments,
    required this.territoryLabel,
    required this.role,
    this.canSwitchRoles = false,
    this.availableRoles = const [],
    this.spvId,
    this.spvName,
    this.managementId,
    this.managementName,
    this.faceEnrollmentStatus = 'pending',
    this.faceSamplesCount = 0,
  });

  final String userId;
  final String userName;
  final String phoneNumber;
  final String areaName;
  final String? territoryScope;
  final String? territoryProvince;
  final String? territoryCity;
  final String? territoryDistrict;
  final String? territorySubdistrict;
  final List<TerritoryAssignment> territoryAssignments;
  final String? territoryLabel;
  final AppRole role;
  final bool canSwitchRoles;
  final List<AppRole> availableRoles;
  final String? spvId;
  final String? spvName;
  final String? managementId;
  final String? managementName;
  final String faceEnrollmentStatus;
  final int faceSamplesCount;

  bool get hasFaceEnrollment =>
      faceEnrollmentStatus == 'active' && faceSamplesCount >= 3;

  factory AppSession.mock(
    AppRole role, {
    String? userName,
  }) {
    return AppSession(
      userId: role.workflowDemoUserId,
      userName: userName?.trim().isNotEmpty == true
          ? userName!.trim()
          : role.mockUserName,
      phoneNumber: '081234567890',
      areaName: role.defaultArea,
      territoryScope: null,
      territoryProvince: null,
      territoryCity: role.defaultArea,
      territoryDistrict: null,
      territorySubdistrict: null,
      territoryAssignments: const [],
      territoryLabel: role.defaultArea,
      role: role,
      spvId: role == AppRole.staff ? AppRole.spv.workflowDemoUserId : null,
      spvName: role == AppRole.staff ? AppRole.spv.mockUserName : null,
      managementId: switch (role) {
        AppRole.staff || AppRole.spv || AppRole.areaManager =>
          AppRole.management.workflowDemoUserId,
        _ => null,
      },
      managementName: switch (role) {
        AppRole.staff || AppRole.spv || AppRole.areaManager =>
          AppRole.management.mockUserName,
        _ => null,
      },
      faceEnrollmentStatus: 'active',
      faceSamplesCount: 3,
    );
  }

  factory AppSession.multiRoleTester(
    AppRole activeRole, {
    String testerName = 'All Role Tester',
  }) {
    final base = AppSession.mock(activeRole);
    return base.copyWith(
      userName: testerName,
      phoneNumber: '086666666666',
      canSwitchRoles: true,
      availableRoles: AppRole.values,
    );
  }

  factory AppSession.fromUser(AppUser user) {
    return AppSession(
      userId: user.id,
      userName: user.fullName,
      phoneNumber: user.phoneNumber,
      areaName: user.areaName,
      territoryScope: user.territoryScope,
      territoryProvince: user.territoryProvince,
      territoryCity: user.territoryCity,
      territoryDistrict: user.territoryDistrict,
      territorySubdistrict: user.territorySubdistrict,
      territoryAssignments: user.territoryAssignments,
      territoryLabel: user.territoryLabel,
      role: user.role,
      canSwitchRoles: user.canSwitchRoles,
      availableRoles: user.availableRoles,
      spvId: user.spvId,
      spvName: user.spvName,
      managementId: user.managementId,
      managementName: user.managementName,
      faceEnrollmentStatus: user.faceEnrollmentStatus,
      faceSamplesCount: user.faceSamplesCount,
    );
  }

  String get ownerKey {
    final normalizedName = userName.trim().toLowerCase();
    return '${role.name}:$normalizedName';
  }

  List<String> get spvOptions {
    return spvName == null ? const [] : [spvName!];
  }

  List<String> get managementOptions {
    return managementName == null ? const [] : [managementName!];
  }

  String? get defaultSpv {
    return spvOptions.isEmpty ? null : spvOptions.first;
  }

  String? get defaultManagement {
    return managementOptions.isEmpty ? null : managementOptions.first;
  }

  AppSession copyWith({
    String? userId,
    String? userName,
    String? phoneNumber,
    String? areaName,
    String? territoryScope,
    String? territoryProvince,
    String? territoryCity,
    String? territoryDistrict,
    String? territorySubdistrict,
    List<TerritoryAssignment>? territoryAssignments,
    String? territoryLabel,
    AppRole? role,
    bool? canSwitchRoles,
    List<AppRole>? availableRoles,
    String? spvId,
    String? spvName,
    String? managementId,
    String? managementName,
    String? faceEnrollmentStatus,
    int? faceSamplesCount,
  }) {
    return AppSession(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      areaName: areaName ?? this.areaName,
      territoryScope: territoryScope ?? this.territoryScope,
      territoryProvince: territoryProvince ?? this.territoryProvince,
      territoryCity: territoryCity ?? this.territoryCity,
      territoryDistrict: territoryDistrict ?? this.territoryDistrict,
      territorySubdistrict: territorySubdistrict ?? this.territorySubdistrict,
      territoryAssignments: territoryAssignments ?? this.territoryAssignments,
      territoryLabel: territoryLabel ?? this.territoryLabel,
      role: role ?? this.role,
      canSwitchRoles: canSwitchRoles ?? this.canSwitchRoles,
      availableRoles: availableRoles ?? this.availableRoles,
      spvId: spvId ?? this.spvId,
      spvName: spvName ?? this.spvName,
      managementId: managementId ?? this.managementId,
      managementName: managementName ?? this.managementName,
      faceEnrollmentStatus: faceEnrollmentStatus ?? this.faceEnrollmentStatus,
      faceSamplesCount: faceSamplesCount ?? this.faceSamplesCount,
    );
  }
}
