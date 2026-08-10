import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app_controller.dart';
import '../../../core/enums/app_role.dart';
import '../../../core/models/app_session.dart';
import '../../../core/models/approval_step.dart';
import '../../../core/models/wfa_request_record.dart' as wfa_model;
import '../../../core/widgets/adaptive_image.dart';
import '../../../core/widgets/approval_step_list.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';

class WfhPage extends StatefulWidget {
  const WfhPage({
    super.key,
    required this.session,
    required this.controller,
  });

  final AppSession session;
  final AppController controller;

  @override
  State<WfhPage> createState() => _WfhPageState();
}

class _WfhPageState extends State<WfhPage> {
  static const String _defaultOfficeStart = '08:30';
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _initialTaskController = TextEditingController();
  final _updateController = TextEditingController();
  final _locationController = TextEditingController();
  final _workDateController = TextEditingController();
  final _startPlanController = TextEditingController(text: '08:30');
  final _endPlanController = TextEditingController(text: '17:00');
  final ImagePicker _imagePicker = ImagePicker();

  WfaRequestType _selectedRequestType = WfaRequestType.regular;
  WfaCompensationPlan _selectedCompensation = WfaCompensationPlan.normalShift;
  String? _selectedSpv;
  String? _selectedManagement;
  XFile? _pendingAttachment;
  String? _pendingAttachmentLabel;
  bool _isSubmitting = false;
  bool _isUpdatingTask = false;
  bool _isChangingSessionState = false;
  DateTime? _selectedWorkDate;

  List<WfaRequest> get _requests => widget.controller
      .wfaRequestsForSession(widget.session)
      .map(_mapRequest)
      .toList();

  bool get _showSpvField => widget.session.role == AppRole.staff;
  bool get _showManagementField =>
      widget.session.role == AppRole.staff ||
      widget.session.role == AppRole.spv ||
      widget.session.role == AppRole.areaManager;

  WfaRequest? get _activeRequest {
    for (final request in _requests) {
      if (request.status == WfaRequestStatus.active) {
        return request;
      }
    }
    return null;
  }

  WfaRequest? get _nextApprovedRequest {
    for (final request in _requests) {
      if (request.status == WfaRequestStatus.approved) {
        return request;
      }
    }
    return null;
  }

  int get _pendingCount {
    return _requests
        .where((request) => request.status == WfaRequestStatus.pending)
        .length;
  }

