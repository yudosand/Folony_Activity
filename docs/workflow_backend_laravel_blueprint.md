# Workflow Backend Laravel Blueprint

Dokumen ini menurunkan [workflow_backend_implementation.md](/C:/Users/user/Desktop/FolonyActivity/docs/workflow_backend_implementation.md) ke blueprint teknis yang siap dipakai saat membangun backend Laravel untuk modul `Leave`, `WFA`, dan `Approval`.

## Tujuan Dokumen

- memberi struktur folder backend yang jelas
- memberi draft migration per tabel
- memberi pembagian tanggung jawab controller, service, dan repository
- memberi contoh alur transaksi untuk approval
- mengurangi rework saat mobile mulai diarahkan ke backend live

## Asumsi Teknologi

- framework: `Laravel 12` atau setara yang sudah mendukung typed request dan policy modern
- auth mobile: `Sanctum` token API
- database: `MySQL 8+`
- storage file: local/public dulu, lalu bisa pindah ke S3-compatible storage
- timezone backend: `Asia/Jakarta`

## Struktur Folder yang Disarankan

```text
app/
  Http/
    Controllers/Api/
      MeController.php
      LeaveController.php
      WfaController.php
      ApprovalController.php
    Requests/
      Leave/
        StoreLeaveRequest.php
        UpdateLeaveStatusRequest.php
      Wfa/
        StoreWfaRequest.php
        UpdateWfaStatusRequest.php
        StoreWfaTaskUpdateRequest.php
      Approval/
        ApproveApprovalRequest.php
        RejectApprovalRequest.php
  Models/
    User.php
    LeaveRequest.php
    WfaRequest.php
    ApprovalStep.php
    WfaTaskUpdate.php
    Attachment.php
  Policies/
    LeaveRequestPolicy.php
    WfaRequestPolicy.php
    ApprovalStepPolicy.php
  Repositories/
    Contracts/
      LeaveRepositoryInterface.php
      WfaRepositoryInterface.php
      ApprovalRepositoryInterface.php
    Eloquent/
      LeaveRepository.php
      WfaRepository.php
      ApprovalRepository.php
  Services/
    ApprovalFlowService.php
    LeaveService.php
    WfaService.php
    AttachmentService.php
  Support/
    Workflow/
      ApprovalChainFactory.php
      WorkflowStatus.php
      WorkflowModule.php
      UserRole.php
```

## Route Map

```php
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/me', MeController::class);

    Route::get('/leave', [LeaveController::class, 'index']);
    Route::post('/leave', [LeaveController::class, 'store']);
    Route::patch('/leave/{leaveRequest}/status', [LeaveController::class, 'updateStatus']);

    Route::get('/wfa', [WfaController::class, 'index']);
    Route::post('/wfa', [WfaController::class, 'store']);
    Route::patch('/wfa/{wfaRequest}/status', [WfaController::class, 'updateStatus']);
    Route::post('/wfa/{wfaRequest}/task-updates', [WfaController::class, 'storeTaskUpdate']);

    Route::get('/approvals/inbox', [ApprovalController::class, 'index']);
    Route::post('/approvals/{approvalStep}/approve', [ApprovalController::class, 'approve']);
    Route::post('/approvals/{approvalStep}/reject', [ApprovalController::class, 'reject']);
});
```

## Enum dan Konstanta yang Disarankan

### `UserRole`

- `staff`
- `spv`
- `areaManager`
- `management`
- `fgg`

### `WorkflowModule`

- `leave`
- `wfa`

### `WorkflowStatus`

Untuk `leave`:

- `pending`
- `approved`
- `rejected`
- `cancelled`

Untuk `wfa`:

- `pending`
- `approved`
- `active`
- `completed`
- `rejected`

### `ApprovalStepStatus`

- `pending`
- `approved`
- `rejected`
- `skipped`

## Draft Migration

### `users`

```php
Schema::create('users', function (Blueprint $table) {
    $table->uuid('id')->primary();
    $table->string('full_name');
    $table->string('phone_number')->nullable();
    $table->string('area_name')->nullable();
    $table->string('role', 32);
    $table->uuid('spv_id')->nullable();
    $table->uuid('management_id')->nullable();
    $table->boolean('is_active')->default(true);
    $table->timestamp('last_login_at')->nullable();
    $table->rememberToken();
    $table->timestamps();

    $table->index('role');
    $table->index('spv_id');
    $table->index('management_id');
});
```

### `leave_requests`

