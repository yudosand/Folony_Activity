<?php

namespace Tests\Feature;

use App\Models\AttendanceRecord;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AttendanceDailyTest extends TestCase
{
    use RefreshDatabase;

    public function test_daily_groups_keep_audit_attempts_and_count_only_completed_successful_sessions(): void
    {
        $staff = User::factory()->create(['role' => 'staff']);
        $other = User::factory()->create(['full_name' => $staff->full_name]);
        foreach ([['08:00:00', 'checkIn', 'success'], ['08:01:00', 'checkIn', 'failed'],
            ['12:00:00', 'checkOut', 'success'], ['13:00:00', 'checkIn', 'success'],
            ['17:00:00', 'checkOut', 'success'], ['18:00:00', 'outsideOfficeStart', 'success']] as $i => [$time, $action, $status]) {
            AttendanceRecord::create(['id' => 'daily-'.$i, 'user_id' => $staff->id, 'work_date' => '2026-09-16',
                'recorded_at' => '2026-09-16 '.$time, 'action' => $action, 'status' => $status, 'location' => [], 'verification' => [], 'metadata' => []]);
        }
        AttendanceRecord::create(['id' => 'other', 'user_id' => $other->id, 'work_date' => '2026-09-16',
            'recorded_at' => '2026-09-16 09:00:00', 'action' => 'outsideOfficeStart', 'status' => 'success', 'location' => [], 'verification' => [], 'metadata' => []]);
        $url = route('admin.attendance.show', ['employee' => $staff->id, 'date' => '2026-09-16']);
        $this->actingAs($staff)->get($url)->assertForbidden();
        $this->actingAs(User::factory()->create(['role' => 'hr']))->get('/admin/attendance')->assertOk()
            ->assertViewHas('days', fn ($days) => $days->total() === 2)->assertSee('08:00:00')->assertSee('Ada sesi belum selesai')->assertSee('Absensi luar kantor');
        $this->get($url)->assertOk()->assertViewHas('records', fn ($records) => $records->count() === 6)
            ->assertViewHas('day', fn ($day) => $day['duration_seconds'] === 28800 && $day['open_sessions'] === 1);
        $this->get('/admin/attendance?export=csv')->assertOk()->assertDownload('attendance-monitoring.csv');
        $this->get(str_replace('2026-09-16', '2026-02-30', $url))->assertNotFound();
    }
}
