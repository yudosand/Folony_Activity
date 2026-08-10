import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../core/enums/app_role.dart';
import '../../../core/models/app_session.dart';
import '../../../core/models/approval_step.dart';
import '../../../core/models/leave_request_record.dart' as leave_model;
import '../../../core/models/wfa_request_record.dart' as wfa_model;
import '../../../core/widgets/approval_step_list.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';

class LeaveApprovalPage extends StatefulWidget {
  const LeaveApprovalPage({
    super.key,
    required this.session,
    required this.controller,
  });

  final AppSession session;
  final AppController controller;

  @override
  State<LeaveApprovalPage> createState() => _LeaveApprovalPageState();
}

class _LeaveApprovalPageState extends State<LeaveApprovalPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);
  bool _decisionDialogOpen = false;
  bool _approvalActionInFlight = false;
  bool _pendingControllerRefresh = false;

  List<LeaveApprovalRequest> get _leaveRequests => widget.controller
      .leaveApprovalsForSession(widget.session)
      .map(_mapLeaveRequest)
      .toList();

  List<WfaApprovalRequest> get _wfaRequests => widget.controller
      .wfaApprovalsForSession(widget.session)
      .map(_mapWfaRequest)
      .toList();

  int get _pendingLeaveCount {
    return _leaveRequests
        .where((item) => item.status == ApprovalStatus.pending)
        .length;
  }

  int get _pendingWfaCount {
    return _wfaRequests
        .where((item) => item.status == ApprovalStatus.pending)
        .length;
  }

  bool get _allResolved {
    return _leaveRequests
            .every((request) => request.status != ApprovalStatus.pending) &&
        _wfaRequests
            .every((request) => request.status != ApprovalStatus.pending);
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }
    if (_decisionDialogOpen || _approvalActionInFlight) {
      _pendingControllerRefresh = true;
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Approval Pengajuan', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                '$_pendingLeaveCount cuti/izin dan $_pendingWfaCount WFA masih menunggu keputusan.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CountPill(
                    label: 'Cuti / Izin',
                    value: _pendingLeaveCount.toString(),
                  ),
                  _CountPill(
                    label: 'WFA',
                    value: _pendingWfaCount.toString(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Cuti / Izin'),
                  Tab(text: 'WFA'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildLeaveTab(context),
              _buildWfaTab(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveTab(BuildContext context) {
    final requests = _leaveRequests;

    return RefreshIndicator(
      onRefresh: () =>
          widget.controller.refreshWorkflowDataForSession(widget.session),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          if (requests.isEmpty)
            const EmptyState(
              icon: Icons.fact_check_outlined,
              title: 'Tidak ada pengajuan cuti',
              message:
                  'Pengajuan cuti atau izin yang perlu diputuskan akan muncul di sini.',
            )
          else
            for (var i = 0; i < requests.length; i++) ...[
              _LeaveApprovalItem(
                request: requests[i],
                onOpen: () => _showLeaveDetail(requests[i]),
                onApprove: requests[i].status == ApprovalStatus.pending
                    ? () => _handleLeaveDecision(
                          requests[i],
                          ApprovalStatus.approved,
                        )
                    : null,
                onReject: requests[i].status == ApprovalStatus.pending
                    ? () => _handleLeaveDecision(
                          requests[i],
                          ApprovalStatus.rejected,
                        )
                    : null,
              ),
              if (i != requests.length - 1) const Divider(height: 24),
            ],
          if (_allResolved) ...[
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: _resetMocks,
              child: const Text('Reset Mock Approval'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWfaTab(BuildContext context) {
    final requests = _wfaRequests;

    return RefreshIndicator(
      onRefresh: () =>
          widget.controller.refreshWorkflowDataForSession(widget.session),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          if (requests.isEmpty)
            const EmptyState(
              icon: Icons.laptop_mac_rounded,
              title: 'Tidak ada pengajuan WFA',
              message:
                  'Pengajuan WFA atau overtime yang perlu diputuskan akan muncul di sini.',
            )
          else
            for (var i = 0; i < requests.length; i++) ...[
              _WfaApprovalItem(
                request: requests[i],
                onOpen: () => _showWfaDetail(requests[i]),
                onApprove: requests[i].status == ApprovalStatus.pending
                    ? () => _handleWfaDecision(
                          requests[i],
                          ApprovalStatus.approved,
                        )
                    : null,
                onReject: requests[i].status == ApprovalStatus.pending
                    ? () => _handleWfaDecision(
                          requests[i],
                          ApprovalStatus.rejected,
                        )
                    : null,
              ),
              if (i != requests.length - 1) const Divider(height: 24),
            ],
          if (_allResolved) ...[
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: _resetMocks,
              child: const Text('Reset Mock Approval'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _updateLeaveStatus(
    LeaveApprovalRequest request,
    ApprovalStatus status,
    String? note,
  ) async {
    if (status == ApprovalStatus.approved) {
      await widget.controller.approveLeaveRequest(
        widget.session,
        requestId: request.id,
        note: note,
      );
    } else {
      await widget.controller.rejectLeaveRequest(
        widget.session,
        requestId: request.id,
        note: note,
      );
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('Pengajuan cuti ${request.name} ${status.snackbarLabel}')),
    );
  }

  Future<void> _updateWfaStatus(
    WfaApprovalRequest request,
    ApprovalStatus status,
    String? note,
  ) async {
    if (status == ApprovalStatus.approved) {
      await widget.controller.approveWfaRequest(
        widget.session,
        requestId: request.id,
        note: note,
      );
    } else {
      await widget.controller.rejectWfaRequest(
        widget.session,
        requestId: request.id,
        note: note,
      );
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('Pengajuan WFA ${request.name} ${status.snackbarLabel}')),
    );
  }

  Future<void> _resetMocks() async {
    await widget.controller.resetWorkflowMocksForSession(widget.session);
  }

  Future<void> _handleLeaveDecision(
    LeaveApprovalRequest request,
    ApprovalStatus status,
  ) async {
    final note = await _promptDecisionNote(
      title: status == ApprovalStatus.approved
          ? 'Catatan Persetujuan'
          : 'Alasan Penolakan',
      confirmLabel: status == ApprovalStatus.approved ? 'Setujui' : 'Tolak',
      helperText: status == ApprovalStatus.approved
          ? 'Opsional, misalnya catatan follow-up setelah disetujui.'
          : 'Tambahkan alasan agar requester tahu kenapa pengajuan ditolak.',
    );
    if (!mounted || note == null) {
      return;
    }
    _approvalActionInFlight = true;
    try {
      await WidgetsBinding.instance.endOfFrame;
      await _updateLeaveStatus(request, status, note);
    } finally {
      _approvalActionInFlight = false;
      if (mounted && _pendingControllerRefresh) {
        _pendingControllerRefresh = false;
        setState(() {});
      }
    }
  }

  Future<void> _handleWfaDecision(
    WfaApprovalRequest request,
    ApprovalStatus status,
  ) async {
    final note = await _promptDecisionNote(
      title: status == ApprovalStatus.approved
          ? 'Catatan Persetujuan'
          : 'Alasan Penolakan',
      confirmLabel: status == ApprovalStatus.approved ? 'Setujui' : 'Tolak',
      helperText: status == ApprovalStatus.approved
          ? 'Opsional, misalnya batasan output atau arahan kompensasi.'
          : 'Tambahkan alasan agar requester tahu kenapa pengajuan ditolak.',
    );
    if (!mounted || note == null) {
      return;
    }
    _approvalActionInFlight = true;
    try {
      await WidgetsBinding.instance.endOfFrame;
      await _updateWfaStatus(request, status, note);
    } finally {
      _approvalActionInFlight = false;
      if (mounted && _pendingControllerRefresh) {
        _pendingControllerRefresh = false;
        setState(() {});
      }
    }
  }

  Future<String?> _promptDecisionNote({
    required String title,
    required String confirmLabel,
    required String helperText,
  }) async {
    _decisionDialogOpen = true;
    try {
      final dialogHostContext =
          Navigator.of(context, rootNavigator: true).context;
      return await showGeneralDialog<String>(
        context: dialogHostContext,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(dialogHostContext)
            .modalBarrierDismissLabel,
        barrierColor: Colors.black54,
        transitionDuration: Duration.zero,
        pageBuilder: (dialogContext, _, __) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _DecisionNoteDialog(
              title: title,
              helperText: helperText,
              confirmLabel: confirmLabel,
            ),
          ),
        ),
      );
    } finally {
      await WidgetsBinding.instance.endOfFrame;
      _decisionDialogOpen = false;
      if (mounted && _pendingControllerRefresh && !_approvalActionInFlight) {
        _pendingControllerRefresh = false;
        setState(() {});
      }
    }
  }

  void _showLeaveDetail(LeaveApprovalRequest request) {
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.82,
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
                          child: Text(request.name,
                              style: theme.textTheme.titleLarge),
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
                    _DetailLine(label: 'Jenis', value: request.requestType),
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
                    if (request.status == ApprovalStatus.pending) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                await _handleLeaveDecision(
                                  request,
                                  ApprovalStatus.rejected,
                                );
                              },
                              child: const Text('Tolak'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                await _handleLeaveDecision(
                                  request,
                                  ApprovalStatus.approved,
                                );
                              },
                              child: const Text('Setujui'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showWfaDetail(WfaApprovalRequest request) {
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.82,
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
                          child: Text(request.name,
                              style: theme.textTheme.titleLarge),
                        ),
                        const SizedBox(width: 12),
                        StatusBadge(
                          label: request.status.label,
                          color: request.status.color,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _DetailLine(label: 'Jenis', value: request.requestType),
                    const Divider(height: 24),
                    _DetailLine(label: 'Tanggal', value: request.workDate),
                    const Divider(height: 24),
                    _DetailLine(label: 'Jadwal', value: request.schedule),
                    const Divider(height: 24),
                    _DetailLine(label: 'Lokasi', value: request.location),
                    const Divider(height: 24),
                    _DetailLine(
                        label: 'Kompensasi', value: request.compensation),
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
                    _DetailLine(label: 'Catatan', value: request.note),
                    const Divider(height: 24),
                    Text('Alur Approval', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    ApprovalStepList(steps: request.approvalSteps),
                    if (request.status == ApprovalStatus.pending) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                await _handleWfaDecision(
                                  request,
                                  ApprovalStatus.rejected,
                                );
                              },
                              child: const Text('Tolak'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                await _handleWfaDecision(
                                  request,
                                  ApprovalStatus.approved,
                                );
                              },
                              child: const Text('Setujui'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  LeaveApprovalRequest _mapLeaveRequest(leave_model.LeaveRequestRecord record) {
    return LeaveApprovalRequest(
      id: record.id,
      name: record.requesterName,
      date: '${_formatDate(record.startAt)} - ${_formatDate(record.endAt)}',
      requestType: record.category.toApprovalLabel(),
      reason: record.reason,
      delegation: record.delegateTo,
      spvName: _approverNameForRole(record.approvalSteps, AppRole.spv),
      managementName: _approverNameForRole(
        record.approvalSteps,
        AppRole.management,
      ),
      status: record.status.toApprovalStatus(),
      approvalSteps: record.approvalSteps,
    );
  }

  WfaApprovalRequest _mapWfaRequest(wfa_model.WfaRequestRecord record) {
    return WfaApprovalRequest(
      id: record.id,
      name: record.requesterName,
      requestType: record.mode.toApprovalLabel(),
      workDate: _formatDate(record.workDate),
      schedule: '${record.startTime} - ${record.endTime}',
      location: record.locationLabel,
      compensation: record.compensationMode.toApprovalLabel(),
      reason: record.reason,
      initialTask: record.initialTask,
      note: record.note ?? '-',
      status: record.status.toApprovalStatus(),
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
}

class _LeaveApprovalItem extends StatelessWidget {
  const _LeaveApprovalItem({
    required this.request,
    required this.onOpen,
    required this.onApprove,
    required this.onReject,
  });

  final LeaveApprovalRequest request;
  final VoidCallback onOpen;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE7E5E4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        request.requestType,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                    label: request.status.label, color: request.status.color),
              ],
            ),
            const SizedBox(height: 10),
            _MiniInfoRow(label: 'Tanggal', value: request.date),
            const SizedBox(height: 4),
            _MiniInfoRow(label: 'Delegasi', value: request.delegation),
            const SizedBox(height: 6),
            Text(
              request.reason,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton(
                  onPressed: onReject,
                  child: const Text('Tolak'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onApprove,
                  child: const Text('Setujui'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WfaApprovalItem extends StatelessWidget {
  const _WfaApprovalItem({
    required this.request,
    required this.onOpen,
    required this.onApprove,
    required this.onReject,
  });

  final WfaApprovalRequest request;
  final VoidCallback onOpen;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE7E5E4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        request.requestType,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: request.requestType.contains('Overtime')
                              ? const Color(0xFFB45309)
                              : theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                    label: request.status.label, color: request.status.color),
              ],
            ),
            const SizedBox(height: 10),
            _MiniInfoRow(label: 'Tanggal', value: request.workDate),
            const SizedBox(height: 4),
            _MiniInfoRow(label: 'Jadwal', value: request.schedule),
            const SizedBox(height: 4),
            _MiniInfoRow(label: 'Kompensasi', value: request.compensation),
            const SizedBox(height: 6),
            Text(
              request.location,
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
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton(
                  onPressed: onReject,
                  child: const Text('Tolak'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onApprove,
                  child: const Text('Setujui'),
                ),
              ],
            ),
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
          width: 96,
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

class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfoRow extends StatelessWidget {
  const _MiniInfoRow({
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
          width: 84,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _DecisionNoteDialog extends StatefulWidget {
  const _DecisionNoteDialog({
    required this.title,
    required this.helperText,
    required this.confirmLabel,
  });

  final String title;
  final String helperText;
  final String confirmLabel;

  @override
  State<_DecisionNoteDialog> createState() => _DecisionNoteDialogState();
}

class _DecisionNoteDialogState extends State<_DecisionNoteDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.helperText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Tulis catatan keputusan',
              ),
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
          onPressed: () => Navigator.pop(
            context,
            _controller.text.trim(),
          ),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class LeaveApprovalRequest {
  const LeaveApprovalRequest({
    required this.id,
    required this.name,
    required this.date,
    required this.requestType,
    required this.reason,
    required this.delegation,
    required this.status,
    required this.approvalSteps,
    this.spvName,
    this.managementName,
  });

  final String id;
  final String name;
  final String date;
  final String requestType;
  final String reason;
  final String delegation;
  final ApprovalStatus status;
  final List<ApprovalStep> approvalSteps;
  final String? spvName;
  final String? managementName;

  LeaveApprovalRequest copyWith({
    ApprovalStatus? status,
    List<ApprovalStep>? approvalSteps,
  }) {
    return LeaveApprovalRequest(
      id: id,
      name: name,
      date: date,
      requestType: requestType,
      reason: reason,
      delegation: delegation,
      status: status ?? this.status,
      approvalSteps: approvalSteps ?? this.approvalSteps,
      spvName: spvName,
      managementName: managementName,
    );
  }
}

class WfaApprovalRequest {
  const WfaApprovalRequest({
    required this.id,
    required this.name,
    required this.requestType,
    required this.workDate,
    required this.schedule,
    required this.location,
    required this.compensation,
    required this.reason,
    required this.initialTask,
    required this.note,
    required this.status,
    required this.approvalSteps,
    this.spvName,
    this.managementName,
  });

  final String id;
  final String name;
  final String requestType;
  final String workDate;
  final String schedule;
  final String location;
  final String compensation;
  final String reason;
  final String initialTask;
  final String note;
  final ApprovalStatus status;
  final List<ApprovalStep> approvalSteps;
  final String? spvName;
  final String? managementName;

  WfaApprovalRequest copyWith({
    ApprovalStatus? status,
    List<ApprovalStep>? approvalSteps,
  }) {
    return WfaApprovalRequest(
      id: id,
      name: name,
      requestType: requestType,
      workDate: workDate,
      schedule: schedule,
      location: location,
      compensation: compensation,
      reason: reason,
      initialTask: initialTask,
      note: note,
      status: status ?? this.status,
      approvalSteps: approvalSteps ?? this.approvalSteps,
      spvName: spvName,
      managementName: managementName,
    );
  }
}

enum ApprovalStatus {
  pending,
  approved,
  rejected;
}

extension ApprovalStatusX on ApprovalStatus {
  String get label {
    switch (this) {
      case ApprovalStatus.pending:
        return 'Pending';
      case ApprovalStatus.approved:
        return 'Disetujui';
      case ApprovalStatus.rejected:
        return 'Ditolak';
    }
  }

  Color get color {
    switch (this) {
      case ApprovalStatus.pending:
        return Colors.orange;
      case ApprovalStatus.approved:
        return Colors.green;
      case ApprovalStatus.rejected:
        return Colors.red;
    }
  }

  String get snackbarLabel {
    switch (this) {
      case ApprovalStatus.pending:
        return 'dikembalikan ke pending';
      case ApprovalStatus.approved:
        return 'disetujui';
      case ApprovalStatus.rejected:
        return 'ditolak';
    }
  }
}

extension on leave_model.LeaveCategory {
  String toApprovalLabel() {
    switch (this) {
      case leave_model.LeaveCategory.cuti:
        return 'Cuti';
      case leave_model.LeaveCategory.sakit:
        return 'Sakit';
      case leave_model.LeaveCategory.izinPerJam:
        return 'Izin per jam';
      case leave_model.LeaveCategory.izinPerHari:
        return 'Izin per hari';
    }
  }
}

extension on leave_model.WorkflowStatus {
  ApprovalStatus toApprovalStatus() {
    switch (this) {
      case leave_model.WorkflowStatus.approved:
        return ApprovalStatus.approved;
      case leave_model.WorkflowStatus.rejected:
        return ApprovalStatus.rejected;
      case leave_model.WorkflowStatus.pending:
      case leave_model.WorkflowStatus.draft:
      case leave_model.WorkflowStatus.cancelled:
      case leave_model.WorkflowStatus.completed:
        return ApprovalStatus.pending;
    }
  }
}

extension on wfa_model.WfaRequestMode {
  String toApprovalLabel() {
    switch (this) {
      case wfa_model.WfaRequestMode.regular:
        return 'WFA Reguler';
      case wfa_model.WfaRequestMode.overtime:
        return 'WFA Overtime';
    }
  }
}

extension on wfa_model.WfaCompensationMode {
  String toApprovalLabel() {
    switch (this) {
      case wfa_model.WfaCompensationMode.normalShift:
        return 'Normal shift';
      case wfa_model.WfaCompensationMode.shiftMundur:
        return 'Jam masuk mundur';
      case wfa_model.WfaCompensationMode.klaimLembur:
        return 'Klaim lembur';
      case wfa_model.WfaCompensationMode.reviewHr:
        return 'Review HR/Management';
    }
  }
}

extension on wfa_model.WorkflowStatus {
  ApprovalStatus toApprovalStatus() {
    switch (this) {
      case wfa_model.WorkflowStatus.approved:
        return ApprovalStatus.approved;
      case wfa_model.WorkflowStatus.rejected:
        return ApprovalStatus.rejected;
      case wfa_model.WorkflowStatus.pending:
      case wfa_model.WorkflowStatus.draft:
      case wfa_model.WorkflowStatus.cancelled:
      case wfa_model.WorkflowStatus.active:
      case wfa_model.WorkflowStatus.completed:
        return ApprovalStatus.pending;
    }
  }
}
