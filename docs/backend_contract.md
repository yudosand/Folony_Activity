# Backend Contract Final Draft

Dokumen ini merangkum kontrak data yang sekarang sudah dipakai oleh layer repository mock dan siap dijadikan acuan integrasi backend bertahap.

## Modul Inti

- `AppUser`: data user login, role, area, dan relasi approval.
- `AttendanceRecord`: absensi check-in/check-out dengan face verification, lokasi audit, dan dasar evaluasi jam kerja.
- `AttendanceDailySummary`: ringkasan hasil rule engine absensi untuk satu hari kerja.
- `LeaveRequestRecord`: pengajuan cuti/izin dengan delegasi, kompensasi, dan histori approval.
- `WfaRequestRecord`: pengajuan WFA reguler/overtime dengan task updates, kompensasi, dan histori approval.
- `NetworkProfile`: UKM atau Mitra yang dimiliki user lapangan.
- `ApprovalItem`: inbox approval generik lintas modul.

## Standar Kerja Saat Ini

- Jam masuk standar: `08:30`
- Jam pulang standar: `17:00`
- Rule engine mobile saat ini menghasilkan status:
  - `tepat_waktu`
  - `terlambat`
  - `pulang_cepat`
  - `lembur`
- Overtime bisa datang dari:
  - `check_out` di atas `17:00`
  - `WFA overtime` yang sudah disetujui atau selesai
- Jika overtime memakai kompensasi `shiftMundur`, mobile akan menyiapkan rekomendasi jam masuk esok hari.

## Kontrak JSON Utama

### `AppUser`

```json
{
  "id": "usr_001",
  "full_name": "Nadia Staff",
  "phone_number": "081234567890",
  "area_name": "Head Office",
  "role": "staff",
  "spv_id": "usr_spv_001",
  "spv_name": "Dimas SPV",
  "management_id": "usr_mgt_001",
  "management_name": "Sinta Management",
  "is_active": true
}
```

### `AttendanceRecord`

```json
{
  "id": "att_001",
  "user_id": "usr_001",
  "work_date": "2026-04-24T00:00:00.000Z",
  "action": "checkIn",
  "status": "success",
  "recorded_at": "2026-04-24T01:32:00.000Z",
  "location": {
    "latitude": -6.31111,
    "longitude": 106.80123,
    "recorded_at": "2026-04-24T01:32:00.000Z",
    "address_label": "Jagakarsa",
    "radius_meters": 150,
    "within_radius": true
  },
  "verification": {
    "verified_at": "2026-04-24T01:31:58.000Z",
    "match_score": 0.96,
    "liveness_score": 0.94,
    "capture": {
      "id": "file_001",
      "file_name": "face-check-in.jpg",
      "mime_type": "image/jpeg",
      "url": "https://cdn.example.com/face-check-in.jpg"
    }
  },
  "note": "Absensi masuk otomatis setelah wajah terverifikasi dan lokasi tercatat."
}
```

### `AttendanceDailySummary`

```json
{
  "user_id": "usr_001",
  "work_date": "2026-04-24",
  "standard_start_time": "08:30",
  "standard_end_time": "17:00",
  "check_in_at": "2026-04-24T01:30:00.000Z",
  "check_out_at": "2026-04-24T08:00:00.000Z",
  "arrival_status": "tepat_waktu",
  "departure_status": "lembur",
  "work_duration_minutes": 390,
  "late_duration_minutes": 0,
  "early_leave_minutes": 0,
  "overtime_minutes": 90,
  "wfa_regular_context": true,
  "wfa_overtime_context": true,
  "next_start_recommendation": "10:00"
}
```

### `LeaveRequestRecord`

```json
{
  "id": "leave_001",
  "requester_id": "usr_001",
  "requester_name": "Nadia Staff",
  "requester_role": "staff",
  "category": "izinPerHari",
  "compensation_option": "tidakPotongGaji",
  "start_at": "2026-04-24T00:00:00.000Z",
  "end_at": "2026-04-25T00:00:00.000Z",
  "duration_value": 2,
  "reason": "Keperluan keluarga",
  "delegate_to": "Dian Pratama",
  "status": "pending",
  "approval_steps": [
    {
      "sequence": 1,
      "approver_role": "spv",
      "status": "approved",
      "approver_id": "usr_spv_001",
      "approver_name": "Dimas SPV",
      "note": "Lanjutkan ke management.",
      "acted_at": "2026-04-24T03:00:00.000Z"
    },
    {
      "sequence": 2,
      "approver_role": "management",
      "status": "pending",
      "approver_id": "usr_mgt_001",
      "approver_name": "Sinta Management"
    }
  ],
  "submitted_at": "2026-04-24T02:00:00.000Z",
  "note": "Pengajuan staff menunggu approval management."
}
```

### `WfaRequestRecord`

