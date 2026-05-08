import 'package:flutter/material.dart';

import '../enums/app_role.dart';
import 'network_entry.dart';
import 'network_profile.dart';
import 'remote_attachment.dart';

extension NetworkProfileUiMapper on NetworkProfile {
  NetworkEntry toNetworkEntry() {
    final personalityMap = {
      for (final item in personalityMetrics) item.label: item.score,
    };
    final documentMap = {
      for (final item in documents)
        item.label: PartnerDocumentState(
          exists: item.exists,
          isValid: item.isValid,
        ),
    };

    return NetworkEntry(
      id: id,
      ownerKey: ownerId,
      ownerName: ownerName,
      ownerRole: ownerRole,
      type: type == NetworkProfileType.ukm
          ? NetworkEntryType.ukm
          : NetworkEntryType.mitraHub,
      name: name,
      address: address,
      businessType: businessType,
      phone: phoneNumber,
      reference: referenceName ?? '',
      notes: note ?? '',
      photoPath: photo?.url,
      status: _statusLabel(status),
      statusColor: _statusColor(status),
      personalityScore: personalityMetrics.isEmpty
          ? null
          : (personalityMetrics
                      .fold<double>(0, (sum, item) => sum + item.score) /
                  personalityMetrics.length)
              .round(),
      personalityScores: personalityMap,
      documents: documentMap,
      followUps: followUps
          .map(
            (item) => NetworkFollowUp(
              title: item.title,
              note: item.note,
              actorName: item.actorName,
              createdAt: item.createdAt,
            ),
          )
          .toList(),
      createdAt: createdAt,
    );
  }
}

extension NetworkEntryDomainMapper on NetworkEntry {
  NetworkProfile toNetworkProfile({
    String? ownerId,
  }) {
    final metrics = personalityScores.entries
        .map(
          (item) => PersonalityMetric(
            label: item.key,
            score: item.value,
          ),
        )
        .toList();
    final documentRecords = documents.entries
        .map(
          (item) => NetworkDocumentRecord(
            label: item.key,
            exists: item.value.exists,
            isValid: item.value.isValid,
          ),
        )
        .toList();

    return NetworkProfile(
      id: id,
      ownerId: ownerId ?? ownerKey,
      ownerName: ownerName,
      ownerRole: ownerRole,
      type: type == NetworkEntryType.ukm
          ? NetworkProfileType.ukm
          : NetworkProfileType.mitra,
      name: name,
      address: address,
      businessType: businessType,
      phoneNumber: phone,
      status: _networkStatusFromLabel(status),
      createdAt: createdAt,
      referenceName: reference.isEmpty ? null : reference,
      note: notes.isEmpty ? null : notes,
      photo: photoPath == null
          ? null
          : RemoteAttachment(
              id: 'local-$id',
              fileName: photoPath!,
              mimeType: 'image/jpeg',
              url: photoPath!,
            ),
      personalityMetrics: metrics,
      documents: documentRecords,
      followUps: followUps
          .map(
            (item) => NetworkFollowUpRecord(
              id: '$id-${item.createdAt.microsecondsSinceEpoch}',
              title: item.title,
              note: item.note,
              actorId: ownerId ?? ownerKey,
              actorName: item.actorName,
              createdAt: item.createdAt,
            ),
          )
          .toList(),
    );
  }
}

String _statusLabel(NetworkProfileStatus status) {
  switch (status) {
    case NetworkProfileStatus.draft:
      return 'Draft';
    case NetworkProfileStatus.followUp:
      return 'Follow-up';
    case NetworkProfileStatus.completed:
      return 'Lengkap';
    case NetworkProfileStatus.archived:
      return 'Arsip';
  }
}

Color _statusColor(NetworkProfileStatus status) {
  switch (status) {
    case NetworkProfileStatus.draft:
      return Colors.teal;
    case NetworkProfileStatus.followUp:
      return Colors.orange;
    case NetworkProfileStatus.completed:
      return Colors.green;
    case NetworkProfileStatus.archived:
      return Colors.blueGrey;
  }
}

NetworkProfileStatus _networkStatusFromLabel(String label) {
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

String buildOwnerId({
  required AppRole role,
  required String userName,
}) {
  final normalizedName = userName.trim().toLowerCase();
  return '${role.name}:$normalizedName';
}
