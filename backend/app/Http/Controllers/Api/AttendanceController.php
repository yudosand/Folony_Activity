<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Attendance\StoreAttendanceCheckInRequest;
use App\Http\Requests\Attendance\StoreAttendanceCheckOutRequest;
use App\Http\Requests\Attendance\StoreOutsideOfficeAttendanceFinishRequest;
use App\Http\Requests\Attendance\StoreOutsideOfficeAttendanceStartRequest;
use App\Models\AttendanceRecord;
use App\Services\AttendanceService;
use App\Services\AttendanceSummaryService;
use App\Support\Api\ApiListResponse;
use App\Support\FieldOps\FieldApiData;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class AttendanceController extends Controller
{
    public function index(Request $request, AttendanceService $attendanceService): JsonResponse
    {
        $dateFrom = $request->filled('date_from')
            ? Carbon::parse($request->string('date_from')->toString())
            : null;
        $dateTo = $request->filled('date_to')
            ? Carbon::parse($request->string('date_to')->toString())
            : null;

        $records = $attendanceService
            ->queryByUser($request->user(), $dateFrom, $dateTo)
            ->when(
                $request->filled('action'),
                fn ($query) => $query->where('action', $request->string('action')->toString()),
            )
            ->when(
                $request->filled('status'),
                fn ($query) => $query->where('status', $request->string('status')->toString()),
            );

        return ApiListResponse::fromQuery(
            $request,
            $records,
            fn (AttendanceRecord $record) => FieldApiData::attendanceRecord($record),
        );
    }

    public function checkIn(
        StoreAttendanceCheckInRequest $request,
        AttendanceService $attendanceService,
    ): JsonResponse {
        $record = $attendanceService->create($request->user(), $request->validated(), 'checkIn');

        return response()->json([
            'data' => FieldApiData::attendanceRecord($record),
        ], 201);
    }

    public function checkOut(
        StoreAttendanceCheckOutRequest $request,
        AttendanceService $attendanceService,
    ): JsonResponse {
        $record = $attendanceService->create($request->user(), $request->validated(), 'checkOut');

        return response()->json([
            'data' => FieldApiData::attendanceRecord($record),
        ], 201);
    }

    public function dailySummary(
        Request $request,
        AttendanceSummaryService $attendanceSummaryService,
    ): JsonResponse {
        $date = $request->filled('date')
            ? Carbon::parse($request->string('date')->toString())
            : now();

        return response()->json([
            'data' => $attendanceSummaryService->summarize(
                $request->user(),
                $date->copy()->startOfDay(),
            ),
        ]);
    }

    public function destroy(Request $request, AttendanceService $attendanceService): JsonResponse
    {
        $attendanceService->clearByUser($request->user());

        return response()->json([
            'data' => ['cleared' => true],
        ]);
    }

    public function outsideOfficeStart(
        StoreOutsideOfficeAttendanceStartRequest $request,
        AttendanceService $attendanceService,
    ): JsonResponse {
        $record = $attendanceService->createOutsideOfficeStart(
            $request->user(),
            $request->validated(),
        );

        return response()->json([
            'data' => FieldApiData::attendanceRecord($record),
        ], 201);
    }

    public function outsideOfficeFinish(
        StoreOutsideOfficeAttendanceFinishRequest $request,
        AttendanceService $attendanceService,
    ): JsonResponse {
        $record = $attendanceService->createOutsideOfficeFinish(
            $request->user(),
            $request->validated(),
        );

        return response()->json([
            'data' => FieldApiData::attendanceRecord($record),
        ], 201);
    }
}
