<?php

use App\Http\Controllers\Web\AdminAuthController;
use App\Http\Controllers\Web\AdminDashboardController;
use App\Http\Controllers\Web\AnnouncementController;
use App\Http\Controllers\Web\AttendanceMonitoringController;
use App\Http\Controllers\Web\ApprovalCenterController;
use App\Http\Controllers\Web\EmployeeController;
use App\Http\Controllers\Web\LeaveMonitoringController;
use App\Http\Controllers\Web\NetworkMonitoringController;
use App\Http\Controllers\Web\ReportsController;
use App\Http\Controllers\Web\SurveyController;
use App\Http\Controllers\Web\WfaMonitoringController;
use App\Http\Middleware\EnsureHrAdmin;
use Illuminate\Support\Facades\Route;

Route::get('/', fn () => redirect()->route('admin.login'));

Route::get('/admin/login', [AdminAuthController::class, 'showLogin'])->name('admin.login');
Route::post('/admin/login', [AdminAuthController::class, 'login'])->name('admin.login.store');

Route::middleware([EnsureHrAdmin::class])->prefix('admin')->name('admin.')->group(function () {
    Route::get('/dashboard', AdminDashboardController::class)->name('dashboard');
    Route::post('/logout', [AdminAuthController::class, 'logout'])->name('logout');
    Route::get('/announcements', [AnnouncementController::class, 'index'])->name('announcements.index');
    Route::post('/announcements', [AnnouncementController::class, 'store'])->name('announcements.store');
    Route::delete('/announcements/{announcement}', [AnnouncementController::class, 'destroy'])->name('announcements.destroy');

    Route::resource('employees', EmployeeController::class)->except('destroy');
    Route::post('/employees/{employee}/performance-targets', [EmployeeController::class, 'updatePerformanceTargets'])
        ->name('employees.targets.update');
    Route::get('/attendance', [AttendanceMonitoringController::class, 'index'])->name('attendance.index');
    Route::post('/attendance/work-areas', [AttendanceMonitoringController::class, 'storeWorkArea'])->name('attendance.work-areas.store');
    Route::put('/attendance/work-areas/{workArea}', [AttendanceMonitoringController::class, 'updateWorkArea'])->name('attendance.work-areas.update');
    Route::get('/leaves', [LeaveMonitoringController::class, 'index'])->name('leaves.index');
    Route::get('/wfa', [WfaMonitoringController::class, 'index'])->name('wfa.index');
    Route::get('/wfa/{requestRecord}', [WfaMonitoringController::class, 'show'])->name('wfa.show');
    Route::get('/approvals', [ApprovalCenterController::class, 'index'])->name('approvals.index');
    Route::get('/network', [NetworkMonitoringController::class, 'index'])->name('network.index');
    Route::post('/network/manual', [NetworkMonitoringController::class, 'storeManual'])->name('network.manual.store');
    Route::get('/network/{profile}', [NetworkMonitoringController::class, 'show'])->name('network.show');
    Route::get('/surveys', [SurveyController::class, 'index'])->name('surveys.index');
    Route::post('/surveys/products', [SurveyController::class, 'storeProduct'])->name('surveys.products.store');
    Route::delete('/surveys/products/{product}', [SurveyController::class, 'destroyProduct'])->name('surveys.products.destroy');
    Route::post('/surveys/commodities', [SurveyController::class, 'storeCommodity'])->name('surveys.commodities.store');
    Route::delete('/surveys/commodities/{commodity}', [SurveyController::class, 'destroyCommodity'])->name('surveys.commodities.destroy');
    Route::get('/reports', [ReportsController::class, 'index'])->name('reports.index');
});
