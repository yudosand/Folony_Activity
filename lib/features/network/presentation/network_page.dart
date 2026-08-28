import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app_controller.dart';
import '../../../core/enums/app_role.dart';
import '../../../core/models/app_session.dart';
import '../../../core/models/network_entry.dart';
import '../../../core/models/territory_option.dart';
import '../../../core/network/human_readable_error.dart';
import '../../../core/widgets/adaptive_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';

class NetworkPage extends StatefulWidget {
  const NetworkPage({
    super.key,
    required this.session,
    required this.controller,
  });

  final AppSession session;
  final AppController controller;

  @override
  State<NetworkPage> createState() => _NetworkPageState();
}

class _NetworkPageState extends State<NetworkPage> {
  final _searchController = TextEditingController();
  final _followUpTitleController = TextEditingController();
  final _followUpNoteController = TextEditingController();

  String _selectedFollowUpStatus = 'Follow-up';
  bool _isSaving = false;

  bool get _isAreaManager => widget.session.role == AppRole.areaManager;
  bool get _isFgg => widget.session.role == AppRole.fgg;
  bool get _isManagement => widget.session.role == AppRole.management;
  bool get _canCreateData => !_isManagement;
  bool get _canManageMitra => _isAreaManager || _isFgg;

  List<NetworkEntryType> get _allowedTypes {
    if (_canManageMitra) {
      return const [NetworkEntryType.ukm, NetworkEntryType.mitraHub];
    }
    return const [NetworkEntryType.ukm];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_refreshEntries(showFeedback: true));
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _followUpTitleController.dispose();
    _followUpNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final query = _searchController.text.trim().toLowerCase();
        final visibleEntries = widget.controller.ownNetworkEntriesForSession(
          widget.session,
        );
        final myUkmEntries = visibleEntries
            .where((entry) => entry.type == NetworkEntryType.ukm)
            .where(_isOwnedByCurrentUser)
            .where((entry) => _matchesSearch(entry, query))
            .toList();
        final areaUkmEntries = visibleEntries
            .where((entry) => entry.type == NetworkEntryType.ukm)
            .where((entry) => _isManagement || !_isOwnedByCurrentUser(entry))
            .where((entry) => _matchesSearch(entry, query))
            .toList();
        final myMitraEntries = visibleEntries
            .where((entry) => entry.type == NetworkEntryType.mitraHub)
            .where(_isOwnedByCurrentUser)
            .where((entry) => _matchesSearch(entry, query))
            .toList();
        final areaMitraEntries = visibleEntries
            .where((entry) => entry.type == NetworkEntryType.mitraHub)
            .where((entry) => _isManagement || !_isOwnedByCurrentUser(entry))
            .where((entry) => _matchesSearch(entry, query))
            .toList();
        final teamUkmEntries = _isAreaManager
            ? widget.controller
                .teamUkmEntriesForAreaManager(widget.session)
                .where((entry) => _matchesSearch(entry, query))
                .toList()
            : const <NetworkEntry>[];

        return Scaffold(
          floatingActionButton: _canCreateData
              ? FloatingActionButton(
                  onPressed: _isSaving ? null : _openCreateMenu,
                  child: const Icon(Icons.add_rounded),
                )
              : null,
          body: RefreshIndicator(
            onRefresh: _refreshEntries,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE7E5E4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isAreaManager
                            ? 'Monitoring Area dan Jaringan'
                            : _isManagement
                                ? 'Monitoring Jaringan Management'
                                : 'Pengembangan UKM Saya',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isAreaManager
                            ? 'Area Manager bisa menambah data di area mana saja. Data yang tampil tetap mengikuti wilayah kerja yang ditetapkan HR.'
                            : _isManagement
                                ? 'Management melihat UKM dan mitra sesuai wilayah kerja yang ditetapkan HR.'
                                : 'FGG bisa menambah UKM dan mitra di area mana saja. Data pribadi tetap tampil di menu Saya, sedangkan data area mengikuti wilayah kerja yang ditetapkan HR.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Cari nama / lokasi',
                          hintText: 'Contoh: Harapan atau Jagakarsa',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_isAreaManager) ...[
                  _NetworkSection(
                    title: 'UKM Tim FGG',
                    subtitle:
                        '${teamUkmEntries.length} data UKM FGG yang berada di wilayah kerja anda.',
                    entries: teamUkmEntries,
                    emptyMessage:
                        'Data UKM dari FGG akan muncul di sini sebagai monitoring area.',
                    onTap: (entry) => _showDetail(entry, canEdit: false),
                  ),
                  const SizedBox(height: 24),
                ],
                _NetworkSection(
                  title: _isManagement ? 'UKM Area Kerja' : 'UKM Saya',
                  subtitle: _isManagement
                      ? '${areaUkmEntries.length} data UKM di wilayah kerja ${widget.session.territoryLabel ?? widget.session.areaName}.'
                      : '${myUkmEntries.length} data UKM yang Anda buat sendiri, termasuk data di luar area kerja.',
                  entries: _isManagement ? areaUkmEntries : myUkmEntries,
                  emptyMessage: _isManagement
                      ? 'Belum ada data UKM di wilayah kerja management.'
                      : 'Tekan tombol tambah untuk membuat data UKM baru.',
                  onTap: (entry) => _showDetail(entry, canEdit: !_isManagement),
                ),
                if (!_isManagement) ...[
                  const SizedBox(height: 24),
                  _NetworkSection(
                    title: 'UKM Area Kerja',
                    subtitle:
                        '${areaUkmEntries.length} data UKM non-milik Anda yang berada di wilayah kerja ${widget.session.territoryLabel ?? widget.session.areaName}.',
                    entries: areaUkmEntries,
                    emptyMessage:
                        'Data UKM area kerja dari user lain akan muncul di sini.',
                    onTap: (entry) =>
                        _showDetail(entry, canEdit: !_isManagement),
                  ),
                ],
                if (_canManageMitra || _isManagement) ...[
                  const SizedBox(height: 24),
                  if (!_isManagement) ...[
                    _NetworkSection(
                      title: 'Mitra Saya',
                      subtitle:
                          '${myMitraEntries.length} data mitra yang Anda buat sendiri, termasuk data di luar area kerja.',
                      entries: myMitraEntries,
                      emptyMessage:
                          'Tekan tombol tambah untuk membuat data mitra baru.',
                      onTap: (entry) =>
                          _showDetail(entry, canEdit: !_isManagement),
                    ),
                    const SizedBox(height: 24),
                  ],
                  _NetworkSection(
                    title: 'Mitra Area Kerja',
                    subtitle: _isManagement
                        ? '${areaMitraEntries.length} data mitra di wilayah kerja ${widget.session.territoryLabel ?? widget.session.areaName}.'
                        : '${areaMitraEntries.length} data mitra non-milik Anda di wilayah kerja ${widget.session.territoryLabel ?? widget.session.areaName}.',
                    entries: areaMitraEntries,
                    emptyMessage: _isManagement
                        ? 'Belum ada data mitra di wilayah kerja management.'
                        : 'Data mitra area kerja dari user lain akan muncul di sini.',
                    onTap: (entry) =>
                        _showDetail(entry, canEdit: !_isManagement),
                  ),
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCreateMenu() async {
    final selectedType = await showModalBottomSheet<NetworkEntryType>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tambah Data',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Pilih jenis data yang ingin ditambahkan.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                ..._allowedTypes.map((type) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(type.icon),
                    title: Text('Tambah ${type.shortLabel}'),
                    subtitle: Text(
                      type == NetworkEntryType.ukm
                          ? 'Buat data UKM baru'
                          : 'Buat data mitra baru',
                    ),
                    onTap: () => Navigator.pop(context, type),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (selectedType == null || !mounted) {
      return;
    }

    await _openForm(type: selectedType);
  }

  Future<void> _refreshEntries({bool showFeedback = false}) async {
    try {
      await widget.controller.refreshNetworkDataForSession(widget.session);
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (!showFeedback) {
        rethrow;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Muat data jaringan gagal: ${humanReadableError(error, action: 'memuat data jaringan')}',
          ),
        ),
      );
    }
  }

