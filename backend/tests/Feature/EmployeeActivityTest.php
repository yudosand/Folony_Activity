<?php

namespace Tests\Feature;

use App\Models\EmployeeActivity;
use App\Models\User;
use Database\Seeders\WorkflowDemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class EmployeeActivityTest extends TestCase
{
    use RefreshDatabase;

    public function test_employee_updates_persist_and_hr_can_read_all_employees_and_export(): void
    {
        $this->freezeTime();
        $this->seed(WorkflowDemoSeeder::class);
        $staff = User::where('role', 'staff')->firstOrFail();
        Sanctum::actingAs($staff);
        $payload = ['request_id' => 'work-one', 'note' => 'Menata laporan harian',
            'photo_url' => 'https://example.test/storage/work.jpg', 'is_finished' => false];
        $start = $this->postJson('/api/employee-activities', $payload)
            ->assertCreated()->assertJsonPath('data.user_id', $staff->id)->json('data.started_at');
        $this->postJson('/api/employee-activities', $payload)->assertCreated();
        $this->assertDatabaseCount('employee_activities', 1);
        $this->travel(5)->minutes();
        $this->postJson('/api/employee-activities', [...$payload, 'request_id' => 'work-two', 'note' => 'Laporan selesai', 'is_finished' => true])
            ->assertCreated()->assertJsonPath('data.started_at', $start)->assertJsonPath('data.is_finished', true);
        $this->getJson('/api/employee-activities')->assertOk()->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.note', 'Laporan selesai');

        $other = User::where('id', '!=', $staff->id)->where('role', '!=', 'hr')->firstOrFail();
        Sanctum::actingAs($other);
        $this->getJson('/api/employee-activities')->assertOk()->assertJsonCount(0, 'data');
        $this->postJson('/api/employee-activities', $payload)->assertForbidden();
        $this->postJson('/api/employee-activities', [...$payload, 'request_id' => 'other-work', 'note' => 'Kunjungan cabang'])->assertCreated();

        $this->actingAs($staff, 'web')->get('/admin/employee-activities')->assertForbidden();
        $hr = User::where('email', 'hr@hex.local')->firstOrFail();
        $this->actingAs($hr, 'web')->get('/admin/employee-activities')->assertOk()
            ->assertSee('Aktifitas Karyawan')->assertSee($staff->full_name)
            ->assertSee($other->full_name)->assertSee('00:05:00')->assertDontSee('Menata laporan harian');
        $date = EmployeeActivity::where('user_id', $staff->id)->firstOrFail()->started_at->format('Y-m-d');
        $this->get('/admin/employee-activities/'.$staff->id.'/'.$date)->assertOk()
            ->assertSee('Menata laporan harian')->assertSee('Laporan selesai')->assertSee('work.jpg')->assertDontSee('Kunjungan cabang');
        $this->get('/admin/employee-activities?search='.$staff->employee_code)->assertOk()
            ->assertViewHas('days', fn ($days) => $days->total() === 1);
        $this->get('/admin/employee-activities?export=csv')->assertOk()
            ->assertDownload('aktifitas-karyawan.csv');
    }

    public function test_anonymous_and_invalid_activity_submissions_are_rejected(): void
    {
        $this->getJson('/api/employee-activities')->assertUnauthorized();
        $this->seed(WorkflowDemoSeeder::class);
        Sanctum::actingAs(User::where('role', 'staff')->firstOrFail());
        $this->postJson('/api/employee-activities', ['request_id' => 'finish-without-start', 'note' => 'Selesai', 'is_finished' => true])->assertUnprocessable();
        $this->postJson('/api/employee-activities', ['request_id' => 'empty', 'note' => '   ', 'is_finished' => false])->assertUnprocessable();
        $this->assertDatabaseCount('employee_activities', 0);
    }

    public function test_daily_summary_sums_sessions_excludes_breaks_and_keeps_overnight_updates(): void
    {
        $this->seed(WorkflowDemoSeeder::class);
        $staff = User::where('role', 'staff')->firstOrFail();
        $this->travelTo(\Illuminate\Support\Carbon::parse('2026-09-11 12:00:00'));
        $events = [
            ['2026-09-10 08:00:05', '2026-09-10 08:00:05', false, 'Mulai laporan'],
            ['2026-09-10 08:00:05', '2026-09-10 10:00:15', true, 'Laporan tuntas'],
            ['2026-09-10 23:00:00', '2026-09-10 23:00:00', false, 'Mulai malam'],
            ['2026-09-10 23:00:00', '2026-09-11 01:30:00', true, 'Selesai malam'],
            ['2026-09-11 11:00:00', '2026-09-11 11:00:00', false, 'Pekerjaan hari berikutnya'],
        ];
        foreach ($events as $i => [$start, $updated, $finished, $note]) {
            $record = new EmployeeActivity(['user_id' => $staff->id, 'request_id' => 'duration-'.$i,
                'started_at' => $start, 'is_finished' => $finished, 'note' => $note]);
            $record->created_at = $updated;
            $record->save();
        }
        $hr = User::where('email', 'hr@hex.local')->firstOrFail();
        $this->actingAs($hr)->get('/admin/employee-activities?from=2026-09-10&to=2026-09-10&status=completed')
            ->assertOk()->assertSee('04:30:10')->assertSee('11/09/2026 01:30:00')
            ->assertViewHas('days', fn ($days) => $days->total() === 1 && (int) $days->first()->update_count === 4);
        $this->get('/admin/employee-activities/'.$staff->id.'/2026-09-10')->assertOk()
            ->assertSee('Selesai malam')->assertDontSee('Pekerjaan hari berikutnya');
        $this->get('/admin/employee-activities?status=active')->assertOk()->assertSee('01:00:00')
            ->assertViewHas('days', fn ($days) => $days->total() === 1);
        $this->get('/admin/employee-activities/'.$staff->id.'/2026-09-09')->assertNotFound();
        $this->actingAs($staff)->get('/admin/employee-activities/'.$staff->id.'/2026-09-10')->assertForbidden();
    }
}