```json
{
  "id": "wfa_001",
  "requester_id": "usr_001",
  "requester_name": "Nadia Staff",
  "requester_role": "staff",
  "mode": "overtime",
  "compensation_mode": "shiftMundur",
  "work_date": "2026-04-24T00:00:00.000Z",
  "start_time": "19:30",
  "end_time": "21:00",
  "location_label": "Online meeting dari rumah",
  "reason": "Meeting malam dengan mitra regional",
  "initial_task": "Presentasi progres dan tindak lanjut hasil meeting malam",
  "status": "pending",
  "approval_steps": [
    {
      "sequence": 1,
      "approver_role": "spv",
      "status": "approved",
      "approver_id": "usr_spv_001",
      "approver_name": "Dimas SPV",
      "note": "Boleh lanjut ke management.",
      "acted_at": "2026-04-24T10:00:00.000Z"
    },
    {
      "sequence": 2,
      "approver_role": "management",
      "status": "pending",
      "approver_id": "usr_mgt_001",
      "approver_name": "Sinta Management"
    }
  ],
  "task_updates": [
    {
      "id": "wfa_upd_001",
      "message": "Meeting selesai, tindak lanjut sudah dicatat.",
      "created_at": "2026-04-24T14:05:00.000Z",
      "attachments": [
        {
          "id": "file_002",
          "file_name": "meeting-night.jpg",
          "mime_type": "image/jpeg",
          "url": "https://cdn.example.com/meeting-night.jpg"
        }
      ]
    }
  ],
  "submitted_at": "2026-04-24T09:00:00.000Z",
  "actual_start_at": "2026-04-24T12:30:00.000Z",
  "actual_end_at": "2026-04-24T14:00:00.000Z",
  "note": "Jika disetujui, pengajuan ini akan ikut tercatat untuk kompensasi esok hari."
}
```

### `NetworkProfile`

```json
{
  "id": "net_001",
  "owner_id": "usr_fgg_001",
  "owner_name": "Bima FGG",
  "owner_role": "fgg",
  "type": "ukm",
  "name": "UKM Toko Harapan",
  "address": "Pasar Minggu",
  "business_type": "Sembako",
  "phone_number": "081234567890",
  "status": "followUp",
  "created_at": "2026-04-24T03:00:00.000Z",
  "note": "Perlu follow-up stok",
  "follow_ups": [
    {
      "id": "fu_001",
      "title": "Kunjungan awal",
      "note": "Data dasar UKM sudah lengkap",
      "actor_id": "usr_fgg_001",
      "actor_name": "Bima FGG",
      "created_at": "2026-04-24T03:20:00.000Z"
    }
  ]
}
```

## Endpoint Minimum yang Disarankan

### Auth & User

- `POST /auth/login`
- `GET /me`

### Attendance

- `GET /attendance?user_id=usr_001&date=2026-04-24`
- `POST /attendance/check-in`
- `POST /attendance/check-out`
- `GET /attendance/daily-summary?user_id=usr_001&date=2026-04-24`

### Leave

- `GET /leave?user_id=usr_001`
- `POST /leave`
- `PATCH /leave/{id}/status`

### WFA

- `GET /wfa?user_id=usr_001`
- `POST /wfa`
- `PATCH /wfa/{id}/status`
- `POST /wfa/{id}/task-updates`

### Approval

- `GET /approvals/inbox?approver_id=usr_mgt_001&module=wfa`
- `POST /approvals/{id}/approve`
- `POST /approvals/{id}/reject`

### Network

- `GET /network?owner_id=usr_fgg_001`
- `POST /network`
- `PATCH /network/{id}`
- `DELETE /network/{id}`
- `POST /network/{id}/follow-ups`

## Aktivasi di Mobile

Saat backend `Approval + Leave + WFA` sudah siap, mobile bisa diaktifkan ke mode remote dengan `dart-define` berikut:

```powershell
flutter run `
  --dart-define=HEX_ENABLE_REMOTE_WORKFLOW=true `
  --dart-define=HEX_BACKEND_BASE_URL=http://127.0.0.1:8000/api
```

Catatan:

- Jika mode remote aktif, seed demo workflow lokal tidak dijalankan.
- Repository workflow memakai mode `remote preferred with local fallback`.
- Endpoint `leave`, `wfa`, dan `approval` akan dipanggil lebih dulu ke backend; fallback mock dipakai jika request gagal.

## Catatan Integrasi

- Mobile sekarang sudah memakai repository untuk `network`, `leave`, `wfa`, `approval`, dan `attendance`.
- `attendance`, `leave`, `wfa`, dan `approval` sudah satu source of truth, jadi perubahan status approval harus mengubah record asal.
- Histori approval perlu selalu mengembalikan:
  - `status`
  - `note`
  - `acted_at`
  - `approver_id`
  - `approver_name`
- Untuk overtime yang berdampak ke kompensasi, backend sebaiknya menyiapkan `AttendanceDailySummary` agar mobile tidak perlu menghitung ulang semua rule dari nol saat data sudah live.
