import '../enums/app_role.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.areaName,
    required this.role,
    this.canSwitchRoles = false,
    this.availableRoles = const [],
    this.spvId,
    this.spvName,
    this.managementId,
    this.managementName,
    this.isActive = true,
  });

  final String id;
  final String fullName;
  final String phoneNumber;
  final String areaName;
  final AppRole role;
  final bool canSwitchRoles;
  final List<AppRole> availableRoles;
  final String? spvId;
  final String? spvName;
  final String? managementId;
  final String? managementName;
  final bool isActive;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      areaName: json['area_name'] as String? ?? '',
      role: _appRoleFromName(json['role'] as String?),
      canSwitchRoles: json['can_switch_roles'] as bool? ?? false,
      availableRoles: _appRolesFromJson(json['available_roles']),
      spvId: json['spv_id'] as String?,
      spvName: json['spv_name'] as String?,
      managementId: json['management_id'] as String?,
      managementName: json['management_name'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'area_name': areaName,
      'role': role.name,
      'can_switch_roles': canSwitchRoles,
      'available_roles': availableRoles.map((role) => role.name).toList(),
      'spv_id': spvId,
      'spv_name': spvName,
      'management_id': managementId,
      'management_name': managementName,
      'is_active': isActive,
    };
  }

  AppUser copyWith({
    String? id,
    String? fullName,
    String? phoneNumber,
    String? areaName,
    AppRole? role,
    bool? canSwitchRoles,
    List<AppRole>? availableRoles,
    String? spvId,
    String? spvName,
    String? managementId,
    String? managementName,
    bool? isActive,
  }) {
    return AppUser(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      areaName: areaName ?? this.areaName,
      role: role ?? this.role,
      canSwitchRoles: canSwitchRoles ?? this.canSwitchRoles,
      availableRoles: availableRoles ?? this.availableRoles,
      spvId: spvId ?? this.spvId,
      spvName: spvName ?? this.spvName,
      managementId: managementId ?? this.managementId,
      managementName: managementName ?? this.managementName,
      isActive: isActive ?? this.isActive,
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
}
