import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app_controller.dart';
import '../../../core/enums/app_role.dart';
import '../../../core/models/app_session.dart';
import '../../../core/models/network_entry.dart';
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
  bool _isSubmittingFollowUp = false;

  bool get _isAreaManager => widget.session.role == AppRole.areaManager;

  List<NetworkEntryType> get _allowedTypes {
    if (_isAreaManager) {
      return const [NetworkEntryType.ukm, NetworkEntryType.mitraHub];
    }
    return const [NetworkEntryType.ukm];
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
        final ownEntries = widget.controller.ownNetworkEntriesForSession(
          widget.session,
        );
        final ownUkmEntries = ownEntries
            .where((entry) => entry.type == NetworkEntryType.ukm)
            .where((entry) => _matchesSearch(entry, query))
            .toList();
        final ownMitraEntries = ownEntries
            .where((entry) => entry.type == NetworkEntryType.mitraHub)
            .where((entry) => _matchesSearch(entry, query))
            .toList();
        final teamUkmEntries = _isAreaManager
            ? widget.controller.teamUkmEntriesForAreaManager(widget.session)
                .where((entry) => _matchesSearch(entry, query))
                .toList()
            : const <NetworkEntry>[];

        return Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: _isSaving ? null : _openCreateMenu,
            child: const Icon(Icons.add_rounded),
          ),
          body: ListView(
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
                          : 'Pengembangan UKM Saya',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isAreaManager
                          ? 'Area Manager bisa menambah UKM dan Mitra lewat tombol tambah, sekaligus melihat UKM yang sudah ditambahkan oleh tim FGG.'
                          : 'FGG bisa menambah UKM lewat tombol tambah. Semua UKM yang dibuat akan menjadi milik FGG ini.',
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
              _NetworkSection(
                title: 'UKM Saya',
                subtitle:
                    '${ownUkmEntries.length} data UKM milik ${widget.session.userName}.',
                entries: ownUkmEntries,
                emptyMessage: 'Tekan tombol tambah untuk membuat data UKM baru.',
                onTap: (entry) => _showDetail(entry, canEdit: true),
              ),
              if (_isAreaManager) ...[
                const SizedBox(height: 24),
                _NetworkSection(
                  title: 'Mitra Saya',
                  subtitle:
                      '${ownMitraEntries.length} data mitra milik ${widget.session.userName}.',
                  entries: ownMitraEntries,
                  emptyMessage:
                      'Tekan tombol tambah untuk membuat data mitra baru.',
                  onTap: (entry) => _showDetail(entry, canEdit: true),
                ),
                const SizedBox(height: 24),
                _NetworkSection(
                  title: 'UKM Tim FGG',
                  subtitle:
                      '${teamUkmEntries.length} data UKM yang sudah ditambahkan tim FGG.',
                  entries: teamUkmEntries,
                  emptyMessage:
                      'Data UKM dari FGG akan muncul di sini sebagai monitoring area.',
                  onTap: (entry) => _showDetail(entry, canEdit: false),
                ),
              ],
              const SizedBox(height: 80),
            ],
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

  Future<void> _openForm({
    required NetworkEntryType type,
    NetworkEntry? existingEntry,
  }) async {
    final result = await Navigator.of(context).push<NetworkEntry>(
      MaterialPageRoute(
        builder: (context) => _NetworkFormPage(
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
      await widget.controller.upsertNetworkEntryForSession(widget.session, result);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingEntry == null
                ? 'Data masuk ke daftar milik ${widget.session.userName}'
                : 'Data milik ${widget.session.userName} berhasil diperbarui',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Simpan data jaringan gagal: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showDetail(
    NetworkEntry entry, {
    required bool canEdit,
  }) {
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
                  _DetailLine(label: 'Pemilik', value: refreshedEntry.ownerName),
                  const Divider(height: 24),
                  _DetailLine(
                    label: 'Dibuat',
                    value: refreshedEntry.createdAtLabel,
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
                      _CompactScoreList(scores: refreshedEntry.personalityScores),
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
                    value:
                        refreshedEntry.notes.isEmpty ? '-' : refreshedEntry.notes,
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
                    for (var i = 0; i < refreshedEntry.followUps.length; i++) ...[
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
    _selectedFollowUpStatus = entry.status == 'Draft' ? 'Follow-up' : entry.status;

    await showDialog<void>(
      context: context,
      builder: (context) {
        String selectedStatus = _selectedFollowUpStatus;

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
                  onPressed: _isSubmittingFollowUp
                      ? null
                      : () async {
                    final dialogContext = context;
                    final rootMessenger = ScaffoldMessenger.of(this.context);
                    final title = _followUpTitleController.text.trim();
                    final note = _followUpNoteController.text.trim();
                    if (title.isEmpty || note.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Judul dan catatan follow-up wajib diisi'),
                        ),
                      );
                      return;
                    }

                    setState(() => _isSubmittingFollowUp = true);
                    try {
                      await widget.controller.addFollowUpToEntry(
                        entry: entry,
                        status: selectedStatus,
                        statusColor: _statusColorFor(selectedStatus),
                        followUp: NetworkFollowUp(
                          title: title,
                          note: note,
                          actorName: widget.session.userName,
                          createdAt: DateTime.now(),
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
                          content: Text('Follow-up gagal disimpan: $error'),
                        ),
                      );
                    } finally {
                      if (mounted) {
                        setState(() => _isSubmittingFollowUp = false);
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
      await widget.controller.deleteNetworkEntryForSession(widget.session, entry.id);
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
        SnackBar(content: Text('Hapus data jaringan gagal: $error')),
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
    return entry.ownerKey == widget.session.ownerKey;
  }

  NetworkEntry? _resolveEntry(NetworkEntry entry) {
    final ownEntries = widget.controller.ownNetworkEntriesForSession(widget.session);
    for (final ownEntry in ownEntries) {
      if (ownEntry.id == entry.id) {
        return ownEntry;
      }
    }

    final teamEntries = widget.controller.teamUkmEntriesForAreaManager(widget.session);
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
    required this.session,
    required this.type,
    this.existingEntry,
  });

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
  final _imagePicker = ImagePicker();

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
      _nameController.text = existingEntry.name;
      _addressController.text = existingEntry.address;
      _businessTypeController.text = existingEntry.businessType;
      _phoneController.text = existingEntry.phone;
      _referenceController.text = existingEntry.reference;
      _notesController.text = existingEntry.notes;
      _photo = existingEntry.photoPath == null ? null : XFile(existingEntry.photoPath!);
      for (final item in existingEntry.personalityScores.entries) {
        _personalityScores[item.key] = item.value;
      }
      for (final item in existingEntry.documents.entries) {
        _partnerDocuments[item.key] = item.value;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _businessTypeController.dispose();
    _phoneController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
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
                  ? 'Perbarui data ${widget.type.shortLabel.toLowerCase()} milik ${widget.session.userName}.'
                  : 'Isi form untuk menambahkan ${widget.type.shortLabel.toLowerCase()} baru.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            StatusBadge(label: widget.type.shortLabel, color: Colors.teal),
            const SizedBox(height: 20),
            _PhotoPickerLine(
              photo: _photo,
              onCamera: () => _pickPhoto(ImageSource.camera),
              onGallery: () => _pickPhoto(ImageSource.gallery),
              onRemove: () => setState(() => _photo = null),
            ),
            const Divider(height: 24),
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
                    onPressed: _submit,
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

  Future<void> _pickPhoto(ImageSource source) async {
    final photo = await _imagePicker.pickImage(
      source: source,
      imageQuality: 72,
      maxWidth: 1600,
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

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto wajib dipilih dari kamera atau gallery'),
        ),
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
        documentComplete == _partnerDocuments.length ? 'Lengkap' : 'Follow-up',
    };

    Navigator.pop(
      context,
      NetworkEntry(
        id: existingEntry?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        ownerKey: widget.session.ownerKey,
        ownerName: widget.session.userName,
        ownerRole: widget.session.role,
        type: widget.type,
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        businessType: _businessTypeController.text.trim(),
        phone: _phoneController.text.trim(),
        reference: _referenceController.text.trim(),
        notes: _notesController.text.trim(),
        photoPath: _photo?.path,
        status: status,
        statusColor: _statusColorFor(status),
        personalityScore:
            widget.type == NetworkEntryType.mitraHub ? personalityScore : null,
        personalityScores: widget.type == NetworkEntryType.mitraHub
            ? Map<String, double>.from(_personalityScores)
            : const {},
        documents: widget.type == NetworkEntryType.mitraHub
            ? Map<String, PartnerDocumentState>.from(_partnerDocuments)
            : const {},
        followUps: existingEntry?.followUps ?? const [],
        createdAt: existingEntry?.createdAt ?? DateTime.now(),
      ),
    );
  }

  double get _personalityAverage {
    final total =
        _personalityScores.values.fold<double>(0, (sum, value) => sum + value);
    return total / _personalityScores.length;
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

class _NetworkSection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E5E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
            EmptyState(
              icon: Icons.folder_open_rounded,
              title: '$title masih kosong',
              message: emptyMessage,
            )
          else
            for (var i = 0; i < entries.length; i++) ...[
              _NetworkItem(
                entry: entries[i],
                onTap: () => onTap(entries[i]),
              ),
              if (i != entries.length - 1) const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
  });

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
  const _FollowUpTile({
    required this.followUp,
  });

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
  const _CompactScoreList({
    required this.scores,
  });

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
                child: Text(
                  entry.key,
                  style: theme.textTheme.bodyMedium,
                ),
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
  const _CompactDocumentList({
    required this.documents,
  });

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
                child: Text(
                  entry.key,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              StatusBadge(label: label, color: color),
            ],
          ),
        );
      }).toList(),
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
    required this.onGallery,
    required this.onRemove,
  });

  final XFile? photo;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
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
                          Text('Foto dipilih',
                              style: theme.textTheme.bodyMedium),
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
                    TextButton(
                      onPressed: onRemove,
                      child: const Text('Hapus'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: onCamera,
                    child: const Text('Kamera'),
                  ),
                  OutlinedButton(
                    onPressed: onGallery,
                    child: const Text('Gallery'),
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
  const _PersonalityScoring({
    required this.scores,
    required this.onChanged,
  });

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
              onSelected: (selected) => onChanged(
                state.copyWith(exists: !selected, isValid: false),
              ),
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
  const _NetworkItem({
    required this.entry,
    required this.onTap,
  });

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
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
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
                        child: Text(entry.name, style: theme.textTheme.titleMedium),
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
                      StatusBadge(label: entry.status, color: entry.statusColor),
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
