<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\EmployeeActivity;
use App\Models\User;
use App\Services\Admin\AdminExportService;
use App\Services\Admin\EmployeeActivitySummary;
use App\Support\Workflow\UserRole;
use Illuminate\Http\Request;

class EmployeeActivityController extends Controller
{
    public function index(Request $request, AdminExportService $exportService, EmployeeActivitySummary $summary)
    {
        $filters = $request->validate([
            'search' => ['nullable', 'string', 'max:200'],
            'from' => ['nullable', 'date_format:Y-m-d'],
            'to' => ['nullable', 'date_format:Y-m-d', 'after_or_equal:from'],
            'status' => ['nullable', 'in:active,completed'],
        ]);
        $query = $summary->days($filters);
        if ($request->string('export')->value() === 'csv') {
            return $exportService->streamCsv('aktifitas-karyawan.csv',
                ['Karyawan', 'NIK', 'Role', 'Tanggal Mulai', 'Mulai Kerja', 'Update Terakhir', 'Selesai', 'Durasi (HH:MM:SS)', 'Status', 'Jumlah Update'],
                $summary->withDurations($query->get())->map(fn ($day) => [
                    $day->full_name, $day->employee_code, UserRole::label($day->role), $day->work_date,
                    $day->started_at, $day->last_update, $day->finished_at, $day->duration_label,
                    $day->active_sessions ? 'Berjalan' : 'Selesai', $day->update_count,
                ]));
        }
        $days = $query->paginate(25)->withQueryString();
        $days->setCollection($summary->withDurations($days->getCollection()));
        return view('admin.employee-activities.index', ['days' => $days, 'filters' => $filters]);
    }

    public function show(Request $request, User $employee, string $date, EmployeeActivitySummary $summary)
    {
        validator(['date' => $date], ['date' => ['required', 'date_format:Y-m-d']])->validate();
        $day = $summary->days(['from' => $date, 'to' => $date])->where('sessions.user_id', $employee->id)->first();
        abort_unless($day, 404);
        $day = $summary->withDurations(collect([$day]))->first();
        $updates = EmployeeActivity::where('user_id', $employee->id)->whereDate('started_at', $date)
            ->orderBy('created_at')->orderBy('id')->paginate(50)->withQueryString();
        return view('admin.employee-activities.show', compact('employee', 'day', 'updates'));
    }
}
