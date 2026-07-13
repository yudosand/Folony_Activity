import '../enums/app_role.dart';
import 'territory_assignment.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.areaName,
    required this.workLocation,
    required this.jobTitle,
    required this.officeLatitude,
    required this.officeLongitude,
    required this.attendanceRadiusMeters,
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
    this.isActive = true,
    this.leaveBalanceDays,
    this.joinedAt,
    this.address,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.faceEnrollmentStatus = 'pending',
    this.faceSamplesCount = 0,
  });

  final String id;
  final String fullName;
  final String? email;
  final String phoneNumber;
  final String areaName;
  final String? workLocation;
  final String? jobTitle;
  final double? officeLatitude;
  final double? officeLongitude;
  final int? attendanceRadiusMeters;
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
  final bool isActive;
  final double? leaveBalanceDays;
  final DateTime? joinedAt;
  final String? address;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String faceEnrollmentStatus;
  final int faceSamplesCount;

  bool get hasFaceEnrollment =>
      faceEnrollmentStatus == 'active' && faceSamplesCount >= 3;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String?,
      phoneNumber: json['phone_number'] as String? ?? '',
      areaName: json['area_name'] as String? ?? '',
      workLocation: json['work_location'] as String?,
      jobTitle: json['job_title'] as String?,
      officeLatitude: (json['office_latitude'] as num?)?.toDouble(),
      officeLongitude: (json['office_longitude'] as num?)?.toDouble(),
      attendanceRadiusMeters:
          (json['attendance_radius_meters'] as num?)?.toInt(),
      territoryScope: json['territory_scope'] as String?,
      territoryProvince: json['territory_province'] as String?,
      territoryCity: json['territory_city'] as String?,
      territoryDistrict: json['territory_district'] as String?,
      territorySubdistrict: json['territory_subdistrict'] as String?,
      territoryAssignments: _territoryAssignmentsFromJson(
        json['territory_assignments'],
      ),
      territoryLabel: json['territory_label'] as String?,
      role: _appRoleFromName(json['role'] as String?),
      canSwitchRoles: json['can_switch_roles'] as bool? ?? false,
      availableRoles: _appRolesFromJson(json['available_roles']),
      spvId: json['spv_id'] as String?,
      spvName: json['spv_name'] as String?,
      managementId: json['management_id'] as String?,
      managementName: json['management_name'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      leaveBalanceDays: (json['leave_balance_days'] as num?)?.toDouble(),
      joinedAt: _parseDateTime(json['joined_at']),
      address: json['address'] as String?,
      emergencyContactName: json['emergency_contact_name'] as String?,
      emergencyContactPhone: json['emergency_contact_phone'] as String?,
      faceEnrollmentStatus:
          json['face_enrollment_status'] as String? ?? 'pending',
      faceSamplesCount: (json['face_samples_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone_number': phoneNumber,
      'area_name': areaName,
      'work_location': workLocation,
      'job_title': jobTitle,
      'office_latitude': officeLatitude,
      'office_longitude': officeLongitude,
      'attendance_radius_meters': attendanceRadiusMeters,
      'territory_scope': territoryScope,
      'territory_province': territoryProvince,
      'territory_city': territoryCity,
      'territory_district': territoryDistrict,
      'territory_subdistrict': territorySubdistrict,
      'territory_assignments':
          territoryAssignments.map((item) => item.toJson()).toList(),
      'territory_label': territoryLabel,
      'role': role.name,
      'can_switch_roles': canSwitchRoles,
      'available_roles': availableRoles.map((role) => role.name).toList(),
      'spv_id': spvId,
      'spv_name': spvName,
      'management_id': managementId,
      'management_name': managementName,
      'is_active': isActive,
      'leave_balance_days': leaveBalanceDays,
      'joined_at': joinedAt?.toIso8601String(),
      'address': address,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_phone': emergencyContactPhone,
      'face_enrollment_status': faceEnrollmentStatus,
      'face_samples_count': faceSamplesCount,
    };
  }

  AppUser copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? areaName,
    String? workLocation,
    String? jobTitle,
    double? officeLatitude,
    double? officeLongitude,
    int? attendanceRadiusMeters,
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
    bool? isActive,
    double? leaveBalanceDays,
    DateTime? joinedAt,
    String? address,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? faceEnrollmentStatus,
    int? faceSamplesCount,
  }) {
    return AppUser(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      areaName: areaName ?? this.areaName,
      workLocation: workLocation ?? this.workLocation,
      jobTitle: jobTitle ?? this.jobTitle,
      officeLatitude: officeLatitude ?? this.officeLatitude,
      officeLongitude: officeLongitude ?? this.officeLongitude,
      attendanceRadiusMeters:
          attendanceRadiusMeters ?? this.attendanceRadiusMeters,
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
      isActive: isActive ?? this.isActive,
      leaveBalanceDays: leaveBalanceDays ?? this.leaveBalanceDays,
      joinedAt: joinedAt ?? this.joinedAt,
      address: address ?? this.address,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone:
          emergencyContactPhone ?? this.emergencyContactPhone,
      faceEnrollmentStatus: faceEnrollmentStatus ?? this.faceEnrollmentStatus,
      faceSamplesCount: faceSamplesCount ?? this.faceSamplesCount,
    );
  }

  static AppRole _appRoleFromName(String? value) {
    return AppRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => AppRole.staff,
    );
  }

  static List<AppRole> _appRolesFromJson(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map(
          (item) => _appRoleFromName(item as String?),
        )
        .toSet()
        .toList(growable: false);
  }

  static List<TerritoryAssignment> _territoryAssignmentsFromJson(
      dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map((item) =>
            TerritoryAssignment.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }
}
