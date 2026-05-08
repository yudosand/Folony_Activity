import 'package:flutter/material.dart';

import '../enums/app_role.dart';
import '../models/approval_step.dart';
import 'status_badge.dart';

class ApprovalStepList extends StatelessWidget {
  const ApprovalStepList({
    super.key,
    required this.steps,
    this.compact = false,
  });

  final List<ApprovalStep> steps;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (steps.isEmpty) {
      return Text(
        'Tidak ada approval step untuk item ini.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          _ApprovalStepTile(
            step: steps[i],
            compact: compact,
          ),
          if (i != steps.length - 1) SizedBox(height: compact ? 10 : 14),
        ],
      ],
    );
  }
}

class _ApprovalStepTile extends StatelessWidget {
  const _ApprovalStepTile({
    required this.step,
    required this.compact,
  });

  final ApprovalStep step;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
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
                    Text(
                      'Step ${step.sequence} - ${step.approverRole.label}',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      step.approverName ?? 'Approver belum ditentukan',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: step.status.label,
                color: _statusColor(step.status),
              ),
            ],
          ),
          if (step.actedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Diproses ${_formatDateTime(step.actedAt!)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (step.note != null && step.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              step.note!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(ApprovalStepStatus status) {
    switch (status) {
      case ApprovalStepStatus.pending:
        return Colors.orange;
      case ApprovalStepStatus.approved:
        return Colors.green;
      case ApprovalStepStatus.rejected:
        return Colors.red;
      case ApprovalStepStatus.skipped:
        return Colors.blueGrey;
    }
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}
