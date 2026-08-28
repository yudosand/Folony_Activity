<?php

use App\Http\Controllers\Api\ApprovalController;
use App\Http\Controllers\Api\AnnouncementController;
use App\Http\Controllers\Api\AttendanceController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\DeviceTokenController;
use App\Http\Controllers\Api\FaceProfileController;
use App\Http\Controllers\Api\FaceVerificationController;
use App\Http\Controllers\Api\FaqController;
use App\Http\Controllers\Api\HeatMapController;
use App\Http\Controllers\Api\LeaveController;
use App\Http\Controllers\Api\MeController;
use App\Http\Controllers\Api\NetworkController;
use App\Http\Controllers\Api\PerformanceController;
use App\Http\Controllers\Api\ProfilePhotoController;
use App\Http\Controllers\Api\SurveyController;
use App\Http\Controllers\Api\TerritoryController;
use App\Http\Controllers\Api\UploadController;
use App\Http\Controllers\Api\WfaController;
use App\Http\Middleware\EnsureActiveApiUser;
use Illuminate\Support\Facades\Route;

Route::post('/auth/login', [AuthController::class, 'login']);

Route::get('/territories/provinces', [TerritoryController::class, 'provinces']);
Route::get('/territories/cities', [TerritoryController::class, 'cities']);
Route::get('/territories/districts', [TerritoryController::class, 'districts']);
Route::get('/territories/subdistricts', [TerritoryController::class, 'subdistricts']);

Route::middleware(['auth:sanctum', EnsureActiveApiUser::class])->group(function () {
    Route::post('/auth/logout', [AuthController::class, 'logout']);
    Route::post('/auth/change-password', [AuthController::class, 'changePassword']);
    Route::post('/devices/push-token', [DeviceTokenController::class, 'store']);
    Route::delete('/devices/push-token', [DeviceTokenController::class, 'destroy']);
    Route::get('/me', MeController::class);
    Route::get('/announcements', AnnouncementController::class);
    Route::get('/faqs', FaqController::class);
    Route::post('/profile/photo', [ProfilePhotoController::class, 'store']);
    Route::delete('/profile/photo', [ProfilePhotoController::class, 'destroy']);

    Route::get('/leave', [LeaveController::class, 'index']);
    Route::get('/leave/approvals', [LeaveController::class, 'approvals']);
    Route::post('/leave', [LeaveController::class, 'store']);
    Route::patch('/leave/{leaveRequest}/status', [LeaveController::class, 'updateStatus']);

    Route::get('/wfa', [WfaController::class, 'index']);
    Route::get('/wfa/approvals', [WfaController::class, 'approvals']);
    Route::post('/wfa', [WfaController::class, 'store']);
    Route::patch('/wfa/{wfaRequest}/status', [WfaController::class, 'updateStatus']);
    Route::post('/wfa/{wfaRequest}/task-updates', [WfaController::class, 'storeTaskUpdate']);

    Route::get('/network', [NetworkController::class, 'index']);
    Route::get('/network/team-ukm', [NetworkController::class, 'teamUkm']);
    Route::post('/network', [NetworkController::class, 'store']);
    Route::patch('/network/{networkProfile}', [NetworkController::class, 'update']);
    Route::delete('/network/{networkProfile}', [NetworkController::class, 'destroy']);
    Route::post('/network/{networkProfile}/follow-ups', [NetworkController::class, 'storeFollowUp']);

    Route::get('/performance/summary', [PerformanceController::class, 'summary']);

    Route::get('/attendance', [AttendanceController::class, 'index']);
    Route::post('/attendance/check-in', [AttendanceController::class, 'checkIn']);
    Route::post('/attendance/check-out', [AttendanceController::class, 'checkOut']);
    Route::post('/attendance/outside-office/start', [AttendanceController::class, 'outsideOfficeStart']);
    Route::post('/attendance/outside-office/finish', [AttendanceController::class, 'outsideOfficeFinish']);
    Route::get('/attendance/daily-summary', [AttendanceController::class, 'dailySummary']);
    Route::delete('/attendance', [AttendanceController::class, 'destroy']);

    Route::get('/face/profile', [FaceProfileController::class, 'show']);
    Route::post('/face/profile', [FaceProfileController::class, 'upsert']);
    Route::post('/face/verify', [FaceVerificationController::class, 'store']);

    Route::get('/heat-map', HeatMapController::class);
    Route::post('/uploads/attachments', [UploadController::class, 'store']);

    Route::get('/surveys/options', [SurveyController::class, 'options']);
    Route::post('/surveys/kios', [SurveyController::class, 'storeKios']);
    Route::post('/surveys/prices', [SurveyController::class, 'storePrices']);

    Route::get('/approvals/inbox', [ApprovalController::class, 'index']);
    Route::post('/approvals/{approvalIdentifier}/approve', [ApprovalController::class, 'approve'])->where('approvalIdentifier', '.*');
    Route::post('/approvals/{approvalIdentifier}/reject', [ApprovalController::class, 'reject'])->where('approvalIdentifier', '.*');
});