  Future<void> _openForm({
    required NetworkEntryType type,
    NetworkEntry? existingEntry,
  }) async {
    final result = await Navigator.of(context).push<NetworkEntry>(
      MaterialPageRoute(
        builder: (context) => _NetworkFormPage(
          controller: widget.controller,
          session: widget.session,
          type: type,
          existingEntry: existingEntry,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.controller.upsertNetworkEntryForSession(
        widget.session,
        result,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingEntry == null
                ? 'Data berhasil masuk ke area ${result.territorySummary} dengan titik ${result.latitude?.toStringAsFixed(5)}, ${result.longitude?.toStringAsFixed(5)}'
                : 'Data wilayah kerja berhasil diperbarui di titik ${result.latitude?.toStringAsFixed(5)}, ${result.longitude?.toStringAsFixed(5)}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Simpan data jaringan gagal: ${humanReadableError(error, action: 'menyimpan data jaringan')}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showDetail(NetworkEntry entry, {required bool canEdit}) {
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final refreshedEntry = _resolveEntry(entry) ?? entry;

            return SafeArea(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (refreshedEntry.hasReadablePhoto)
                        AdaptiveImage(
                          path: refreshedEntry.photoPath!,
                          width: 56,
                          height: 56,
                          borderRadius: BorderRadius.circular(10),
                        )
                      else
                        Icon(
                          refreshedEntry.type.icon,
                          size: 32,
                          color: theme.colorScheme.primary,
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              refreshedEntry.name,
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(refreshedEntry.type.shortLabel),
                            const SizedBox(height: 8),
                            StatusBadge(
                              label: refreshedEntry.status,
                              color: refreshedEntry.statusColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _DetailLine(
                    label: 'Pemilik',
                    value: refreshedEntry.ownerName,
                  ),
                  const Divider(height: 24),
                  _DetailLine(
                    label: 'Dibuat',
                    value: refreshedEntry.createdAtLabel,
                  ),
                  const Divider(height: 24),
                  _DetailLine(
                    label: 'Wilayah',
                    value: refreshedEntry.territorySummary,
                  ),
                  const Divider(height: 24),
                  _DetailLine(label: 'Alamat', value: refreshedEntry.address),
                  const Divider(height: 24),
                  _DetailLine(
                    label: 'Jenis Usaha',
                    value: refreshedEntry.businessType,
                  ),
                  const Divider(height: 24),
                  _DetailLine(label: 'Nomor HP', value: refreshedEntry.phone),
                  if (refreshedEntry.type == NetworkEntryType.mitraHub) ...[
                    const Divider(height: 24),
                    _DetailLine(
                      label: 'Referensi',
                      value: refreshedEntry.reference.isEmpty
                          ? '-'
                          : refreshedEntry.reference,
                    ),
                    const Divider(height: 24),
                    _DetailLine(
                      label: 'Personality',
                      value: '${refreshedEntry.personalityScore ?? 0}%',
                    ),
                    if (refreshedEntry.personalityScores.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _CompactScoreList(
                        scores: refreshedEntry.personalityScores,
                      ),
                    ],
                    const Divider(height: 24),
                    _DetailLine(
                      label: 'Dokumen Valid',
                      value:
                          '${refreshedEntry.validDocumentCount}/${refreshedEntry.documents.length}',
                    ),
                    if (refreshedEntry.documents.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _CompactDocumentList(documents: refreshedEntry.documents),
                    ],
                  ],
                  const Divider(height: 24),
                  _DetailLine(
                    label: 'Catatan',
                    value: refreshedEntry.notes.isEmpty
                        ? '-'
                        : refreshedEntry.notes,
                  ),
                  const SizedBox(height: 20),
                  Text('Histori Follow-up', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    'Setiap catatan kunjungan atau tindak lanjut terbaru akan tersimpan di sini.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (refreshedEntry.followUps.isEmpty)
                    const EmptyState(
                      icon: Icons.history_toggle_off_rounded,
                      title: 'Belum ada histori',
                      message:
                          'Tambahkan follow-up untuk menyimpan catatan kunjungan dan update status.',
                    )
                  else
                    for (var i = 0;
                        i < refreshedEntry.followUps.length;
                        i++) ...[
                      _FollowUpTile(followUp: refreshedEntry.followUps[i]),
                      if (i != refreshedEntry.followUps.length - 1)
                        const Divider(height: 24),
                    ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openFollowUpDialog(refreshedEntry);
                    },
                    icon: const Icon(Icons.note_add_rounded),
                    label: const Text('Tambah Follow-up'),
                  ),
                  if (canEdit) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteEntry(refreshedEntry);
                            },
                            child: const Text('Hapus'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await _openForm(
                                type: refreshedEntry.type,
                                existingEntry: refreshedEntry,
                              );
                            },
                            child: const Text('Edit'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openFollowUpDialog(NetworkEntry entry) async {
    _followUpTitleController.clear();
    _followUpNoteController.clear();
    _selectedFollowUpStatus =
        entry.status == 'Draft' ? 'Follow-up' : entry.status;
    var selectedStatus = _selectedFollowUpStatus;
    var isSubmitting = false;
    String? pendingFollowUpId;
    DateTime? pendingFollowUpCreatedAt;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text('Follow-up ${entry.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _followUpTitleController,
                      decoration: const InputDecoration(
                        labelText: 'Judul update',
                        hintText: 'Contoh: Kunjungan ulang',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _followUpNoteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Catatan',
                        hintText: 'Ringkas hasil follow-up atau kunjungan',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Status terbaru',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Draft', 'Follow-up', 'Lengkap']
                          .map(
                            (status) => ChoiceChip(
                              label: Text(status),
                              selected: selectedStatus == status,
                              onSelected: (_) {
                                setLocalState(() => selectedStatus = status);
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final dialogContext = context;
                          final rootMessenger = ScaffoldMessenger.of(
                            this.context,
                          );
                          final title = _followUpTitleController.text.trim();
                          final note = _followUpNoteController.text.trim();
                          if (title.isEmpty || note.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Judul dan catatan follow-up wajib diisi',
                                ),
                              ),
                            );
                            return;
                          }

                          final createdAt =
                              pendingFollowUpCreatedAt ??= DateTime.now();
                          final followUpId = pendingFollowUpId ??=
                              '${entry.id}-${createdAt.microsecondsSinceEpoch}';
                          setLocalState(() => isSubmitting = true);
                          try {
                            await widget.controller.addFollowUpToEntry(
                              entry: entry,
                              status: selectedStatus,
                              statusColor: _statusColorFor(selectedStatus),
                              followUp: NetworkFollowUp(
                                id: followUpId,
                                title: title,
                                note: note,
                                actorName: widget.session.userName,
                                createdAt: createdAt,
                              ),
                            );

                            _selectedFollowUpStatus = selectedStatus;
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            _showDetail(
                              _resolveEntry(entry) ?? entry,
                              canEdit: _canEdit(entry),
                            );
                          } catch (error) {
                            if (!mounted) {
                              return;
                            }
                            rootMessenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Follow-up gagal disimpan: ${humanReadableError(error, action: 'menyimpan follow-up')}',
                                ),
                              ),
                            );
                          } finally {
                            if (dialogContext.mounted) {
                              setLocalState(() => isSubmitting = false);
                            }
                          }
                        },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteEntry(NetworkEntry entry) async {
    try {
      await widget.controller.deleteNetworkEntryForSession(
        widget.session,
        entry.id,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${entry.name} dihapus dari daftar ${entry.ownerName}'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hapus data jaringan gagal: ${humanReadableError(error, action: 'menghapus data jaringan')}',
          ),
        ),
      );
    }
  }

  bool _matchesSearch(NetworkEntry entry, String query) {
    if (query.isEmpty) {
      return true;
    }

    final haystack =
        '${entry.name} ${entry.address} ${entry.ownerName}'.toLowerCase();
    return haystack.contains(query);
  }

  bool _canEdit(NetworkEntry entry) {
    return _isOwnedByCurrentUser(entry);
  }

  bool _isOwnedByCurrentUser(NetworkEntry entry) {
    return entry.ownerKey == widget.session.ownerKey ||
        entry.ownerKey == widget.session.userId;
  }

  NetworkEntry? _resolveEntry(NetworkEntry entry) {
    final ownEntries = widget.controller.ownNetworkEntriesForSession(
      widget.session,
    );
    for (final ownEntry in ownEntries) {
      if (ownEntry.id == entry.id) {
        return ownEntry;
      }
    }

    final teamEntries = widget.controller.teamUkmEntriesForAreaManager(
      widget.session,
    );
    for (final teamEntry in teamEntries) {
      if (teamEntry.id == entry.id) {
        return teamEntry;
      }
    }

    return null;
  }

  Color _statusColorFor(String status) {
    switch (status) {
      case 'Lengkap':
        return Colors.green;
      case 'Follow-up':
        return Colors.orange;
      case 'Draft':
        return Colors.teal;
      default:
        return Colors.blue;
    }
  }
}

class _NetworkFormPage extends StatefulWidget {
  const _NetworkFormPage({
    required this.controller,
    required this.session,
    required this.type,
    this.existingEntry,
  });

  final AppController controller;
  final AppSession session;
  final NetworkEntryType type;
  final NetworkEntry? existingEntry;

  bool get isEditing => existingEntry != null;

  @override
  State<_NetworkFormPage> createState() => _NetworkFormPageState();
}

class _NetworkFormPageState extends State<_NetworkFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  final _territoryProvinceController = TextEditingController();
  final _territoryCityController = TextEditingController();
  final _territoryDistrictController = TextEditingController();
  final _territorySubdistrictController = TextEditingController();
  final _imagePicker = ImagePicker();
  bool _isLoadingTerritories = false;
  bool _isCapturingGpsTerritory = false;
  bool _isSubmitting = false;
  bool _isManualTerritory = false;
  Position? _gpsTerritoryPosition;
  String? _gpsTerritoryAddress;
  String? _gpsTerritoryError;
  List<TerritoryOption> _provinceOptions = const [];
  List<TerritoryOption> _cityOptions = const [];
  List<TerritoryOption> _districtOptions = const [];
  List<TerritoryOption> _subdistrictOptions = const [];
  TerritoryOption? _selectedProvince;
  TerritoryOption? _selectedCity;
  TerritoryOption? _selectedDistrict;
  TerritoryOption? _selectedSubdistrict;

  late final Map<String, double> _personalityScores = {
    'Etika pribadi': 75,
    'Jiwa bisnis': 75,
    'Kolega': 75,
    'Rajin': 75,
    'Jujur': 75,
    'Komitmen kerja': 75,
    'Komunikatif': 75,
  };

  late final Map<String, PartnerDocumentState> _partnerDocuments = {
    'Fotocopy KTP': const PartnerDocumentState(),
    'Bukti transfer jaminan': const PartnerDocumentState(),
    'Survey lokasi': const PartnerDocumentState(),
    'Kapasitas gedung': const PartnerDocumentState(),
    'Akses transportasi': const PartnerDocumentState(),
  };

  XFile? _photo;

  @override
  void initState() {
    super.initState();
    final existingEntry = widget.existingEntry;
    if (existingEntry != null) {
      _isManualTerritory = true;
      _nameController.text = existingEntry.name;
      _addressController.text = existingEntry.address;
      _territoryProvinceController.text = existingEntry.territoryProvince;
      _territoryCityController.text = existingEntry.territoryCity;
      _territoryDistrictController.text = existingEntry.territoryDistrict;
      _territorySubdistrictController.text = existingEntry.territorySubdistrict;
      _businessTypeController.text = existingEntry.businessType;
      _phoneController.text = existingEntry.phone;
      _referenceController.text = existingEntry.reference;
      _notesController.text = existingEntry.notes;
      _photo = existingEntry.photoPath == null
          ? null
          : XFile(existingEntry.photoPath!);
      for (final item in existingEntry.personalityScores.entries) {
        _personalityScores[item.key] = item.value;
      }
      for (final item in existingEntry.documents.entries) {
        _partnerDocuments[item.key] = item.value;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _bootstrapTerritories();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _businessTypeController.dispose();
    _phoneController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    _territoryProvinceController.dispose();
    _territoryCityController.dispose();
    _territoryDistrictController.dispose();
    _territorySubdistrictController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapTerritories() async {
    setState(() => _isLoadingTerritories = true);
    try {
      final provinces = await widget.controller.territoryProvinces();
      final selectedProvince =
          _findByName(provinces, _territoryProvinceController.text);

      List<TerritoryOption> cities = const [];
      List<TerritoryOption> districts = const [];
      List<TerritoryOption> subdistricts = const [];
      TerritoryOption? selectedCity;
      TerritoryOption? selectedDistrict;
      TerritoryOption? selectedSubdistrict;

      if (selectedProvince != null) {
        cities = await widget.controller.territoryCities(selectedProvince.code);
        selectedCity = _findByName(cities, _territoryCityController.text);
      }

      if (selectedCity != null) {
        districts = await widget.controller.territoryDistricts(
          selectedCity.code,
        );
        selectedDistrict =
            _findByName(districts, _territoryDistrictController.text);
      }

      if (selectedDistrict != null) {
        subdistricts = await widget.controller.territorySubdistricts(
          selectedDistrict.code,
        );
        selectedSubdistrict = _findByName(
          subdistricts,
          _territorySubdistrictController.text,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _provinceOptions = provinces;
        _cityOptions = cities;
        _districtOptions = districts;
        _subdistrictOptions = subdistricts;
        _selectedProvince = selectedProvince;
        _selectedCity = selectedCity;
        _selectedDistrict = selectedDistrict;
        _selectedSubdistrict = selectedSubdistrict;
        _applySelectedTerritoryTexts();
        _isLoadingTerritories = false;
      });

      if (!widget.isEditing && !_isManualTerritory) {
        unawaited(_captureGpsTerritory());
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingTerritories = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Master wilayah gagal dimuat: ${humanReadableError(error, action: 'memuat pilihan wilayah')}',
          ),
        ),
      );
    }
  }

  TerritoryOption? _findByName(List<TerritoryOption> options, String rawName) {
    final normalizedTarget = _normalizeNullable(rawName);
    if (normalizedTarget == null) {
      return null;
    }

    for (final option in options) {
      if (_normalize(option.name) == normalizedTarget) {
        return option;
      }
    }

    return null;
  }

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  String? _normalizeNullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return _normalize(trimmed);
  }

  void _applySelectedTerritoryTexts() {
    _territoryProvinceController.text = _selectedProvince?.name ?? '';
    _territoryCityController.text = _selectedCity?.name ?? '';
    _territoryDistrictController.text = _selectedDistrict?.name ?? '';
    _territorySubdistrictController.text = _selectedSubdistrict?.name ?? '';
  }

  String _displayTerritoryText() {
    final parts = [
      _territorySubdistrictController.text,
      _territoryDistrictController.text,
      _territoryCityController.text,
      _territoryProvinceController.text,
    ].map((item) => item.trim()).where((item) => item.isNotEmpty).toList();

    return parts.isEmpty ? 'Belum ada wilayah terbaca' : parts.join(', ');
  }

  Future<void> _onProvinceChanged(TerritoryOption? province) async {
    setState(() {
      _isLoadingTerritories = true;
      _selectedProvince = province;
      _selectedCity = null;
      _selectedDistrict = null;
      _selectedSubdistrict = null;
      _cityOptions = const [];
      _districtOptions = const [];
      _subdistrictOptions = const [];
      _applySelectedTerritoryTexts();
    });

    if (province == null) {
      setState(() => _isLoadingTerritories = false);
      return;
    }

    final cities = await widget.controller.territoryCities(province.code);

    if (!mounted) {
      return;
    }

    setState(() {
      _cityOptions = cities;
      _applySelectedTerritoryTexts();
      _isLoadingTerritories = false;
    });
  }

  Future<void> _onCityChanged(TerritoryOption? city) async {
    setState(() {
      _isLoadingTerritories = true;
      _selectedCity = city;
      _selectedDistrict = null;
      _selectedSubdistrict = null;
      _districtOptions = const [];
      _subdistrictOptions = const [];
      _applySelectedTerritoryTexts();
    });

    if (city == null) {
      setState(() => _isLoadingTerritories = false);
      return;
    }

    final districts = await widget.controller.territoryDistricts(city.code);

    if (!mounted) {
      return;
    }

    setState(() {
      _districtOptions = districts;
      _applySelectedTerritoryTexts();
      _isLoadingTerritories = false;
    });
  }

  Future<void> _onDistrictChanged(TerritoryOption? district) async {
    setState(() {
      _isLoadingTerritories = true;
      _selectedDistrict = district;
      _selectedSubdistrict = null;
      _subdistrictOptions = const [];
      _applySelectedTerritoryTexts();
    });

    if (district == null) {
      setState(() => _isLoadingTerritories = false);
      return;
    }

    final subdistricts =
        await widget.controller.territorySubdistricts(district.code);

    if (!mounted) {
      return;
    }

    setState(() {
      _subdistrictOptions = subdistricts;
      _applySelectedTerritoryTexts();
      _isLoadingTerritories = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? 'Edit ${widget.type.shortLabel}'
              : 'Tambah ${widget.type.shortLabel}',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.isEditing
                  ? 'Perbarui data ${widget.type.shortLabel.toLowerCase()} di wilayah kerja ${widget.session.territoryLabel ?? widget.session.areaName}.'
                  : 'Isi form untuk menambahkan ${widget.type.shortLabel.toLowerCase()} baru.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Wilayah kerja aktif: ${widget.session.territoryLabel ?? widget.session.areaName}. Anda tetap bisa tambah data di area lain; data akan tampil untuk user yang wilayah kerjanya sesuai area data tersebut.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_isLoadingTerritories) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 3),
            ],
            const SizedBox(height: 16),
            StatusBadge(label: widget.type.shortLabel, color: Colors.teal),
            const SizedBox(height: 20),
            _PhotoPickerLine(
              photo: _photo,
              onCamera: () => _pickPhoto(ImageSource.camera),
              onRemove: () => setState(() => _photo = null),
            ),
            const Divider(height: 24),
            ..._buildTerritoryFields(),
            _TextInput(
              controller: _nameController,
              label: widget.type.nameLabel,
              hint: 'Masukkan ${widget.type.nameLabel.toLowerCase()}',
              required: true,
            ),
            const Divider(height: 24),
            _TextInput(
              controller: _addressController,
              label: 'Alamat',
              hint: 'Masukkan alamat singkat',
              required: true,
              maxLines: 2,
            ),
            const Divider(height: 24),
            _TextInput(
              controller: _businessTypeController,
              label: 'Jenis Usaha',
              hint: 'Contoh: sembako, kuliner, jasa',
              required: true,
            ),
            const Divider(height: 24),
            _TextInput(
              controller: _phoneController,
              label: 'Nomor HP',
              hint: '08xxxxxxxxxx',
              keyboardType: TextInputType.phone,
              required: true,
              validator: _validatePhone,
            ),
            if (widget.type == NetworkEntryType.mitraHub) ...[
              const Divider(height: 24),
              _TextInput(
                controller: _referenceController,
                label: 'Referensi',
                hint: 'Nama referensi bila ada',
              ),
              const Divider(height: 24),
              _PersonalityScoring(
                scores: _personalityScores,
                onChanged: (label, value) {
                  setState(() => _personalityScores[label] = value);
                },
              ),
              const Divider(height: 24),
              _PartnerDocumentChecklist(
                documents: _partnerDocuments,
                onChanged: (label, state) {
                  setState(() => _partnerDocuments[label] = state);
                },
              ),
            ],
            const Divider(height: 24),
            _TextInput(
              controller: _notesController,
              label: 'Catatan',
              hint: 'Tambahkan catatan bila diperlukan',
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: Text(widget.isEditing ? 'Update' : 'Simpan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTerritoryFields() {
    return [
      _GpsTerritoryCard(
        isManual: _isManualTerritory,
        isLoading: _isCapturingGpsTerritory,
        position: _gpsTerritoryPosition,
        address: _gpsTerritoryAddress,
        errorText: _gpsTerritoryError,
        territoryText: _displayTerritoryText(),
        onRefresh: _captureGpsTerritory,
        onUseManual: () => setState(() => _isManualTerritory = true),
        onUseGps: () {
          setState(() => _isManualTerritory = false);
          unawaited(_captureGpsTerritory());
        },
      ),
      if (_isManualTerritory) ...[
        const Divider(height: 24),
        _TerritoryDropdownField(
          label: 'Provinsi',
          value: _selectedProvince,
          items: _provinceOptions,
          enabled: !_isProvinceLocked && _provinceOptions.isNotEmpty,
          hint: _provinceOptions.isEmpty
              ? 'Wilayah provinsi tidak tersedia'
              : 'Pilih provinsi',
          onChanged: _onProvinceChanged,
        ),
        const Divider(height: 24),
        if (_selectedProvince != null && _cityOptions.isEmpty)
          _TextInput(
            controller: _territoryCityController,
            label: 'Kota/Kabupaten',
            hint: 'Ketik kota/kabupaten',
            required: true,
          )
        else
          _TerritoryDropdownField(
            label: 'Kota/Kabupaten',
            value: _selectedCity,
            items: _cityOptions,
            enabled: !_isCityLocked && _selectedProvince != null,
            hint: _selectedProvince == null
                ? 'Pilih provinsi dulu'
                : _cityOptions.isEmpty
                    ? 'Tidak ada kota/kabupaten yang sesuai'
                    : 'Pilih kota/kabupaten',
            onChanged: _onCityChanged,
          ),
        const Divider(height: 24),
        if ((_selectedCity != null ||
                _territoryCityController.text.trim().isNotEmpty) &&
            _districtOptions.isEmpty)
          _TextInput(
            controller: _territoryDistrictController,
            label: 'Kecamatan',
            hint: 'Ketik kecamatan',
            required: true,
          )
        else
          _TerritoryDropdownField(
            label: 'Kecamatan',
            value: _selectedDistrict,
            items: _districtOptions,
            enabled: !_isDistrictLocked && _selectedCity != null,
            hint: _selectedCity == null
                ? 'Pilih kota/kabupaten dulu'
                : _districtOptions.isEmpty
                    ? 'Tidak ada kecamatan yang sesuai'
                    : 'Pilih kecamatan',
            onChanged: _onDistrictChanged,
          ),
        const Divider(height: 24),
        if ((_selectedDistrict != null ||
                _territoryDistrictController.text.trim().isNotEmpty) &&
            _subdistrictOptions.isEmpty)
          _TextInput(
            controller: _territorySubdistrictController,
            label: 'Kelurahan',
            hint: 'Ketik kelurahan',
            required: true,
          )
        else
          _TerritoryDropdownField(
            label: 'Kelurahan',
            value: _selectedSubdistrict,
            items: _subdistrictOptions,
            enabled: !_isSubdistrictLocked && _selectedDistrict != null,
            hint: _selectedDistrict == null
                ? 'Pilih kecamatan dulu'
                : _subdistrictOptions.isEmpty
                    ? 'Tidak ada kelurahan yang sesuai'
                    : 'Pilih kelurahan',
            onChanged: (value) {
              setState(() {
                _selectedSubdistrict = value;
                _applySelectedTerritoryTexts();
              });
            },
          ),
      ],
      const Divider(height: 24),
    ];
  }

  Future<void> _captureGpsTerritory() async {
    setState(() {
      _isCapturingGpsTerritory = true;
      _gpsTerritoryError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const _NetworkLocationException(
          'GPS belum aktif. Aktifkan lokasi device atau isi alamat manual.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const _NetworkLocationException(
          'Izin lokasi dibutuhkan untuk membaca wilayah otomatis. Anda tetap bisa isi manual.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 5));
      final place = placemarks.isEmpty ? null : placemarks.first;

      if (place == null) {
        throw const _NetworkLocationException(
          'Alamat GPS belum berhasil dibaca. Silakan isi manual jika perlu.',
        );
      }

      await _applyTerritoryFromPlacemark(place);

      if (!mounted) {
        return;
      }

      final address = _formatPlacemarkAddress(place);
      final hasCompleteTerritory =
          _territoryProvinceController.text.trim().isNotEmpty &&
              _territoryCityController.text.trim().isNotEmpty &&
              _territoryDistrictController.text.trim().isNotEmpty &&
              _territorySubdistrictController.text.trim().isNotEmpty;

      setState(() {
        _gpsTerritoryPosition = position;
        _gpsTerritoryAddress = address;
        _gpsTerritoryError = hasCompleteTerritory
            ? null
            : 'Wilayah GPS belum lengkap. Cek hasilnya atau isi manual.';
      });
    } on _NetworkLocationException catch (error) {
      if (mounted) {
        setState(() {
          _gpsTerritoryPosition = null;
          _gpsTerritoryAddress = null;
          _gpsTerritoryError = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _gpsTerritoryPosition = null;
          _gpsTerritoryAddress = null;
          _gpsTerritoryError =
              'Lokasi belum berhasil dibaca. Coba refresh atau isi manual.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturingGpsTerritory = false);
      }
    }
  }

  Future<void> _applyTerritoryFromPlacemark(Placemark place) async {
    final provinceCandidates = [
      place.administrativeArea,
      place.country,
    ];
    final cityCandidates = [
      place.subAdministrativeArea,
      place.locality,
    ];
    final districtCandidates = [
      place.locality,
      place.subLocality,
    ];
    final subdistrictCandidates = [
      place.subLocality,
      place.thoroughfare,
    ];

    final selectedProvince =
        _findBestTerritoryMatch(_provinceOptions, provinceCandidates);
    var cities = _cityOptions;
    TerritoryOption? selectedCity;
    var districts = _districtOptions;
    TerritoryOption? selectedDistrict;
    var subdistricts = _subdistrictOptions;
    TerritoryOption? selectedSubdistrict;

    if (selectedProvince != null) {
      cities = await widget.controller.territoryCities(selectedProvince.code);
      selectedCity = _findBestTerritoryMatch(cities, cityCandidates);
    }

    if (selectedCity != null) {
      districts = await widget.controller.territoryDistricts(selectedCity.code);
      selectedDistrict = _findBestTerritoryMatch(districts, districtCandidates);
    }

    if (selectedDistrict != null) {
      subdistricts =
          await widget.controller.territorySubdistricts(selectedDistrict.code);
      selectedSubdistrict =
          _findBestTerritoryMatch(subdistricts, subdistrictCandidates);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _cityOptions = cities;
      _districtOptions = districts;
      _subdistrictOptions = subdistricts;
      _selectedProvince = selectedProvince;
      _selectedCity = selectedCity;
      _selectedDistrict = selectedDistrict;
      _selectedSubdistrict = selectedSubdistrict;
      _territoryProvinceController.text =
          selectedProvince?.name ?? _firstReadable(provinceCandidates);
      _territoryCityController.text =
          selectedCity?.name ?? _firstReadable(cityCandidates);
      _territoryDistrictController.text =
          selectedDistrict?.name ?? _firstReadable(districtCandidates);
      _territorySubdistrictController.text =
          selectedSubdistrict?.name ?? _firstReadable(subdistrictCandidates);
    });
  }

  TerritoryOption? _findBestTerritoryMatch(
    List<TerritoryOption> options,
    List<String?> candidates,
  ) {
    final normalizedCandidates = candidates
        .whereType<String>()
        .map(_normalizeTerritoryName)
        .where((item) => item.isNotEmpty)
        .toList();

    if (normalizedCandidates.isEmpty) {
      return null;
    }

    for (final option in options) {
      final normalizedOption = _normalizeTerritoryName(option.name);
      for (final candidate in normalizedCandidates) {
        if (normalizedOption == candidate ||
            normalizedOption.contains(candidate) ||
            candidate.contains(normalizedOption)) {
          return option;
        }
      }
    }

    return null;
  }

  String _normalizeTerritoryName(String value) {
    return value
        .toLowerCase()
        .replaceAll(
            RegExp(
                r'\b(provinsi|province|kabupaten|kab|kota|city|administrasi|kecamatan|kelurahan|desa|daerah|khusus|ibukota|dki)\b'),
            ' ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _firstReadable(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return '';
  }

  String _formatPlacemarkAddress(Placemark place) {
    final parts = [
      place.street,
      place.subLocality,
      place.locality,
      place.subAdministrativeArea,
      place.administrativeArea,
      place.postalCode,
    ]
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();

    return parts.join(', ');
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final photo = await _imagePicker.pickImage(
      source: source,
      imageQuality: 52,
      maxWidth: 960,
      maxHeight: 960,
    );
    if (photo == null) {
      return;
    }

    setState(() => _photo = photo);
  }

  String? _validatePhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Nomor HP wajib diisi';
    }

    final numeric = RegExp(r'^[0-9+ ]+$').hasMatch(text);
    if (!numeric || text.replaceAll(RegExp(r'[^0-9]'), '').length < 10) {
      return 'Nomor HP belum valid';
    }

    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_territoryProvinceController.text.trim().isEmpty ||
        _territoryCityController.text.trim().isEmpty ||
        _territoryDistrictController.text.trim().isEmpty ||
        _territorySubdistrictController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Wilayah sampai level kelurahan wajib terisi. Gunakan GPS atau isi manual.',
          ),
        ),
      );
      return;
    }
    if (_photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto wajib diambil dari kamera HP')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      if (!_isManualTerritory && _gpsTerritoryPosition == null) {
        await _captureGpsTerritory();
      }

      if (!mounted) {
        return;
      }

      final location = _gpsTerritoryPosition;
      if (!_isManualTerritory && location == null) {
        _showLocationError(
          'Lokasi GPS belum siap. Refresh lokasi atau isi manual jika GPS bermasalah.',
        );
        return;
      }

      final existingEntry = widget.existingEntry;
      final personalityScore = _personalityAverage.round();
      final documentComplete = _partnerDocuments.values
          .where((item) => item.exists && item.isValid)
          .length;
      final status = switch (widget.type) {
        NetworkEntryType.ukm => existingEntry?.status ?? 'Draft',
        NetworkEntryType.mitraHub =>
          documentComplete == _partnerDocuments.length
              ? 'Lengkap'
              : 'Follow-up',
      };

      Navigator.pop(
        context,
        NetworkEntry(
          id: existingEntry?.id ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          ownerKey: widget.session.ownerKey,
          ownerName: widget.session.userName,
          ownerRole: widget.session.role,
          type: widget.type,
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          territoryProvince: _territoryProvinceController.text.trim(),
          territoryCity: _territoryCityController.text.trim(),
          territoryDistrict: _territoryDistrictController.text.trim(),
          territorySubdistrict: _territorySubdistrictController.text.trim(),
          businessType: _businessTypeController.text.trim(),
          phone: _phoneController.text.trim(),
          reference: _referenceController.text.trim(),
          notes: _notesController.text.trim(),
          photoPath: _photo?.path,
          status: status,
          statusColor: _statusColorFor(status),
          personalityScore: widget.type == NetworkEntryType.mitraHub
              ? personalityScore
              : null,
          personalityScores: widget.type == NetworkEntryType.mitraHub
              ? Map<String, double>.from(_personalityScores)
              : const {},
          documents: widget.type == NetworkEntryType.mitraHub
              ? Map<String, PartnerDocumentState>.from(_partnerDocuments)
              : const {},
          followUps: existingEntry?.followUps ?? const [],
          createdAt: existingEntry?.createdAt ?? DateTime.now(),
          latitude: location?.latitude,
          longitude: location?.longitude,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showLocationError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  double get _personalityAverage {
    final total = _personalityScores.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    return total / _personalityScores.length;
  }

  bool get _isProvinceLocked {
    return false;
  }

  bool get _isCityLocked {
    // Kota/kecamatan/kelurahan tetap bisa dibuka agar FGG dapat memilih
    // alamat UKM/Mitra secara lengkap di dalam area kerja yang sudah difilter.
    return false;
  }

  bool get _isDistrictLocked {
    return false;
  }

  bool get _isSubdistrictLocked {
    return false;
  }

  Color _statusColorFor(String status) {
    switch (status) {
      case 'Lengkap':
        return Colors.green;
      case 'Follow-up':
        return Colors.orange;
      case 'Draft':
        return Colors.teal;
      default:
        return Colors.blue;
    }
  }
}

class _NetworkLocationException implements Exception {
  const _NetworkLocationException(this.message);

  final String message;
}

class _NetworkSection extends StatefulWidget {
  const _NetworkSection({
    required this.title,
    required this.subtitle,
    required this.entries,
    required this.emptyMessage,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final List<NetworkEntry> entries;
  final String emptyMessage;
  final ValueChanged<NetworkEntry> onTap;

  @override
  State<_NetworkSection> createState() => _NetworkSectionState();
}

class _NetworkSectionState extends State<_NetworkSection> {
  static const _itemsPerPage = 10;
  int _pageIndex = 0;

  @override
  void didUpdateWidget(covariant _NetworkSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries.length != widget.entries.length ||
        oldWidget.title != widget.title) {
      final lastPageIndex = _lastPageIndex(widget.entries.length);
      if (_pageIndex > lastPageIndex) {
        _pageIndex = lastPageIndex;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalPages = _totalPages(widget.entries.length);
    final start = _pageIndex * _itemsPerPage;
    final end = math.min(start + _itemsPerPage, widget.entries.length);
    final pageEntries = widget.entries.isEmpty
        ? const <NetworkEntry>[]
        : widget.entries.sublist(start, end);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(widget.title, style: theme.textTheme.titleMedium),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            widget.subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        children: [
          if (widget.entries.isEmpty)
            EmptyState(
              icon: Icons.folder_open_rounded,
              title: '${widget.title} masih kosong',
              message: widget.emptyMessage,
            )
          else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Menampilkan ${start + 1}-$end dari ${widget.entries.length} data',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < pageEntries.length; i++) ...[
              _NetworkItem(
                entry: pageEntries[i],
                onTap: () => widget.onTap(pageEntries[i]),
              ),
              if (i != pageEntries.length - 1) const SizedBox(height: 12),
            ],
            if (totalPages > 1) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pageIndex == 0
                          ? null
                          : () => setState(() => _pageIndex--),
                      child: const Text('Sebelumnya'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_pageIndex + 1} / $totalPages',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pageIndex >= totalPages - 1
                          ? null
                          : () => setState(() => _pageIndex++),
                      child: const Text('Berikutnya'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  int _lastPageIndex(int length) {
    return math.max(0, _totalPages(length) - 1);
  }

  int _totalPages(int length) {
    if (length <= 0) {
      return 1;
    }
    return (length / _itemsPerPage).ceil();
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _FollowUpTile extends StatelessWidget {
  const _FollowUpTile({required this.followUp});

  final NetworkFollowUp followUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.history_rounded, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(followUp.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                followUp.note,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${followUp.actorName} - ${followUp.createdAtLabel}',
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

class _CompactScoreList extends StatelessWidget {
  const _CompactScoreList({required this.scores});

  final Map<String, double> scores;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: scores.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(entry.key, style: theme.textTheme.bodyMedium),
              ),
              Text(
                '${entry.value.round()}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CompactDocumentList extends StatelessWidget {
  const _CompactDocumentList({required this.documents});

  final Map<String, PartnerDocumentState> documents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: documents.entries.map((entry) {
        final label = entry.value.exists
            ? entry.value.isValid
                ? 'Valid'
                : 'Tidak Valid'
            : 'Belum Ada';
        final color = entry.value.exists
            ? entry.value.isValid
                ? Colors.green
                : Colors.orange
            : Colors.blueGrey;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(entry.key, style: theme.textTheme.bodyMedium),
              ),
              StatusBadge(label: label, color: color),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _GpsTerritoryCard extends StatelessWidget {
  const _GpsTerritoryCard({
    required this.isManual,
    required this.isLoading,
    required this.position,
    required this.address,
    required this.errorText,
    required this.territoryText,
    required this.onRefresh,
    required this.onUseManual,
    required this.onUseGps,
  });

  final bool isManual;
  final bool isLoading;
  final Position? position;
  final String? address;
  final String? errorText;
  final String territoryText;
  final Future<void> Function() onRefresh;
  final VoidCallback onUseManual;
  final VoidCallback onUseGps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPosition = position != null;
    final coordinates = hasPosition
        ? '${position!.latitude.toStringAsFixed(6)}, ${position!.longitude.toStringAsFixed(6)}'
        : 'Belum ada titik GPS';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isManual ? const Color(0xFFFFFBEB) : const Color(0xFFEFFAF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isManual ? const Color(0xFFFDE68A) : const Color(0xFFBBE7C7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    isManual ? const Color(0xFFFEF3C7) : Colors.white,
                foregroundColor:
                    isManual ? const Color(0xFFB45309) : Colors.teal,
                child: Icon(
                  isManual
                      ? Icons.edit_location_alt_rounded
                      : Icons.my_location_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isManual ? 'Wilayah manual' : 'Wilayah otomatis dari GPS',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isManual
                          ? 'Isi wilayah seperti form lama jika GPS/alamat tidak sesuai.'
                          : 'Aplikasi membaca GPS lalu mengisi area data otomatis.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: isLoading ? null : onRefresh,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _GpsInfoLine(label: 'Area data', value: territoryText),
          const SizedBox(height: 8),
          _GpsInfoLine(label: 'Koordinat', value: coordinates),
          if (address != null && address!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _GpsInfoLine(label: 'Alamat GPS', value: address!),
          ],
          if (errorText != null && errorText!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isManual)
                FilledButton.tonalIcon(
                  onPressed: isLoading ? null : onUseGps,
                  icon: const Icon(Icons.my_location_rounded),
                  label: const Text('Gunakan GPS'),
                )
              else
                FilledButton.tonalIcon(
                  onPressed: onUseManual,
                  icon: const Icon(Icons.edit_location_alt_rounded),
                  label: const Text('Isi manual'),
                ),
              TextButton.icon(
                onPressed: isLoading ? null : onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh lokasi'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GpsInfoLine extends StatelessWidget {
  const _GpsInfoLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _TerritoryDropdownField extends StatelessWidget {
  const _TerritoryDropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.enabled,
    required this.hint,
    required this.onChanged,
  });

  final String label;
  final TerritoryOption? value;
  final List<TerritoryOption> items;
  final bool enabled;
  final String hint;
  final ValueChanged<TerritoryOption?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              '$label *',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<TerritoryOption>(
            key: ValueKey(
              '${label}_${value?.code ?? 'none'}_${items.length}_$enabled',
            ),
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(hintText: hint),
            items: items
                .map(
                  (item) => DropdownMenuItem<TerritoryOption>(
                    value: item,
                    child: Text(item.name),
                  ),
                )
                .toList(),
            onChanged: enabled ? onChanged : null,
            validator: (selected) {
              if (selected == null) {
                return '$label wajib dipilih';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.label,
    required this.hint,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              required ? '$label *' : label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(hintText: hint),
            validator: validator ??
                (value) {
                  if (required && (value == null || value.trim().isEmpty)) {
                    return '$label wajib diisi';
                  }
                  return null;
                },
          ),
        ),
      ],
    );
  }
}

class _PhotoPickerLine extends StatelessWidget {
  const _PhotoPickerLine({
    required this.photo,
    required this.onCamera,
    required this.onRemove,
  });

  final XFile? photo;
  final VoidCallback onCamera;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedPhoto = photo;
    final hasReadablePhoto =
        selectedPhoto != null && File(selectedPhoto.path).existsSync();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Foto *',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectedPhoto != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasReadablePhoto)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(selectedPhoto.path),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Icon(
                        Icons.image_not_supported_rounded,
                        size: 36,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Foto dipilih',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            selectedPhoto.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(onPressed: onRemove, child: const Text('Hapus')),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: onCamera,
                    icon: const Icon(Icons.photo_camera_rounded),
                    label: const Text('Ambil dari kamera'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PersonalityScoring extends StatelessWidget {
  const _PersonalityScoring({required this.scores, required this.onChanged});

  final Map<String, double> scores;
  final void Function(String label, double value) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final average = scores.values.fold<double>(0, (sum, value) => sum + value) /
        scores.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personality',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text('${average.round()}%', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final entry in scores.entries) ...[
          _ScoreSlider(
            label: entry.key,
            value: entry.value,
            onChanged: (value) => onChanged(entry.key, value),
          ),
          if (entry.key != scores.keys.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ScoreSlider extends StatelessWidget {
  const _ScoreSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            Text(
              value.round().toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 50,
          max: 100,
          divisions: 10,
          label: value.round().toString(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _PartnerDocumentChecklist extends StatelessWidget {
  const _PartnerDocumentChecklist({
    required this.documents,
    required this.onChanged,
  });

  final Map<String, PartnerDocumentState> documents;
  final void Function(String label, PartnerDocumentState state) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completeCount =
        documents.values.where((item) => item.exists && item.isValid).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dokumen',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$completeCount/${documents.length} valid',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final entry in documents.entries) ...[
          _PartnerDocumentRow(
            label: entry.key,
            state: entry.value,
            onChanged: (state) => onChanged(entry.key, state),
          ),
          if (entry.key != documents.keys.last) const Divider(height: 20),
        ],
      ],
    );
  }
}

class _PartnerDocumentRow extends StatelessWidget {
  const _PartnerDocumentRow({
    required this.label,
    required this.state,
    required this.onChanged,
  });

  final String label;
  final PartnerDocumentState state;
  final ValueChanged<PartnerDocumentState> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Ada'),
              selected: state.exists,
              onSelected: (selected) =>
                  onChanged(state.copyWith(exists: selected)),
            ),
            ChoiceChip(
              label: const Text('Tidak Ada'),
              selected: !state.exists,
              onSelected: (selected) =>
                  onChanged(state.copyWith(exists: !selected, isValid: false)),
            ),
            ChoiceChip(
              label: const Text('Valid'),
              selected: state.isValid,
              onSelected: state.exists
                  ? (selected) => onChanged(state.copyWith(isValid: selected))
                  : null,
            ),
            ChoiceChip(
              label: const Text('Tidak Valid'),
              selected: state.exists && !state.isValid,
              onSelected: state.exists
                  ? (selected) => onChanged(state.copyWith(isValid: !selected))
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _NetworkItem extends StatelessWidget {
  const _NetworkItem({required this.entry, required this.onTap});

  final NetworkEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = switch (entry.type) {
      NetworkEntryType.ukm => theme.colorScheme.primary,
      NetworkEntryType.mitraHub => const Color(0xFFB45309),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.32,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.hasReadablePhoto)
              AdaptiveImage(
                path: entry.photoPath!,
                width: 38,
                height: 38,
                borderRadius: BorderRadius.circular(8),
              )
            else
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(entry.type.icon, size: 20, color: accent),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          entry.name,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.type.shortLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusBadge(
                        label: entry.status,
                        color: entry.statusColor,
                      ),
                      Text(
                        'Follow-up: ${entry.latestFollowUpLabel}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (entry.ownerRole == AppRole.fgg)
                        Text(
                          'Owner: ${entry.ownerName}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
