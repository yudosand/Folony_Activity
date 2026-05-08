enum AppRole {
  areaManager,
  fgg,
  staff,
  spv,
  management;
}

extension AppRoleX on AppRole {
  String get label {
    switch (this) {
      case AppRole.areaManager:
        return 'Area Manager';
      case AppRole.fgg:
        return 'FGG';
      case AppRole.staff:
        return 'Staff';
      case AppRole.spv:
        return 'SPV';
      case AppRole.management:
        return 'Management';
    }
  }

  String get description {
    switch (this) {
      case AppRole.areaManager:
        return 'Role area dengan fokus absensi, dashboard lapangan, heat map, jaringan UKM dan mitra, serta monitoring UKM tim FGG.';
      case AppRole.fgg:
        return 'Role lapangan dengan fokus pengembangan UKM, heat map, dashboard aktivitas, dan daftar UKM miliknya.';
      case AppRole.staff:
        return 'Role internal untuk absensi, WFA activity, dan pengajuan cuti.';
      case AppRole.spv:
        return 'Role pengawas tim dengan akses approval cuti dan monitoring aktivitas.';
      case AppRole.management:
        return 'Role manajemen dengan akses ringkasan, approval, dan pengawasan operasional.';
    }
  }

  String get mockUserName {
    switch (this) {
      case AppRole.areaManager:
        return 'Raka Area Manager';
      case AppRole.fgg:
        return 'Bima FGG';
      case AppRole.staff:
        return 'Nadia Staff';
      case AppRole.spv:
        return 'Dimas SPV';
      case AppRole.management:
        return 'Sinta Management';
    }
  }

  String get defaultArea {
    switch (this) {
      case AppRole.areaManager:
        return 'Jakarta Selatan';
      case AppRole.fgg:
        return 'Cluster Jagakarsa';
      case AppRole.staff:
        return 'Head Office';
      case AppRole.spv:
        return 'Regional Barat';
      case AppRole.management:
        return 'National';
    }
  }

  double get defaultLeaveBalanceDays {
    switch (this) {
      case AppRole.areaManager:
        return 10;
      case AppRole.fgg:
        return 0;
      case AppRole.staff:
        return 9;
      case AppRole.spv:
        return 8;
      case AppRole.management:
        return 12;
    }
  }

  String get workflowDemoUserId {
    switch (this) {
      case AppRole.areaManager:
        return 'usr_area_001';
      case AppRole.fgg:
        return 'usr_fgg_001';
      case AppRole.staff:
        return 'usr_001';
      case AppRole.spv:
        return 'usr_spv_001';
      case AppRole.management:
        return 'usr_mgt_001';
    }
  }
}