  @override
  void initState() {
    super.initState();
    _selectedSpv = widget.session.defaultSpv;
    _selectedManagement = widget.session.defaultManagement;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _initialTaskController.dispose();
    _updateController.dispose();
    _locationController.dispose();
    _workDateController.dispose();
    _startPlanController.dispose();
    _endPlanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final requests = _requests;
        final headerBadge = _activeRequest != null
            ? const StatusBadge(label: 'Sesi aktif', color: Colors.green)
            : _pendingCount > 0
                ? const StatusBadge(
                    label: 'Menunggu approval',
                    color: Colors.orange,
                  )
                : const StatusBadge(label: 'Siap diajukan', color: Colors.blue);

        return Form(
          key: _formKey,
          child: RefreshIndicator(
            onRefresh: () =>
                widget.controller.refreshWorkflowDataForSession(widget.session),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE7E5E4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('WFA Activity',
                                style: theme.textTheme.titleMedium),
                          ),
                          headerBadge,
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'WFA dipakai untuk kerja resmi di luar kantor, termasuk lembur atau overtime yang terjadi di luar jam kerja dan perlu approval serta dasar kompensasi.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _WfaSectionCard(
                  title: 'Pengajuan WFA',
                  subtitle: _approvalHint,
                  child: Column(
                    children: [
                      _SelectionLine<WfaRequestType>(
                        label: 'Jenis',
                        value: _selectedRequestType,
                        options: WfaRequestType.values,
                        hint: 'Pilih jenis WFA',
                        itemLabel: (option) => option.label,
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedRequestType = value;
                            _selectedCompensation =
                                value == WfaRequestType.overtime
                                    ? WfaCompensationPlan.shiftMundur
                                    : WfaCompensationPlan.normalShift;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _RequestTypeBanner(type: _selectedRequestType),
                      const Divider(height: 24),
                      _TextInput(
                        fieldKey: const ValueKey('wfa-work-date-input'),
                        controller: _workDateController,
                        label: 'Tanggal',
                        hint: 'Pilih tanggal kerja',
                        required: true,
                        readOnly: true,
                        suffixIcon: Icons.calendar_month_rounded,
                        onTap: _pickWorkDate,
                      ),
                      const Divider(height: 24),
                      _TextInput(
                        controller: _locationController,
                        label: 'Lokasi',
                        hint: 'Contoh: Rumah / lokasi meeting',
                        required: true,
                      ),
                      const Divider(height: 24),
                      _TextInput(
                        controller: _startPlanController,
                        label: 'Mulai',
                        hint: 'Contoh: 08:30',
                        required: true,
                      ),
                      const Divider(height: 24),
                      _TextInput(
                        controller: _endPlanController,
                        label: 'Selesai',
                        hint: 'Contoh: 17:00',
                        required: true,
                      ),
                      const Divider(height: 24),
                      _SelectionLine<WfaCompensationPlan>(
                        label: 'Kompensasi',
                        value: _selectedCompensation,
                        options: _availableCompensationPlans,
                        hint: 'Pilih rencana kompensasi',
                        itemLabel: (option) => option.label,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedCompensation = value);
                          }
                        },
                      ),
                      const SizedBox(height: 6),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 112),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth - 112),
                              child: Text(
                                _selectedCompensation.helperText,
                                softWrap: true,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 24),
                      _TextInput(
                        controller: _reasonController,
                        label: 'Alasan',
                        hint: _selectedRequestType == WfaRequestType.overtime
                            ? 'Contoh: meeting malam dengan mitra'
                            : 'Alasan bekerja dari luar kantor',
                        required: true,
                        maxLines: 2,
                      ),
                      const Divider(height: 24),
                      _TextInput(
                        controller: _initialTaskController,
                        label: 'Task Awal',
                        hint: 'Output utama atau fokus kerja saat WFA',
                        required: true,
                        maxLines: 2,
                      ),
                      if (_showSpvField) ...[
                        const Divider(height: 24),
                        _SelectionLine<String>(
                          label: 'SPV',
                          value: _selectedSpv,
                          options: widget.session.spvOptions,
                          hint: 'Pilih SPV',
                          itemLabel: (option) => option,
                          onChanged: (value) =>
                              setState(() => _selectedSpv = value),
                        ),
                      ],
                      if (_showManagementField) ...[
                        const Divider(height: 24),
                        _SelectionLine<String>(
                          label: 'Management',
                          value: _selectedManagement,
                          options: widget.session.managementOptions,
                          hint: 'Pilih Management',
                          itemLabel: (option) => option,
                          onChanged: (value) =>
                              setState(() => _selectedManagement = value),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _resetForm,
                              child: const Text('Reset'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _isSubmitting ? null : _submitRequest,
                              child: Text(_isSubmitting
                                  ? 'Memproses...'
                                  : 'Ajukan WFA'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _WfaSectionCard(
                  title: 'Aktivitas WFA',
                  subtitle:
                      'Mulai sesi dari approval yang sudah disetujui, lalu simpan progres kerja dan bukti lapangan selama WFA berlangsung.',
                  child: Column(
                    children: [
                      if (_activeRequest != null)
                        _ActiveWfaCard(
                          request: _activeRequest!,
                          durationText: _formatDuration(
                            _activeRequest!.actualStartAt,
                            _activeRequest!.actualEndAt,
                          ),
                          compensationSummary:
                              _compensationSummary(_activeRequest!),
                        )
                      else if (_nextApprovedRequest != null)
                        _ApprovedWfaCard(
                          request: _nextApprovedRequest!,
                          compensationSummary:
                              _compensationSummary(_nextApprovedRequest!),
                          onStart: () =>
                              _startApprovedSession(_nextApprovedRequest!),
                          isBusy: _isChangingSessionState,
                        )
                      else
                        const EmptyState(
                          icon: Icons.laptop_mac_rounded,
                          title: 'Belum ada sesi aktif',
                          message:
                              'Ajukan WFA dulu. Setelah ada request yang disetujui, sesi kerja bisa dimulai dari approval tersebut.',
                        ),
                    ],
                  ),
                ),
                if (_activeRequest != null) ...[
                  const SizedBox(height: 24),
                  _WfaSectionCard(
                    title: 'Update Task & Bukti',
                    subtitle:
                        'Unggah progres kerja dengan teks singkat dan lampiran foto dari kamera atau galeri.',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _updateController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText:
                                'Tulis progres kerja, hasil meeting, atau follow-up terbaru',
                          ),
                        ),
                        if (_pendingAttachment != null) ...[
                          const SizedBox(height: 12),
                          _AttachmentPreview(
                            file: _pendingAttachment!,
                            label: _pendingAttachmentLabel ?? 'Lampiran',
                            onRemove: () {
                              setState(() {
                                _pendingAttachment = null;
                                _pendingAttachmentLabel = null;
                              });
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _pickUpdateImage(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library_rounded),
                                label: const Text('Galeri'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _pickUpdateImage(ImageSource.camera),
                                icon: const Icon(Icons.photo_camera_rounded),
                                label: const Text('Kamera'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isUpdatingTask ? null : _addUpdate,
                                child: Text(
                                  _isUpdatingTask
                                      ? 'Mengirim...'
                                      : 'Tambah Update',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: _isChangingSessionState
                                    ? null
                                    : _finishSession,
                                child: Text(
                                  _isChangingSessionState
                                      ? 'Memproses...'
                                      : 'Selesaikan WFA',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _WfaSectionCard(
                  title: 'Riwayat Pengajuan',
                  subtitle:
                      'Semua request WFA reguler dan overtime tersimpan di sini lengkap dengan status, kompensasi, dan detailnya.',
                  child: requests.isEmpty
                      ? const EmptyState(
                          icon: Icons.history_rounded,
                          title: 'Belum ada pengajuan',
                          message:
                              'Pengajuan WFA dan overtime akan muncul di sini.',
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < requests.length; i++) ...[
                              _WfaHistoryItem(
                                request: requests[i],
                                onTap: () => _showRequestDetail(requests[i]),
                              ),
                              if (i != requests.length - 1)
                                const Divider(height: 24),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<WfaCompensationPlan> get _availableCompensationPlans {
    if (_selectedRequestType == WfaRequestType.overtime) {
      return const [
        WfaCompensationPlan.shiftMundur,
        WfaCompensationPlan.klaimLembur,
        WfaCompensationPlan.reviewHr,
      ];
    }
    return const [
      WfaCompensationPlan.normalShift,
      WfaCompensationPlan.reviewHr,
    ];
  }

  String get _approvalHint {
    switch (widget.session.role) {
      case AppRole.staff:
        return 'Pengajuan WFA staff akan diteruskan ke SPV lalu Management. Update task, bukti foto, dan overtime tetap melekat ke request yang disetujui.';
      case AppRole.spv:
        return 'Pengajuan WFA SPV akan diteruskan ke Management. Overtime malam bisa diajukan agar kompensasinya terdokumentasi.';
      case AppRole.areaManager:
        return 'Pengajuan WFA Area Manager akan diteruskan langsung ke Management, termasuk jika ada meeting malam atau overtime di luar jam kerja.';
      default:
        return 'Pengajuan WFA management dicatat sebagai mock monitoring. Approval chain bisa disambungkan ke struktur final nanti.';
    }
  }

  Future<void> _pickUpdateImage(ImageSource source) async {
    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 75,
    );
    if (image == null || !mounted) {
      return;
    }

    setState(() {
      _pendingAttachment = image;
      _pendingAttachmentLabel = source == ImageSource.camera
          ? 'Foto dari kamera'
          : 'Foto dari galeri';
    });
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_showSpvField && (_selectedSpv == null || _selectedSpv!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SPV wajib dipilih')),
      );
      return;
    }
    if (_showManagementField &&
        (_selectedManagement == null || _selectedManagement!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Management wajib dipilih')),
      );
      return;
    }

    final now = DateTime.now();
    final request = wfa_model.WfaRequestRecord(
      id: 'wfa-${now.millisecondsSinceEpoch}',
      requesterId: widget.session.ownerKey,
      requesterName: widget.session.userName,
      requesterRole: widget.session.role,
      mode: _selectedRequestType.toRecordMode(),
      compensationMode: _selectedCompensation.toRecordMode(),
      workDate: _selectedWorkDate ??
          _parseDisplayDate(_workDateController.text.trim()),
      startTime: _startPlanController.text.trim(),
      endTime: _endPlanController.text.trim(),
      locationLabel: _locationController.text.trim(),
      reason: _reasonController.text.trim(),
      initialTask: _initialTaskController.text.trim(),
      status: _approvalStepsForRequest.isEmpty
          ? wfa_model.WorkflowStatus.approved
          : wfa_model.WorkflowStatus.pending,
      approvalSteps: _approvalStepsForRequest,
      taskUpdates: const [],
      submittedAt: now,
      note: _selectedRequestType == WfaRequestType.overtime
          ? 'Pengajuan overtime tercatat dan menunggu approval. Rencana kompensasi: ${_selectedCompensation.label.toLowerCase()}.'
          : 'Pengajuan WFA tercatat dan menunggu approval sesuai struktur user.',
    );

    setState(() => _isSubmitting = true);
    try {
      await widget.controller.submitWfaRequest(widget.session, request);
      if (!mounted) {
        return;
      }

      setState(() => _resetForm(clearInsideSetState: false));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_submissionSuccessMessage)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pengajuan WFA gagal: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String get _submissionSuccessMessage {
    switch (widget.session.role) {
      case AppRole.staff:
        return 'Pengajuan WFA masuk dan menunggu approval SPV lalu Management';
      case AppRole.spv:
      case AppRole.areaManager:
        return 'Pengajuan WFA masuk dan menunggu approval Management';
      default:
        return 'Pengajuan WFA langsung tercatat untuk monitoring';
    }
  }

  Future<void> _startApprovedSession(WfaRequest request) async {
    final source = widget.controller
        .wfaRequestsForSession(widget.session)
        .firstWhere((item) => item.id == request.id);
    setState(() => _isChangingSessionState = true);
    try {
      await widget.controller.startWfaSession(
        widget.session,
        request: source,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memulai sesi WFA: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isChangingSessionState = false);
      }
    }
  }

  Future<void> _addUpdate() async {
    final activeRequest = _activeRequest;
    if (activeRequest == null) {
      return;
    }

    final text = _updateController.text.trim();
    if (text.isEmpty && _pendingAttachment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Isi update task atau lampirkan foto dulu')),
      );
      return;
    }

    setState(() => _isUpdatingTask = true);
    try {
      await widget.controller.appendWfaTaskUpdate(
        widget.session,
        requestId: activeRequest.id,
        message: text.isEmpty ? 'Lampiran bukti aktivitas WFA' : text,
        attachmentPath: _pendingAttachment?.path,
        attachmentLabel: _pendingAttachmentLabel,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _updateController.clear();
        _pendingAttachment = null;
        _pendingAttachmentLabel = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update task gagal: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingTask = false);
      }
    }
  }

  Future<void> _finishSession() async {
    final activeRequest = _activeRequest;
    if (activeRequest == null) {
      return;
    }

    final source = widget.controller
        .wfaRequestsForSession(widget.session)
        .firstWhere((item) => item.id == activeRequest.id);
    setState(() => _isChangingSessionState = true);
    try {
      await widget.controller.finishWfaSession(
        widget.session,
        request: source,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _updateController.clear();
        _pendingAttachment = null;
        _pendingAttachmentLabel = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyelesaikan WFA: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isChangingSessionState = false);
      }
    }
  }

  List<ApprovalStep> get _approvalStepsForRequest {
    switch (widget.session.role) {
      case AppRole.staff:
        return [
          ApprovalStep(
            sequence: 1,
            approverRole: AppRole.spv,
            approverId: _ownerKeyFor(AppRole.spv, _selectedSpv!),
            approverName: _selectedSpv,
            status: ApprovalStepStatus.pending,
          ),
          ApprovalStep(
            sequence: 2,
            approverRole: AppRole.management,
            approverId: _ownerKeyFor(AppRole.management, _selectedManagement!),
            approverName: _selectedManagement,
            status: ApprovalStepStatus.pending,
          ),
        ];
      case AppRole.spv:
      case AppRole.areaManager:
        return [
          ApprovalStep(
            sequence: 1,
            approverRole: AppRole.management,
            approverId: _ownerKeyFor(AppRole.management, _selectedManagement!),
            approverName: _selectedManagement,
            status: ApprovalStepStatus.pending,
          ),
        ];
      default:
        return const [];
    }
  }

  String _ownerKeyFor(AppRole role, String userName) {
    return '${role.name}:${userName.trim().toLowerCase()}';
  }

  DateTime _parseDisplayDate(String value) {
    final parts = value.trim().split(' ');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]) ?? 1;
      final month = _monthFromShortName(parts[1]);
      final year = int.tryParse(parts[2]) ?? DateTime.now().year;
      return DateTime(year, month, day);
    }
    return DateTime.now();
  }

  Future<void> _pickWorkDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedWorkDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      locale: const Locale('id'),
    );
    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _selectedWorkDate = picked;
      _workDateController.text = _formatDate(picked);
    });
  }

  int _monthFromShortName(String value) {
    const months = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'Mei': 5,
      'Jun': 6,
      'Jul': 7,
      'Agu': 8,
      'Sep': 9,
      'Okt': 10,
      'Nov': 11,
      'Des': 12,
    };
    return months[value] ?? DateTime.now().month;
  }

