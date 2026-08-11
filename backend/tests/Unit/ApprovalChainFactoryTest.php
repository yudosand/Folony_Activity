<?php

namespace Tests\Unit;

use App\Models\User;
use App\Support\Workflow\ApprovalChainFactory;
use App\Support\Workflow\UserRole;
use Illuminate\Validation\ValidationException;
use Tests\TestCase;

class ApprovalChainFactoryTest extends TestCase
{
    public function test_it_uses_spv_and_management_when_both_are_available(): void
    {
        $spv = new User(['id' => 'usr_spv_test', 'full_name' => 'SPV Test']);
        $management = new User(['id' => 'usr_mgt_test', 'full_name' => 'Management Test']);
        $requester = new User([
            'id' => 'usr_staff_test',
            'role' => UserRole::STAFF,
            'spv_id' => 'usr_spv_test',
            'management_id' => 'usr_mgt_test',
        ]);
        $requester->setRelation('spv', $spv);
        $requester->setRelation('management', $management);

        $steps = (new ApprovalChainFactory())->buildFor($requester);

        $this->assertCount(2, $steps);
        $this->assertSame(1, $steps[0]['sequence']);
        $this->assertSame(UserRole::SPV, $steps[0]['approver_role']);
        $this->assertSame('usr_spv_test', $steps[0]['approver_id']);
        $this->assertSame('SPV Test', $steps[0]['approver_name']);
        $this->assertSame(2, $steps[1]['sequence']);
        $this->assertSame(UserRole::MANAGEMENT, $steps[1]['approver_role']);
        $this->assertSame('usr_mgt_test', $steps[1]['approver_id']);
        $this->assertSame('Management Test', $steps[1]['approver_name']);
    }

    public function test_it_falls_back_to_management_when_spv_is_not_available(): void
    {
        $management = new User(['id' => 'usr_mgt_test', 'full_name' => 'Management Test']);
        $requester = new User([
            'id' => 'usr_staff_test',
            'role' => UserRole::STAFF,
            'management_id' => 'usr_mgt_test',
        ]);
        $requester->setRelation('management', $management);

        $steps = (new ApprovalChainFactory())->buildFor($requester);

        $this->assertCount(1, $steps);
        $this->assertSame(UserRole::MANAGEMENT, $steps[0]['approver_role']);
        $this->assertSame('usr_mgt_test', $steps[0]['approver_id']);
    }

    public function test_it_blocks_requests_when_no_approver_is_configured(): void
    {
        $requester = new User([
            'id' => 'usr_staff_test',
            'role' => UserRole::STAFF,
        ]);

        $this->expectException(ValidationException::class);

        (new ApprovalChainFactory())->buildFor($requester);
    }
}
