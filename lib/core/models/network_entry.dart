import 'dart:io';

import 'package:flutter/material.dart';

import '../enums/app_role.dart';

class NetworkEntry {
  const NetworkEntry({
    required this.id,
    required this.ownerKey,
    required this.ownerName,
    required this.ownerRole,
    required this.type,
    required this.name,
    required this.address,
    required this.territoryProvince,
    required this.territoryCity,
    required this.territoryDistrict,
    required this.territorySubdistrict,
    required this.businessType,
    required this.phone,
    required this.reference,
    required this.notes,
    required this.photoPath,
    required this.status,
    required this.statusColor,
    required this.personalityScore,
    required this.personalityScores,
    required this.documents,
    required this.followUps,
    required this.createdAt,
    this.latitude,
    this.longitude,
  });

  factory NetworkEntry.mock({
    required String ownerKey,
    required String ownerName,
    required AppRole ownerRole,
    required NetworkEntryType type,
    required String name,
    required String address,
    required String businessType,
    required String phone,
    required String status,
    required Color statusColor,
    String reference = '',
    String notes = '',
    int? personalityScore,
    List<NetworkFollowUp> followUps = const [],
  }) {
    return NetworkEntry(
      id: '$ownerKey-$name',
      ownerKey: ownerKey,
      ownerName: ownerName,
      ownerRole: ownerRole,
      type: type,
      name: name,
      address: address,
      territoryProvince: '',
      territoryCity: '',
      territoryDistrict: '',
      territorySubdistrict: '',
      businessType: businessType,
      phone: phone,
      reference: reference,
      notes: notes,
      photoPath: null,
      status: status,
      statusColor: statusColor,
      personalityScore: personalityScore,
      personalityScores: const {},
      documents: const {},
      followUps: followUps,
      createdAt: DateTime.now(),
      latitude: null,
      longitude: null,
    );
  }

  final String id;
  final String ownerKey;
  final String ownerName;
  final AppRole ownerRole;
  final NetworkEntryType type;
  final String name;
  final String address;
  final String territoryProvince;
  final String territoryCity;
  final String territoryDistrict;
  final String territorySubdistrict;
  final String businessType;
  final String phone;
  final String reference;
  final String notes;
  final String? photoPath;
  final String status;
  final Color statusColor;
  final int? personalityScore;
  final Map<String, double> personalityScores;
  final Map<String, PartnerDocumentState> documents;
  final List<NetworkFollowUp> followUps;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;

  NetworkEntry copyWith({
    String? id,
    String? ownerKey,
    String? ownerName,
    AppRole? ownerRole,
    NetworkEntryType? type,
    String? name,
    String? address,
    String? territoryProvince,
    String? territoryCity,
    String? territoryDistrict,
    String? territorySubdistrict,
    String? businessType,
    String? phone,
    String? reference,
    String? notes,
    String? photoPath,
    String? status,
    Color? statusColor,
    int? personalityScore,
    Map<String, double>? personalityScores,
    Map<String, PartnerDocumentState>? documents,
    List<NetworkFollowUp>? followUps,
    DateTime? createdAt,
    double? latitude,
    double? longitude,
  }) {
    return NetworkEntry(
      id: id ?? this.id,
      ownerKey: ownerKey ?? this.ownerKey,
      ownerName: ownerName ?? this.ownerName,
      ownerRole: ownerRole ?? this.ownerRole,
      type: type ?? this.type,
      name: name ?? this.name,
      address: address ?? this.address,
      territoryProvince: territoryProvince ?? this.territoryProvince,
      territoryCity: territoryCity ?? this.territoryCity,
      territoryDistrict: territoryDistrict ?? this.territoryDistrict,
      territorySubdistrict: territorySubdistrict ?? this.territorySubdistrict,
      businessType: businessType ?? this.businessType,
      phone: phone ?? this.phone,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      photoPath: photoPath ?? this.photoPath,
      status: status ?? this.status,
      statusColor: statusColor ?? this.statusColor,
      personalityScore: personalityScore ?? this.personalityScore,
      personalityScores: personalityScores ?? this.personalityScores,
      documents: documents ?? this.documents,
      followUps: followUps ?? this.followUps,
      createdAt: createdAt ?? this.createdAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  String get subtitle {
    switch (type) {
      case NetworkEntryType.ukm:
        return '$businessType - $territorySummary';
      case NetworkEntryType.mitraHub:
        return 'Personality ${personalityScore ?? 0}% - dokumen $validDocumentCount/${documents.length}';
    }
  }

  String get territorySummary {
    final parts = [
      territorySubdistrict,
      territoryDistrict,
      territoryCity,
      territoryProvince,
    ].where((item) => item.trim().isNotEmpty).toList();

    return parts.isEmpty ? address : parts.join(', ');
  }

  int get validDocumentCount {
    return documents.values.where((item) => item.exists && item.isValid).length;
  }

  bool get hasReadablePhoto {
    final path = photoPath;
    if (path == null) {
      return false;
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return true;
    }
    return File(path).existsSync();
  }

  String get createdAtLabel => _formatDateTime(createdAt);

  String get latestFollowUpLabel {
    if (followUps.isEmpty) {
      return 'Belum ada follow-up';
    }
    final latest = followUps.first;
    return '${latest.typeLabel} - ${_formatDateTime(latest.createdAt)}';
  }

  static String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} $hour:$minute';
  }
}

class NetworkFollowUp {
  const NetworkFollowUp({
    this.id,
    required this.title,
    required this.note,
    required this.actorName,
    required this.createdAt,
  });

  final String? id;
  final String title;
  final String note;
  final String actorName;
  final DateTime createdAt;

  String get createdAtLabel => NetworkEntry._formatDateTime(createdAt);

  String get typeLabel => title;
}

class PartnerDocumentState {
  const PartnerDocumentState({
    this.exists = false,
    this.isValid = false,
  });

  final bool exists;
  final bool isValid;

  PartnerDocumentState copyWith({
    bool? exists,
    bool? isValid,
  }) {
    return PartnerDocumentState(
      exists: exists ?? this.exists,
      isValid: isValid ?? this.isValid,
    );
  }
}

enum NetworkEntryType {
  ukm,
  mitraHub;
}

extension NetworkEntryTypeX on NetworkEntryType {
  String get shortLabel {
    switch (this) {
      case NetworkEntryType.ukm:
        return 'UKM';
      case NetworkEntryType.mitraHub:
        return 'Mitra';
    }
  }

  String get nameLabel {
    switch (this) {
      case NetworkEntryType.ukm:
        return 'Nama UKM';
      case NetworkEntryType.mitraHub:
        return 'Nama Mitra';
    }
  }

  IconData get icon {
    switch (this) {
      case NetworkEntryType.ukm:
        return Icons.storefront_rounded;
      case NetworkEntryType.mitraHub:
        return Icons.apartment_rounded;
    }
  }
}