  WfaRequest _mapRequest(wfa_model.WfaRequestRecord record) {
    return WfaRequest(
      id: record.id,
      submittedAtLabel: _formatDateTime(record.submittedAt),
      workDate: _formatDate(record.workDate),
      plannedWindow: '${record.startTime} - ${record.endTime}',
      workLocation: record.locationLabel,
      reason: record.reason,
      initialTask: record.initialTask,
      requestType: record.mode.toUiType(),
      compensationPlan: record.compensationMode.toUiPlan(),
      status: record.status.toUiStatus(),
      approvalNote: record.note ?? '-',
      updates: record.taskUpdates.map(_mapTaskUpdate).toList(),
      spvName: _approverNameForRole(record.approvalSteps, AppRole.spv),
      managementName: _approverNameForRole(
        record.approvalSteps,
        AppRole.management,
      ),
      approvalSteps: record.approvalSteps,
      actualStartAt: record.actualStartAt,
      actualEndAt: record.actualEndAt,
    );
  }

  WfaTaskUpdate _mapTaskUpdate(wfa_model.WfaTaskUpdateRecord update) {
    return WfaTaskUpdate(
      time: _formatTime(update.createdAt),
      text: update.message,
      attachmentPath:
          update.attachments.isEmpty ? null : update.attachments.first.url,
      attachmentLabel:
          update.attachments.isEmpty ? null : update.attachments.first.fileName,
    );
  }

