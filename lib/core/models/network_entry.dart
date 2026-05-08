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
    );
  }

  final String id;
  final String ownerKey;
  final String ownerName;
  final AppRole ownerRole;
  final NetworkEntryType type;
  final String name;
  final String address;
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

  NetworkEntry copyWith({
    String? id,
    String? ownerKey,
    String? ownerName,
    AppRole? ownerRole,
    NetworkEntryType? type,
    String? name,
    String? address,
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
  }) {
    return NetworkEntry(
      id: id ?? this.id,
      ownerKey: ownerKey ?? this.ownerKey,
      ownerName: ownerName ?? this.ownerName,
      ownerRole: ownerRole ?? this.ownerRole,
      type: type ?? this.type,
      name: name ?? this.name,
      address: address ?? this.address,
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
    );
  }

  String get subtitle {
    switch (type) {
      case NetworkEntryType.ukm:
        return '$businessType - $address';
      case NetworkEntryType.mitraHub:
        return 'Personality ${personalityScore ?? 0}% - dokumen $validDocumentCount/${documents.length}';
    }
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
    required this.title,
    required this.note,
    required this.actorName,
    required this.createdAt,
  });

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
