import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app_controller.dart';
import '../../../core/enums/app_role.dart';
import '../../../core/models/app_session.dart';
import '../../../core/models/approval_step.dart';
import '../../../core/models/leave_request_record.dart' as leave_model;
import '../../../core/models/remote_attachment.dart';
import '../../../core/widgets/approval_step_list.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';

class LeavePage extends StatefulWidget {
  const LeavePage({
    super.key,
    required this.session,
    required this.controller,
  });

  final AppSession session;
  final AppController controller;

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> {
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _daysController = TextEditingController();
  final _reasonController = TextEditingController();
  final _delegationController = TextEditingController();

  LeaveRequestType _selectedRequestType = LeaveRequestType.cuti;
  LeaveCompensationType _selectedCompensation =
      LeaveCompensationType.potongSaldoCuti;
  String? _selectedSpv;
  String? _selectedManagement;
  bool _isSubmitting = false;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  String? _evidencePhotoPath;

  List<LeaveRequest> get _requests => widget.controller
      .leaveRequestsForSession(widget.session)
      .map(_mapRequest)
      .toList();

  bool get _showSpvField => widget.session.role == AppRole.staff;
  bool get _showManagementField =>
      widget.session.role == AppRole.staff ||
      widget.session.role == AppRole.spv ||
      widget.session.role == AppRole.areaManager;

  @override
  void initState() {
    super.initState();
    _selectedSpv = widget.session.defaultSpv;
    _selectedManagement = widget.session.defaultManagement;
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _daysController.dispose();
    _reasonController.dispose();
    _delegationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final requests = _requests;
        final pendingCount = _requests
            .where((request) => request.status == LeaveStatus.pending)
            .length;
        final leaveBalance = widget.controller.leaveBalanceDaysForSession(
          widget.session,
        );

        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
          Text('Pengajuan Cuti / Izin', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          _SummaryLine(
            label: 'Saldo cuti',
            value: _formatBalanceDays(leaveBalance),
            note: 'Tersedia',
          ),
          const Divider(height: 24),
          _SummaryLine(
            label: 'Pending',
            value: pendingCount.toString(),
            note: 'Menunggu approval',
          ),
          const SizedBox(height: 20),
          Text('Form Pengajuan', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            _approvalHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _SelectionLine<LeaveRequestType>(
            label: 'Jenis',
            value: _selectedRequestType,
            options: LeaveRequestType.values,
            hint: 'Pilih jenis pengajuan',
            itemLabel: (option) => option.label,
            onChanged: (value) => setState(() {
              _selectedRequestType = value ?? _selectedRequestType;
              if (_selectedRequestType == LeaveRequestType.izinPerJam) {
                _daysController.clear();
              } else {
                _recalculateDuration();
              }
            }),
          ),
          const Divider(height: 24),
          _SelectionLine<LeaveCompensationType>(
            label: 'Kompensasi',
            value: _selectedCompensation,
            options: LeaveCompensationType.values,
            hint: 'Pilih kompensasi',
            itemLabel: (option) => option.label,
            onChanged: (value) => setState(
              () => _selectedCompensation = value ?? _selectedCompensation,
            ),
          ),
          const Divider(height: 24),
          _TextInput(
            fieldKey: const ValueKey('leave-start-date-input'),
            controller: _startDateController,
            label: 'Tanggal Mulai',
            hint: 'Pilih tanggal mulai',
            required: true,
            readOnly: true,
            suffixIcon: Icons.calendar_month_rounded,
            onTap: _pickStartDate,
          ),
          const Divider(height: 24),
          _TextInput(
            fieldKey: const ValueKey('leave-end-date-input'),
            controller: _endDateController,
            label: 'Tanggal Selesai',
            hint: 'Pilih tanggal selesai',
            required: true,
            readOnly: true,
            suffixIcon: Icons.calendar_month_rounded,
            onTap: _pickEndDate,
          ),
          const Divider(height: 24),
          _TextInput(
            controller: _daysController,
            label: _selectedRequestType == LeaveRequestType.izinPerJam
                ? 'Durasi (jam)'
                : 'Jumlah Hari',
            hint: _selectedRequestType == LeaveRequestType.izinPerJam
                ? 'Contoh: 3'
                : 'Terhitung otomatis dari rentang tanggal',
            required: true,
            keyboardType: TextInputType.number,
            readOnly: _selectedRequestType != LeaveRequestType.izinPerJam,
          ),
          const Divider(height: 24),
          _TextInput(
            controller: _reasonController,
            label: 'Alasan',
            hint: 'Alasan pengajuan',
            required: true,
            maxLines: 2,
          ),
          const Divider(height: 24),
          _TextInput(
            controller: _delegationController,
            label: 'Delegasi',
            hint: 'Nama pengganti tugas',
            required: true,
          ),
          const Divider(height: 24),
          _EvidenceInput(
            photoPath: _evidencePhotoPath,
            onCamera: () => _pickEvidence(ImageSource.camera),
            onGallery: () => _pickEvidence(ImageSource.gallery),
            onRemove: _evidencePhotoPath == null
                ? null
                : () => setState(() => _evidencePhotoPath = null),
          ),
          if (_showSpvField) ...[
            const Divider(height: 24),
            _SelectionLine<String>(
              label: 'SPV',
              value: _selectedSpv,
              options: widget.session.spvOptions,
              hint: 'Pilih SPV',
              itemLabel: (option) => option,
              onChanged: (value) => setState(() => _selectedSpv = value),
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
              onChanged: (value) => setState(() => _selectedManagement = value),
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
                  onPressed: _isSubmitting ? null : _submitLeave,
                  child: Text(_isSubmitting ? 'Memproses...' : 'Ajukan'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Riwayat Pengajuan', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          if (requests.isEmpty)
            const EmptyState(
              icon: Icons.event_busy_rounded,
              title: 'Belum ada riwayat',
              message:
                  'Pengajuan cuti atau izin yang dibuat user akan tampil di sini.',
            )
          else
            for (var i = 0; i < requests.length; i++) ...[
              _LeaveHistoryItem(
                request: requests[i],
                onTap: () => _showRequestDetail(requests[i]),
              ),
              if (i != requests.length - 1) const Divider(height: 24),
            ],
            ],
          ),
        );
      },
    );
  }

  String get _approvalHint {
    switch (widget.session.role) {
      case AppRole.staff:
        return 'Pengajuan staff akan diteruskan ke SPV lalu Management sesuai struktur approval user ini.';
      case AppRole.spv:
        return 'Pengajuan SPV akan diteruskan ke Management sesuai struktur approval user ini.';
      case AppRole.areaManager:
        return 'Pengajuan Area Manager akan diteruskan langsung ke Management, sama seperti SPV.';
      default:
        return 'Form mock untuk pengajuan cuti atau izin sebelum backend.';
    }
  }

  Future<void> _submitLeave() async {
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
    if (_evidencePhotoPath == null || _evidencePhotoPath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bukti dokumentasi wajib diunggah.')),
      );
      return;
    }

    final now = DateTime.now();
    final request = leave_model.LeaveRequestRecord(
      id: 'leave-${now.millisecondsSinceEpoch}',
      requesterId: widget.session.ownerKey,
      requesterName: widget.session.userName,
      requesterRole: widget.session.role,
      category: _selectedRequestType.toRecordCategory(),
      compensationOption: _selectedCompensation.toRecordOption(),
      startAt:
          _selectedStartDate ?? _parseDisplayDate(_startDateController.text.trim()),
      endAt: _selectedEndDate ?? _parseDisplayDate(_endDateController.text.trim()),
      durationValue: double.parse(_daysController.text.trim()),
      reason: _reasonController.text.trim(),
      delegateTo: _delegationController.text.trim(),
      status: _approvalStepsForRequest.isEmpty
          ? leave_model.WorkflowStatus.approved
          : leave_model.WorkflowStatus.pending,
      approvalSteps: _approvalStepsForRequest,
      submittedAt: now,
      attachments: const [],
      note:
          'Pengajuan ${_selectedRequestType.label.toLowerCase()} dibuat user dan menunggu approval berikutnya.',
    );

    setState(() => _isSubmitting = true);
    try {
      await widget.controller.submitLeaveRequest(
        widget.session,
        request,
        evidencePath: _evidencePhotoPath,
      );
      if (!mounted) {
        return;
      }

      setState(_resetForm);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_submissionSuccessMessage)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pengajuan gagal: $error')),
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
        return 'Pengajuan masuk dan menunggu approval SPV lalu Management';
      case AppRole.spv:
      case AppRole.areaManager:
        return 'Pengajuan masuk dan menunggu approval Management';
      default:
        return 'Pengajuan langsung tercatat untuk monitoring';
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _startDateController.clear();
    _endDateController.clear();
    _daysController.clear();
    _reasonController.clear();
    _delegationController.clear();
    _selectedRequestType = LeaveRequestType.cuti;
    _selectedCompensation = LeaveCompensationType.potongSaldoCuti;
    _selectedSpv = widget.session.defaultSpv;
    _selectedManagement = widget.session.defaultManagement;
    _selectedStartDate = null;
    _selectedEndDate = null;
    _evidencePhotoPath = null;
  }