  String? _approverNameForRole(List<ApprovalStep> steps, AppRole role) {
    for (final step in steps) {
      if (step.approverRole == role) {
        return step.approverName;
      }
    }
    return null;
  }

  void _resetForm({bool clearInsideSetState = true}) {
    void reset() {
      _formKey.currentState?.reset();
      _workDateController.clear();
      _locationController.clear();
      _startPlanController.text = '08:30';
      _endPlanController.text = '17:00';
      _reasonController.clear();
      _initialTaskController.clear();
      _selectedRequestType = WfaRequestType.regular;
      _selectedCompensation = WfaCompensationPlan.normalShift;
      _selectedSpv = widget.session.defaultSpv;
      _selectedManagement = widget.session.defaultManagement;
      _selectedWorkDate = null;
    }

    if (clearInsideSetState) {
      setState(reset);
    } else {
      reset();
    }
  }

  void _showRequestDetail(WfaRequest request) {
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          request.requestType.label,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      StatusBadge(
                        label: request.status.label,
                        color: request.status.color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _DetailLine(label: 'Tanggal', value: request.workDate),
                  const Divider(height: 24),
                  _DetailLine(label: 'Jadwal', value: request.plannedWindow),
                  const Divider(height: 24),
                  _DetailLine(label: 'Lokasi', value: request.workLocation),
                  const Divider(height: 24),
                  _DetailLine(
                    label: 'Kompensasi',
                    value: request.compensationPlan.label,
                  ),
                  if (_compensationSummary(request) != null) ...[
                    const Divider(height: 24),
                    _DetailLine(
                      label: 'Rekomendasi',
                      value: _compensationSummary(request)!,
                    ),
                  ],
                  const Divider(height: 24),
                  _DetailLine(label: 'Alasan', value: request.reason),
                  const Divider(height: 24),
                  _DetailLine(label: 'Task Awal', value: request.initialTask),
                  if (request.spvName != null) ...[
                    const Divider(height: 24),
                    _DetailLine(label: 'SPV', value: request.spvName!),
                  ],
                  if (request.managementName != null) ...[
                    const Divider(height: 24),
                    _DetailLine(
                      label: 'Management',
                      value: request.managementName!,
                    ),
                  ],
                  const Divider(height: 24),
                  Text('Alur Approval', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  ApprovalStepList(steps: request.approvalSteps),
                  const Divider(height: 24),
                  _DetailLine(label: 'Catatan', value: request.approvalNote),
                  if (request.actualStartAt != null) ...[
                    const Divider(height: 24),
                    _DetailLine(
                      label: 'Mulai Aktual',
                      value: _formatDateTime(request.actualStartAt!),
                    ),
                  ],
                  if (request.actualEndAt != null) ...[
                    const Divider(height: 24),
                    _DetailLine(
                      label: 'Selesai Aktual',
                      value: _formatDateTime(request.actualEndAt!),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text('Update Task', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (request.updates.isEmpty)
                    const Text('Belum ada update task yang tercatat.')
                  else
                    for (final update in request.updates) ...[
                      _TaskItem(update: update),
                      if (update != request.updates.last)
                        const Divider(height: 24),
                    ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year ${_formatTime(value)}';
  }

  String _formatDate(DateTime value) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${value.day.toString().padLeft(2, '0')} ${monthNames[value.month - 1]} ${value.year}';
  }

  String _formatDuration(DateTime? start, DateTime? end) {
    if (start == null) {
      return '-';
    }

    final effectiveEnd = end ?? DateTime.now();
    final duration = effectiveEnd.difference(start);
    return '${duration.inHours}j ${duration.inMinutes.remainder(60)}m';
  }

  String? _compensationSummary(WfaRequest request) {
    switch (request.compensationPlan) {
      case WfaCompensationPlan.shiftMundur:
        final nextStart = _recommendedNextStart(request);
        if (nextStart == null) {
          return null;
        }
        final overtimeDuration = _overtimeDurationLabel(request);
        return 'Jam masuk esok hari disarankan $nextStart setelah overtime $overtimeDuration.';
      case WfaCompensationPlan.klaimLembur:
        final overtimeDuration = _overtimeDurationLabel(request);
        return overtimeDuration == null
            ? 'Klaim lembur menunggu durasi final.'
            : 'Klaim lembur yang disarankan: $overtimeDuration.';
      case WfaCompensationPlan.reviewHr:
        final overtimeDuration = _overtimeDurationLabel(request);
        return overtimeDuration == null
            ? 'Menunggu keputusan HR atau management.'
            : 'Durasi $overtimeDuration tercatat untuk direview HR atau management.';
      case WfaCompensationPlan.normalShift:
        return 'Tidak ada kompensasi tambahan. Tetap mengikuti jam kerja normal.';
    }
  }

  String? _recommendedNextStart(WfaRequest request) {
    if (request.requestType != WfaRequestType.overtime) {
      return null;
    }

    final overtimeMinutes = _overtimeMinutes(request);
    if (overtimeMinutes == null || overtimeMinutes <= 0) {
      return null;
    }

    final baseStart = _parseClock(_defaultOfficeStart);
    if (baseStart == null) {
      return null;
    }

    final totalMinutes =
        (baseStart.hour * 60) + baseStart.minute + overtimeMinutes;
    final hour = (totalMinutes ~/ 60) % 24;
    final minute = totalMinutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String? _overtimeDurationLabel(WfaRequest request) {
    final overtimeMinutes = _overtimeMinutes(request);
    if (overtimeMinutes == null || overtimeMinutes <= 0) {
      return null;
    }

    final hours = overtimeMinutes ~/ 60;
    final minutes = overtimeMinutes % 60;
    return '${hours}j ${minutes}m';
  }

  int? _overtimeMinutes(WfaRequest request) {
    if (request.requestType != WfaRequestType.overtime) {
      return null;
    }

    if (request.actualStartAt != null && request.actualEndAt != null) {
      return request.actualEndAt!
          .difference(request.actualStartAt!)
          .inMinutes
          .clamp(0, 24 * 60);
    }

    final parts = request.plannedWindow.split(' - ');
    if (parts.length != 2) {
      return null;
    }

    final start = _parseClock(parts.first);
    final end = _parseClock(parts.last);
    if (start == null || end == null) {
      return null;
    }

    final startMinutes = (start.hour * 60) + start.minute;
    final endMinutes = (end.hour * 60) + end.minute;
    final diff = endMinutes - startMinutes;
    if (diff <= 0) {
      return null;
    }
    return diff;
  }

  TimeOfDay? _parseClock(String value) {
    final parts = value.trim().split(':');
    if (parts.length != 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }
}

class _SelectionLine<T> extends StatelessWidget {
  const _SelectionLine({
    required this.label,
    required this.value,
    required this.options,
    required this.hint,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<T> options;
  final String hint;
  final String Function(T option) itemLabel;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
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
          child: DropdownButtonFormField<T>(
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(hintText: hint),
            items: options
                .map(
                  (option) => DropdownMenuItem<T>(
                    value: option,
                    child: Text(itemLabel(option)),
                  ),
                )
                .toList(),
            onChanged: onChanged,
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

class _WfaSectionCard extends StatelessWidget {
  const _WfaSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _RequestTypeBanner extends StatelessWidget {
  const _RequestTypeBanner({
    required this.type,
  });

  final WfaRequestType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOvertime = type == WfaRequestType.overtime;
    final color =
        isOvertime ? const Color(0xFFB45309) : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isOvertime ? Icons.nightlight_round : Icons.laptop_mac_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOvertime ? 'WFA Overtime' : 'WFA Reguler',
                  style: theme.textTheme.titleMedium?.copyWith(color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  isOvertime
                      ? 'Dipakai untuk kerja tambahan di luar jam kerja. Approval dan kompensasi akan jadi fokus utama.'
                      : 'Dipakai untuk jam kerja resmi di luar kantor. Fokusnya tetap pada approval, task awal, dan output kerja.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    this.fieldKey,
    required this.controller,
    required this.label,
    required this.hint,
    this.required = false,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool required;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final IconData? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
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
          child: InkWell(
            key: fieldKey,
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: IgnorePointer(
              ignoring: readOnly,
              child: TextFormField(
                controller: controller,
                maxLines: maxLines,
                readOnly: readOnly,
                onTap: onTap,
                decoration: InputDecoration(
                  hintText: hint,
                  suffixIcon: suffixIcon == null ? null : Icon(suffixIcon),
                ),
                validator: (value) {
                  if (required && (value == null || value.trim().isEmpty)) {
                    return '$label wajib diisi';
                  }
                  return null;
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ApprovedWfaCard extends StatelessWidget {
  const _ApprovedWfaCard({
    required this.request,
    required this.compensationSummary,
    required this.onStart,
    this.isBusy = false,
  });

  final WfaRequest request;
  final String? compensationSummary;
  final VoidCallback onStart;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.requestType.label,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              StatusBadge(
                  label: request.status.label, color: request.status.color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${request.workDate} - ${request.plannedWindow}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            request.reason,
            style: theme.textTheme.bodyMedium,
          ),
          if (compensationSummary != null) ...[
            const SizedBox(height: 10),
            Text(
              compensationSummary!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: isBusy ? null : onStart,
            child: Text(
              isBusy ? 'Memproses...' : 'Mulai Sesi dari Approval',
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveWfaCard extends StatelessWidget {
  const _ActiveWfaCard({
    required this.request,
    required this.durationText,
    required this.compensationSummary,
  });

  final WfaRequest request;
  final String durationText;
  final String? compensationSummary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.requestType.label,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              StatusBadge(
                  label: request.status.label, color: request.status.color),
            ],
          ),
          const SizedBox(height: 10),
          _CardLine(label: 'Jadwal', value: request.plannedWindow),
          const SizedBox(height: 8),
          _CardLine(label: 'Lokasi', value: request.workLocation),
          const SizedBox(height: 8),
          _CardLine(label: 'Durasi', value: durationText),
          const SizedBox(height: 8),
          _CardLine(label: 'Kompensasi', value: request.compensationPlan.label),
          if (compensationSummary != null) ...[
            const SizedBox(height: 10),
            Text(
              compensationSummary!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.file,
    required this.label,
    required this.onRemove,
  });

  final XFile file;
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(file.path),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: onRemove,
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

class _WfaHistoryItem extends StatelessWidget {
  const _WfaHistoryItem({
    required this.request,
    required this.onTap,
  });

  final WfaRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              request.requestType == WfaRequestType.overtime
                  ? Icons.nightlight_round
                  : Icons.laptop_mac_rounded,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.requestType.label,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${request.workDate} - ${request.plannedWindow}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    request.reason,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${request.compensationPlan.label} - ${request.updates.length} update',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            StatusBadge(
                label: request.status.label, color: request.status.color),
          ],
        ),
      ),
    );
  }
}

class _TaskItem extends StatelessWidget {
  const _TaskItem({required this.update});

  final WfaTaskUpdate update;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Text(
            update.time,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(update.text),
              if (update.attachmentPath != null) ...[
                const SizedBox(height: 8),
                AdaptiveImage(
                  path: update.attachmentPath!,
                  width: 96,
                  height: 96,
                  borderRadius: BorderRadius.circular(12),
                ),
                if (update.attachmentLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    update.attachmentLabel!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CardLine extends StatelessWidget {
  const _CardLine({
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
          width: 92,
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
          width: 110,
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

class WfaRequest {
  const WfaRequest({
    required this.id,
    required this.submittedAtLabel,
    required this.workDate,
    required this.plannedWindow,
    required this.workLocation,
    required this.reason,
    required this.initialTask,
    required this.requestType,
    required this.compensationPlan,
    required this.status,
    required this.approvalNote,
    required this.updates,
    required this.approvalSteps,
    this.spvName,
    this.managementName,
    this.actualStartAt,
    this.actualEndAt,
  });

  final String id;
  final String submittedAtLabel;
  final String workDate;
  final String plannedWindow;
  final String workLocation;
  final String reason;
  final String initialTask;
  final WfaRequestType requestType;
  final WfaCompensationPlan compensationPlan;
  final WfaRequestStatus status;
  final String approvalNote;
  final List<WfaTaskUpdate> updates;
  final List<ApprovalStep> approvalSteps;
  final String? spvName;
  final String? managementName;
  final DateTime? actualStartAt;
  final DateTime? actualEndAt;

  WfaRequest copyWith({
    WfaRequestStatus? status,
    String? approvalNote,
    List<WfaTaskUpdate>? updates,
    List<ApprovalStep>? approvalSteps,
    DateTime? actualStartAt,
    DateTime? actualEndAt,
  }) {
    return WfaRequest(
      id: id,
      submittedAtLabel: submittedAtLabel,
      workDate: workDate,
      plannedWindow: plannedWindow,
      workLocation: workLocation,
      reason: reason,
      initialTask: initialTask,
      requestType: requestType,
      compensationPlan: compensationPlan,
      status: status ?? this.status,
      approvalNote: approvalNote ?? this.approvalNote,
      updates: updates ?? this.updates,
      approvalSteps: approvalSteps ?? this.approvalSteps,
      spvName: spvName,
      managementName: managementName,
      actualStartAt: actualStartAt ?? this.actualStartAt,
      actualEndAt: actualEndAt ?? this.actualEndAt,
    );
  }
}

class WfaTaskUpdate {
  const WfaTaskUpdate({
    required this.time,
    required this.text,
    this.attachmentPath,
    this.attachmentLabel,
  });

  final String time;
  final String text;
  final String? attachmentPath;
  final String? attachmentLabel;
}

enum WfaRequestType {
  regular,
  overtime;
}

extension WfaRequestTypeX on WfaRequestType {
  String get label {
    switch (this) {
      case WfaRequestType.regular:
        return 'WFA Reguler';
      case WfaRequestType.overtime:
        return 'WFA Overtime';
    }
  }

  String get shortLabel {
    switch (this) {
      case WfaRequestType.regular:
        return 'Reguler';
      case WfaRequestType.overtime:
        return 'Overtime';
    }
  }
}

enum WfaCompensationPlan {
  normalShift,
  shiftMundur,
  klaimLembur,
  reviewHr;
}

extension WfaCompensationPlanX on WfaCompensationPlan {
  String get label {
    switch (this) {
      case WfaCompensationPlan.normalShift:
        return 'Normal shift';
      case WfaCompensationPlan.shiftMundur:
        return 'Jam masuk mundur';
      case WfaCompensationPlan.klaimLembur:
        return 'Klaim lembur';
      case WfaCompensationPlan.reviewHr:
        return 'Review HR/Management';
    }
  }

  String get helperText {
    switch (this) {
      case WfaCompensationPlan.normalShift:
        return 'Dipakai untuk WFA reguler yang tidak menghasilkan kompensasi tambahan.';
      case WfaCompensationPlan.shiftMundur:
        return 'Cocok untuk overtime malam yang kemungkinan dibayar dengan pergeseran jam masuk esok hari.';
      case WfaCompensationPlan.klaimLembur:
        return 'Cocok untuk pekerjaan tambahan di luar jam kerja yang ingin dicatat sebagai lembur.';
      case WfaCompensationPlan.reviewHr:
        return 'Dipakai jika bentuk kompensasi akhir masih akan diputuskan oleh HR atau management.';
    }
  }
}

enum WfaRequestStatus {
  pending,
  approved,
  active,
  completed,
  rejected;
}

extension WfaRequestStatusX on WfaRequestStatus {
  String get label {
    switch (this) {
      case WfaRequestStatus.pending:
        return 'Pending';
      case WfaRequestStatus.approved:
        return 'Disetujui';
      case WfaRequestStatus.active:
        return 'Aktif';
      case WfaRequestStatus.completed:
        return 'Selesai';
      case WfaRequestStatus.rejected:
        return 'Ditolak';
    }
  }

  Color get color {
    switch (this) {
      case WfaRequestStatus.pending:
        return Colors.orange;
      case WfaRequestStatus.approved:
        return Colors.blue;
      case WfaRequestStatus.active:
        return Colors.green;
      case WfaRequestStatus.completed:
        return Colors.teal;
      case WfaRequestStatus.rejected:
        return Colors.red;
    }
  }
}

extension on WfaRequestType {
  wfa_model.WfaRequestMode toRecordMode() {
    switch (this) {
      case WfaRequestType.regular:
        return wfa_model.WfaRequestMode.regular;
      case WfaRequestType.overtime:
        return wfa_model.WfaRequestMode.overtime;
    }
  }
}

extension on WfaCompensationPlan {
  wfa_model.WfaCompensationMode toRecordMode() {
    switch (this) {
      case WfaCompensationPlan.normalShift:
        return wfa_model.WfaCompensationMode.normalShift;
      case WfaCompensationPlan.shiftMundur:
        return wfa_model.WfaCompensationMode.shiftMundur;
      case WfaCompensationPlan.klaimLembur:
        return wfa_model.WfaCompensationMode.klaimLembur;
      case WfaCompensationPlan.reviewHr:
        return wfa_model.WfaCompensationMode.reviewHr;
    }
  }
}

extension on wfa_model.WfaRequestMode {
  WfaRequestType toUiType() {
    switch (this) {
      case wfa_model.WfaRequestMode.regular:
        return WfaRequestType.regular;
      case wfa_model.WfaRequestMode.overtime:
        return WfaRequestType.overtime;
    }
  }
}

extension on wfa_model.WfaCompensationMode {
  WfaCompensationPlan toUiPlan() {
    switch (this) {
      case wfa_model.WfaCompensationMode.normalShift:
        return WfaCompensationPlan.normalShift;
      case wfa_model.WfaCompensationMode.shiftMundur:
        return WfaCompensationPlan.shiftMundur;
      case wfa_model.WfaCompensationMode.klaimLembur:
        return WfaCompensationPlan.klaimLembur;
      case wfa_model.WfaCompensationMode.reviewHr:
        return WfaCompensationPlan.reviewHr;
    }
  }
}

extension on wfa_model.WorkflowStatus {
  WfaRequestStatus toUiStatus() {
    switch (this) {
      case wfa_model.WorkflowStatus.pending:
        return WfaRequestStatus.pending;
      case wfa_model.WorkflowStatus.approved:
        return WfaRequestStatus.approved;
      case wfa_model.WorkflowStatus.active:
        return WfaRequestStatus.active;
      case wfa_model.WorkflowStatus.completed:
        return WfaRequestStatus.completed;
      case wfa_model.WorkflowStatus.rejected:
        return WfaRequestStatus.rejected;
      case wfa_model.WorkflowStatus.draft:
      case wfa_model.WorkflowStatus.cancelled:
        return WfaRequestStatus.pending;
    }
  }
}