```php
Schema::create('leave_requests', function (Blueprint $table) {
    $table->uuid('id')->primary();
    $table->uuid('requester_id');
    $table->string('requester_name_snapshot');
    $table->string('requester_role_snapshot', 32);
    $table->string('category', 32);
    $table->string('compensation_option', 32);
    $table->dateTime('start_at');
    $table->dateTime('end_at')->nullable();
    $table->decimal('duration_value', 8, 2);
    $table->text('reason');
    $table->string('delegate_to')->nullable();
    $table->string('status', 32)->default('pending');
    $table->text('note')->nullable();
    $table->dateTime('submitted_at');
    $table->timestamps();

    $table->index('requester_id');
    $table->index('status');
    $table->index('submitted_at');
});
```

### `wfa_requests`

```php
Schema::create('wfa_requests', function (Blueprint $table) {
    $table->uuid('id')->primary();
    $table->uuid('requester_id');
    $table->string('requester_name_snapshot');
    $table->string('requester_role_snapshot', 32);
    $table->string('mode', 32);
    $table->string('compensation_mode', 32)->nullable();
    $table->date('work_date');
    $table->string('start_time', 5);
    $table->string('end_time', 5);
    $table->string('location_label');
    $table->text('reason');
    $table->text('initial_task');
    $table->string('status', 32)->default('pending');
    $table->text('note')->nullable();
    $table->dateTime('submitted_at');
    $table->dateTime('actual_start_at')->nullable();
    $table->dateTime('actual_end_at')->nullable();
    $table->timestamps();

    $table->index('requester_id');
    $table->index('status');
    $table->index('work_date');
    $table->index('submitted_at');
});
```

### `approval_steps`

```php
Schema::create('approval_steps', function (Blueprint $table) {
    $table->uuid('id')->primary();
    $table->string('module', 32);
    $table->uuid('reference_id');
    $table->unsignedInteger('sequence');
    $table->string('approver_role', 32);
    $table->uuid('approver_id');
    $table->string('approver_name_snapshot');
    $table->string('status', 32)->default('pending');
    $table->text('note')->nullable();
    $table->dateTime('acted_at')->nullable();
    $table->timestamps();

    $table->index(['module', 'reference_id']);
    $table->index('approver_id');
    $table->index('status');
    $table->unique(['module', 'reference_id', 'sequence']);
});
```

### `wfa_task_updates`

```php
Schema::create('wfa_task_updates', function (Blueprint $table) {
    $table->uuid('id')->primary();
    $table->uuid('wfa_request_id');
    $table->uuid('created_by');
    $table->text('message');
    $table->timestamps();

    $table->index('wfa_request_id');
    $table->index('created_at');
});
```

### `attachments`

```php
Schema::create('attachments', function (Blueprint $table) {
    $table->uuid('id')->primary();
    $table->string('module', 32);
    $table->uuid('reference_id');
    $table->string('file_name');
    $table->string('mime_type', 100);
    $table->string('url');
    $table->string('thumbnail_url')->nullable();
    $table->unsignedBigInteger('size_in_bytes')->nullable();
    $table->timestamps();

    $table->index(['module', 'reference_id']);
});
```

## Relasi Model

### `User`

- `spv()`
- `management()`
- `leaveRequests()`
- `wfaRequests()`

### `LeaveRequest`

- `requester()`
- `approvalSteps()`

### `WfaRequest`

- `requester()`
- `approvalSteps()`
- `taskUpdates()`

### `WfaTaskUpdate`

- `wfaRequest()`
- `attachments()`

### `ApprovalStep`

- relasi polymorphic manual via `module + reference_id`, atau
- buat wrapper service dan jangan paksakan morph dulu bila ingin simpel

## Tanggung Jawab Layer

### Controller

Tugas:

- menerima request
- memanggil Form Request untuk validasi
- delegasi ke service
- mengembalikan API resource atau array `data`

Controller jangan:

- membentuk approval chain
- menulis query lintas tabel kompleks
- berisi logika status workflow

### Service

Tugas:

- logika bisnis inti
- transaksi database
- pembentukan approval chain
- menjaga konsistensi perubahan status source record dan approval step

Service utama:

- `LeaveService`
- `WfaService`
- `ApprovalFlowService`

### Repository

Tugas:

- query database
- eager loading relasi
- isolasi detail Eloquent dari service

## Blueprint Service

### `ApprovalChainFactory`

Tugas:

- menerima role requester
- mengembalikan array step approval

Rule:

- `staff` -> `spv`, lalu `management`
- `spv` -> `management`
- `areaManager` -> `management`
- `management` -> kosong atau auto-approved, sesuai keputusan final

Contoh output:

```php
[
    ['sequence' => 1, 'approver_role' => 'spv', 'approver_id' => '...'],
    ['sequence' => 2, 'approver_role' => 'management', 'approver_id' => '...'],
]
```

