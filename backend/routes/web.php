<?php

use App\Http\Controllers\Web\AdminAuthController;
use App\Http\Controllers\Web\AdminDashboardController;
use App\Http\Controllers\Web\AttendanceMonitoringController;
use App\Http\Controllers\Web\ApprovalCenterController;
use App\Http\Controllers\Web\EmployeeController;
use App\Http\Controllers\Web\LeaveMonitoringController;
use App\Http\Controllers\Web\NetworkMonitoringController;
use App\Http\Controllers\Web\ReportsController;
use App\Http\Controllers\Web\WfaMonitoringController;
use App\Http\Middleware\EnsureHrAdmin;
use Illuminate\Support\Facades\Route;

Route::get('/', fn () => redirect()->route('admin.login'));

Route::get('/admin/login', [AdminAuthController::class, 'showLogin'])->name('admin.login');
Route::post('/admin/login', [AdminAuthController::class, 'login'])->name('admin.login.store');

Route::middleware([EnsureHrAdmin::class])->prefix('admin')->name('admin.')->group(function () {
    Route::get('/dashboard', AdminDashboardController::class)->name('dashboard');
    Route::post('/logout', [AdminAuthController::class, 'logout'])->name('logout');

    Route::resource('employees', EmployeeController::class)->except('destroy');
    Route::post('/employees/{employee}/performance-targets', [EmployeeController::class, 'updatePerformanceTargets'])
        ->name('employees.targets.update');
    Route::get('/attendance', [AttendanceMonitoringController::class, 'index'])->name('attendance.index');
    Route::post('/attendance/office-setting', [AttendanceMonitoringController::class, 'updateOfficeSetting'])->name('attendance.office-setting.update');
    Route::get('/leaves', [LeaveMonitoringController::class, 'index'])->name('leaves.index');
    Route::get('/wfa', [WfaMonitoringController::class, 'index'])->name('wfa.index');
    Route::get('/wfa/{requestRecord}', [WfaMonitoringController::class, 'show'])->name('wfa.show');
    Route::get('/approvals', [ApprovalCenterController::class, 'index'])->name('approvals.index');
    Route::get('/network', [NetworkMonitoringController::class, 'index'])->name('network.index');
    Route::get('/network/{profile}', [NetworkMonitoringController::class, 'show'])->name('network.show');
    Route::get('/reports', [ReportsController::class, 'index'])->name('reports.index');
});
