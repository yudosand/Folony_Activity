import 'package:flutter_test/flutter_test.dart';
import 'package:folony_activity/core/enums/app_role.dart';
import 'package:folony_activity/core/models/wfa_request_record.dart';
import 'package:folony_activity/core/repositories/remote/remote_wfa_repository.dart';

void main() {
  group('wfaSubmitPayloadForApi', () {
    test('omits normalShift compensation for regular WFA', () {
      final payload = wfaSubmitPayloadForApi(_request(
        mode: WfaRequestMode.regular,
        compensationMode: WfaCompensationMode.normalShift,
      ));

      expect(payload['mode'], 'regular');
      expect(payload.containsKey('compensation_mode'), isFalse);
    });

    test('keeps compensation mode for overtime WFA', () {
      final payload = wfaSubmitPayloadForApi(_request(
        mode: WfaRequestMode.overtime,
        compensationMode: WfaCompensationMode.shiftMundur,
      ));

      expect(payload['mode'], 'overtime');
      expect(payload['compensation_mode'], 'shiftMundur');
    });
  });
}

WfaRequestRecord _request({
  required WfaRequestMode mode,
  required WfaCompensationMode compensationMode,
}) {
  return WfaRequestRecord(
    id: 'wfa-test',
    requesterId: 'usr-test',
    requesterName: 'Tester',
    requesterRole: AppRole.staff,
    mode: mode,
    compensationMode: compensationMode,
    workDate: DateTime(2026, 8, 11),
    startTime: '08:30',
    endTime: '17:00',
    locationLabel: 'Staging',
    reason: 'Regression test',
    initialTask: 'Verify payload',
    status: WorkflowStatus.pending,
    approvalSteps: const [],
    taskUpdates: const [],
    submittedAt: DateTime(2026, 8, 11, 8, 0),
  );
}