### `LeaveService::create(array $payload, User $actor)`

Langkah:

1. validasi actor boleh membuat request
2. buat record `leave_requests`
3. generate approval chain
4. simpan `approval_steps`
5. load relasi lengkap
6. return record

Wajib pakai transaction:

```php
DB::transaction(function () use ($payload, $actor) {
    // create leave request
    // create approval steps
});
```

### `WfaService::create(array $payload, User $actor)`

Langkah:

1. validasi role dan mode
2. simpan `wfa_requests`
3. bentuk `approval_steps`
4. return record lengkap

Tambahan rule:

- jika `mode = overtime`, `compensation_mode` wajib ada

### `WfaService::updateStatus(WfaRequest $wfa, array $payload, User $actor)`

Langkah:

1. cek policy
2. validasi transisi status
3. isi `actual_start_at` atau `actual_end_at` bila perlu
4. update record
5. return record terbaru

Transisi yang boleh:

- `approved -> active`
- `active -> completed`
- `pending -> rejected`
- `approved -> rejected`

Transisi yang jangan diizinkan:

- `pending -> active`
- `completed -> active`
- `rejected -> active`

### `WfaService::createTaskUpdate(WfaRequest $wfa, array $payload, User $actor)`

Langkah:

1. cek status WFA valid
2. simpan `wfa_task_updates`
3. simpan attachment jika ada
4. return update dengan relasi attachment

### `ApprovalFlowService::approve(ApprovalStep $step, User $actor, ?string $note)`

Langkah:

1. cek step masih `pending`
2. cek approver sesuai actor
3. tandai step `approved`
4. isi `note` dan `acted_at`
5. cek ada next step atau tidak
6. jika ada next step, source record tetap `pending`
7. jika tidak ada next step, source record jadi `approved`
8. return source record lengkap

### `ApprovalFlowService::reject(ApprovalStep $step, User $actor, string $note)`

Langkah:

1. cek step masih `pending`
2. cek approver sesuai actor
3. tandai step `rejected`
4. isi `note` dan `acted_at`
5. ubah source record jadi `rejected`
6. pastikan step berikutnya tidak lagi aktif
7. return source record lengkap

## Form Request yang Disarankan

### `StoreLeaveRequest`

Rules minimum:

```php
[
    'requester_id' => ['required', 'uuid'],
    'requester_name' => ['required', 'string'],
    'requester_role' => ['required', 'string'],
    'category' => ['required', Rule::in(['cuti', 'sakit', 'izinPerJam', 'izinPerHari'])],
    'compensation_option' => ['required', Rule::in(['potongSaldoCuti', 'potongGaji', 'tidakPotongGaji'])],
    'start_at' => ['required', 'date'],
    'end_at' => ['nullable', 'date'],
    'duration_value' => ['required', 'numeric', 'gt:0'],
    'reason' => ['required', 'string'],
    'delegate_to' => ['nullable', 'string'],
]
```

### `StoreWfaRequest`

Rules minimum:

```php
[
    'requester_id' => ['required', 'uuid'],
    'mode' => ['required', Rule::in(['regular', 'overtime'])],
    'compensation_mode' => ['nullable', Rule::in(['shiftMundur', 'klaimLembur', 'reviewHr'])],
    'work_date' => ['required', 'date'],
    'start_time' => ['required', 'date_format:H:i'],
    'end_time' => ['required', 'date_format:H:i'],
    'location_label' => ['required', 'string'],
    'reason' => ['required', 'string'],
    'initial_task' => ['required', 'string'],
]
```

After hook:

- jika `mode === overtime` dan `compensation_mode` kosong, return validation error

### `UpdateWfaStatusRequest`

Rules minimum:

```php
[
    'status' => ['required', Rule::in(['approved', 'active', 'completed', 'rejected'])],
    'actual_start_at' => ['nullable', 'date'],
    'actual_end_at' => ['nullable', 'date'],
    'note' => ['nullable', 'string'],
]
```

### `StoreWfaTaskUpdateRequest`

Rules minimum:

```php
[
    'message' => ['required', 'string'],
    'attachments' => ['nullable', 'array'],
    'attachments.*.file_name' => ['required_with:attachments', 'string'],
    'attachments.*.mime_type' => ['required_with:attachments', 'string'],
    'attachments.*.url' => ['required_with:attachments', 'url'],
]
```

### `RejectApprovalRequest`

Rules minimum:

```php
[
    'approver_id' => ['required', 'uuid'],
    'approver_name' => ['required', 'string'],
    'note' => ['required', 'string'],
]
```