  Future<void> _pickEvidence(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 58,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (!mounted || file == null) {
      return;
    }

    setState(() => _evidencePhotoPath = file.path);
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedStartDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      locale: const Locale('id'),
    );
    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _selectedStartDate = picked;
      if (_selectedEndDate != null && _selectedEndDate!.isBefore(picked)) {
        _selectedEndDate = picked;
      }
      _startDateController.text = _formatDate(picked);
      _endDateController.text = _selectedEndDate == null
          ? ''
          : _formatDate(_selectedEndDate!);
      _recalculateDuration();
    });
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final initialDate = _selectedEndDate ?? _selectedStartDate ?? now;
    final firstDate = _selectedStartDate ?? DateTime(now.year - 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 2),
      locale: const Locale('id'),
    );
    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _selectedEndDate = picked;
      _endDateController.text = _formatDate(picked);
      if (_selectedStartDate == null) {
        _selectedStartDate = picked;
        _startDateController.text = _formatDate(picked);
      }
      _recalculateDuration();
    });
  }

  void _recalculateDuration() {
    if (_selectedRequestType == LeaveRequestType.izinPerJam) {
      return;
    }
    if (_selectedStartDate == null || _selectedEndDate == null) {
      _daysController.clear();
      return;
    }

    final safeEnd = _selectedEndDate!.isBefore(_selectedStartDate!)
        ? _selectedStartDate!
        : _selectedEndDate!;
    final totalDays = safeEnd.difference(_selectedStartDate!).inDays + 1;
    _selectedEndDate = safeEnd;
    _endDateController.text = _formatDate(safeEnd);
    _daysController.text = totalDays.toString();
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

  LeaveRequest _mapRequest(leave_model.LeaveRequestRecord record) {
    return LeaveRequest(
      id: record.id,
      date: '${_formatDate(record.startAt)} - ${_formatDate(record.endAt)}',
      reason: record.reason,
      delegation: record.delegateTo,
      requestType: record.category.toUiType(),
      compensationType: record.compensationOption.toUiCompensation(),
      status: record.status.toUiStatus(),
      detailNote: record.note ?? '-',
      attachments: record.attachments,
      spvName: _approverNameForRole(record.approvalSteps, AppRole.spv),
      managementName: _approverNameForRole(
        record.approvalSteps,
        AppRole.management,
      ),
      approvalSteps: record.approvalSteps,
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

  String _formatBalanceDays(double value) {
    final rounded = value.roundToDouble();
    if (rounded == value) {
      return '${value.toInt()} hari';
    }
    return '${value.toStringAsFixed(1)} hari';
  }

  void _showRequestDetail(LeaveRequest request) {
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
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
                      const SizedBox(width: 12),
                      StatusBadge(
                        label: request.status.label,
                        color: request.status.color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _DetailLine(label: 'Tanggal', value: request.date),
                  const Divider(height: 24),
                  _DetailLine(
                    label: 'Kompensasi',
                    value: request.compensationType.label,
                  ),
                  const Divider(height: 24),
                  _DetailLine(label: 'Alasan', value: request.reason),
                  const Divider(height: 24),
                  _DetailLine(label: 'Delegasi', value: request.delegation),
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
                  _DetailLine(
                    label: 'Catatan',
                    value: request.detailNote,
                  ),
                  if (request.attachments.isNotEmpty) ...[
                    const Divider(height: 24),
                    _DetailLine(
                      label: 'Bukti',
                      value: request.attachments
                          .map((item) => item.fileName)
                          .join(', '),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
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

class _TextInput extends StatelessWidget {
  const _TextInput({
    this.fieldKey,
    required this.controller,
    required this.label,
    required this.hint,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
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
  final TextInputType? keyboardType;
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
                keyboardType: keyboardType,
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
                  if (!readOnly &&
                      keyboardType == TextInputType.number &&
                      value != null) {
                    final amount = int.tryParse(value.trim());
                    if (amount == null || amount <= 0) {
                      return '$label harus angka lebih dari 0';
                    }
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

class _EvidenceInput extends StatelessWidget {
  const _EvidenceInput({
    required this.photoPath,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });

  final String? photoPath;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = photoPath;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              'Bukti *',
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
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: onCamera,
                    icon: const Icon(Icons.photo_camera_rounded),
                    label: const Text('Kamera'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onGallery,
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Galeri'),
                  ),
                  if (onRemove != null)
                    TextButton.icon(
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Hapus'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (path == null)
                Text(
                  'Foto bukti wajib diisi agar HR bisa melihat dokumentasi pengajuan.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(path),
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(
          note,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LeaveHistoryItem extends StatelessWidget {
  const _LeaveHistoryItem({
    required this.request,
    required this.onTap,
  });

  final LeaveRequest request;
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
            const Icon(Icons.event_note_rounded, size: 18),
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
                    request.date,
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
                    request.compensationType.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            StatusBadge(label: request.status.label, color: request.status.color),
          ],
        ),
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

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.date,
    required this.reason,
    required this.delegation,
    required this.requestType,
    required this.compensationType,
    required this.status,
    required this.detailNote,
    required this.approvalSteps,
    required this.attachments,
    this.spvName,
    this.managementName,
  });

  final String id;
  final String date;
  final String reason;
  final String delegation;
  final LeaveRequestType requestType;
  final LeaveCompensationType compensationType;
  final LeaveStatus status;
  final String detailNote;
  final List<ApprovalStep> approvalSteps;
  final List<RemoteAttachment> attachments;
  final String? spvName;
  final String? managementName;
}

enum LeaveRequestType {
  cuti,
  sakit,
  izinPerJam,
  izinPerHari;
}

extension LeaveRequestTypeX on LeaveRequestType {
  String get label {
    switch (this) {
      case LeaveRequestType.cuti:
        return 'Cuti';
      case LeaveRequestType.sakit:
        return 'Sakit';
      case LeaveRequestType.izinPerJam:
        return 'Izin per jam';
      case LeaveRequestType.izinPerHari:
        return 'Izin per hari';
    }
  }
}

enum LeaveCompensationType {
  potongSaldoCuti,
  potongGaji,
  tidakPotongGaji;
}

extension LeaveCompensationTypeX on LeaveCompensationType {
  String get label {
    switch (this) {
      case LeaveCompensationType.potongSaldoCuti:
        return 'Potong saldo cuti';
      case LeaveCompensationType.potongGaji:
        return 'Potong gaji';
      case LeaveCompensationType.tidakPotongGaji:
        return 'Tidak potong gaji';
    }
  }
}

enum LeaveStatus {
  pending,
  approved,
  rejected;
}

extension LeaveStatusX on LeaveStatus {
  String get label {
    switch (this) {
      case LeaveStatus.pending:
        return 'Pending';
      case LeaveStatus.approved:
        return 'Disetujui';
      case LeaveStatus.rejected:
        return 'Ditolak';
    }
  }

  Color get color {
    switch (this) {
      case LeaveStatus.pending:
        return Colors.orange;
      case LeaveStatus.approved:
        return Colors.green;
      case LeaveStatus.rejected:
        return Colors.red;
    }
  }
}

extension on LeaveRequestType {
  leave_model.LeaveCategory toRecordCategory() {
    switch (this) {
      case LeaveRequestType.cuti:
        return leave_model.LeaveCategory.cuti;
      case LeaveRequestType.sakit:
        return leave_model.LeaveCategory.sakit;
      case LeaveRequestType.izinPerJam:
        return leave_model.LeaveCategory.izinPerJam;
      case LeaveRequestType.izinPerHari:
        return leave_model.LeaveCategory.izinPerHari;
    }
  }
}

extension on LeaveCompensationType {
  leave_model.LeaveCompensationOption toRecordOption() {
    switch (this) {
      case LeaveCompensationType.potongSaldoCuti:
        return leave_model.LeaveCompensationOption.potongSaldoCuti;
      case LeaveCompensationType.potongGaji:
        return leave_model.LeaveCompensationOption.potongGaji;
      case LeaveCompensationType.tidakPotongGaji:
        return leave_model.LeaveCompensationOption.tidakPotongGaji;
    }
  }
}

extension on leave_model.LeaveCategory {
  LeaveRequestType toUiType() {
    switch (this) {
      case leave_model.LeaveCategory.cuti:
        return LeaveRequestType.cuti;
      case leave_model.LeaveCategory.sakit:
        return LeaveRequestType.sakit;
      case leave_model.LeaveCategory.izinPerJam:
        return LeaveRequestType.izinPerJam;
      case leave_model.LeaveCategory.izinPerHari:
        return LeaveRequestType.izinPerHari;
    }
  }
}

extension on leave_model.LeaveCompensationOption {
  LeaveCompensationType toUiCompensation() {
    switch (this) {
      case leave_model.LeaveCompensationOption.potongSaldoCuti:
        return LeaveCompensationType.potongSaldoCuti;
      case leave_model.LeaveCompensationOption.potongGaji:
        return LeaveCompensationType.potongGaji;
      case leave_model.LeaveCompensationOption.tidakPotongGaji:
        return LeaveCompensationType.tidakPotongGaji;
    }
  }
}

extension on leave_model.WorkflowStatus {
  LeaveStatus toUiStatus() {
    switch (this) {
      case leave_model.WorkflowStatus.approved:
        return LeaveStatus.approved;
      case leave_model.WorkflowStatus.rejected:
        return LeaveStatus.rejected;
      case leave_model.WorkflowStatus.pending:
      case leave_model.WorkflowStatus.draft:
      case leave_model.WorkflowStatus.cancelled:
      case leave_model.WorkflowStatus.completed:
        return LeaveStatus.pending;
    }
  }
}