## API Resource Shape

### `LeaveRequestResource`

Wajib mengembalikan:

- `id`
- `requester_id`
- `requester_name`
- `requester_role`
- `category`
- `compensation_option`
- `start_at`
- `end_at`
- `duration_value`
- `reason`
- `delegate_to`
- `status`
- `approval_steps`
- `submitted_at`
- `note`

### `WfaRequestResource`

Wajib mengembalikan:

- semua field utama WFA
- `approval_steps`
- `task_updates`

### `ApprovalInboxItemResource`

Wajib mengembalikan:

- `id`
- `module`
- `reference_id`
- `requester_id`
- `requester_name`
- `requester_role`
- `title`
- `summary`
- `status`
- `submitted_at`
- `approval_steps`

## Query Repository yang Disarankan

### `LeaveRepository`

Method minimum:

- `listForUser(string $userId, array $filters = [])`
- `findForWorkflow(string $id)`
- `updateStatus(LeaveRequest $leave, string $status, ?string $note)`

Eager load:

- `approvalSteps`

### `WfaRepository`

Method minimum:

- `listForUser(string $userId, array $filters = [])`
- `findForWorkflow(string $id)`
- `updateStatus(WfaRequest $wfa, string $status, array $payload)`
- `createTaskUpdate(WfaRequest $wfa, array $payload)`

Eager load:

- `approvalSteps`
- `taskUpdates.attachments`

### `ApprovalRepository`

Method minimum:

- `inboxForApprover(string $approverId, ?string $module = null)`
- `findPendingStep(string $id)`
- `findSourceRecord(ApprovalStep $step)`

## Authorization Policy

### `LeaveRequestPolicy`

- requester boleh lihat request miliknya
- approver boleh lihat request yang step-nya milik dia
- admin/management boleh lihat lebih luas sesuai policy organisasi

### `WfaRequestPolicy`

- requester boleh ubah ke `active/completed` hanya jika record miliknya dan status sebelumnya valid
- approver tidak otomatis boleh mengubah sesi WFA, kecuali memang kebijakan bisnis mengizinkan

### `ApprovalStepPolicy`

- actor harus sama dengan `approver_id`
- step harus `pending`

## Seed Data Minimal untuk QA

User yang sebaiknya ada:

- `Staff A`
- `SPV A`
- `Area Manager A`
- `Management A`

Data yang sebaiknya disiapkan:

- 1 leave pending milik staff
- 1 leave pending milik spv
- 1 WFA regular pending
- 1 WFA overtime approved
- 1 WFA completed dengan task update dan attachment

## Skenario Uji End-to-End

### Leave Staff

1. staff login
2. submit leave
3. `GET /leave` menampilkan record pending
4. spv login
5. `GET /approvals/inbox?module=leave` menampilkan item tadi
6. spv approve
7. management login
8. inbox management menampilkan item yang sama
9. management reject atau approve
10. staff refresh `GET /leave` dan melihat status final plus note

### WFA Overtime

1. staff submit WFA overtime
2. spv approve
3. management approve
4. staff ubah status jadi `active`
5. staff tambah task update dengan attachment
6. staff ubah status jadi `completed`
7. mobile membaca lagi detail WFA dan semua data tetap lengkap

## Urutan Kerja Implementasi yang Paling Aman

1. buat migration dan model
2. buat enum/support constants
3. buat `GET /me`
4. buat `POST /leave` dan `GET /leave`
5. buat `POST /wfa` dan `GET /wfa`
6. buat `GET /approvals/inbox`
7. buat `approve` dan `reject`
8. buat `PATCH /wfa/{id}/status`
9. buat `POST /wfa/{id}/task-updates`
10. terakhir `PATCH /leave/{id}/status` sebagai jalur override/admin

## Catatan Integrasi Dengan Mobile Saat Ini

- mobile bisa diaktifkan ke remote workflow lewat:

```powershell
flutter run `
  --dart-define=HEX_ENABLE_REMOTE_WORKFLOW=true `
  --dart-define=HEX_BACKEND_BASE_URL=http://127.0.0.1:8000/api
```

- repository mobile saat ini sudah `remote preferred with local fallback`
- artinya backend bisa di-rollout bertahap per route tanpa mematikan demo seluruh app sekaligus

## Next Step Setelah Backend Repo Dibuat

Saat repo Laravel sudah ada, langkah berikut yang paling efektif:

1. scaffold migration dan model
2. implement `GET /me`
3. implement `leave`
4. implement `wfa`
5. implement `approval inbox`
6. baru sambungkan mobile ke server lokal untuk smoke test
