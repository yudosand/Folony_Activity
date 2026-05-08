# Workflow Backend Implementation Plan

Dokumen ini adalah panduan eksekusi backend untuk modul `Approval`, `Leave / Cuti / Izin`, dan `WFA`. Fokusnya bukan hanya kontrak JSON, tetapi urutan implementasi route, tabel minimum, validasi inti, dan dampaknya ke layar mobile yang sudah ada.

Jika tim backend memakai Laravel, lanjutkan implementasi teknisnya dengan [workflow_backend_laravel_blueprint.md](/C:/Users/user/Desktop/FolonyActivity/docs/workflow_backend_laravel_blueprint.md).

## Ruang Lingkup Tahap Ini

- `GET /me`
- `GET /leave`
- `POST /leave`
- `PATCH /leave/{id}/status`
- `GET /wfa`
- `POST /wfa`
- `PATCH /wfa/{id}/status`
- `POST /wfa/{id}/task-updates`
- `GET /approvals/inbox`
- `POST /approvals/{id}/approve`
- `POST /approvals/{id}/reject`

Modul `Attendance` dan `Network` belum wajib live di tahap ini, tetapi struktur responsnya sudah harus tetap konsisten dengan [backend_contract.md](/C:/Users/user/Desktop/FolonyActivity/docs/backend_contract.md) agar fase berikutnya mulus.

## Tujuan Backend Tahap Ini

- Mobile tidak lagi bergantung ke seed demo untuk `Leave`, `WFA`, dan `Approval`.
- Approval chain antar role benar-benar hidup dari backend.
- Keputusan approver mengubah source record asal, bukan hanya inbox approval.
- Riwayat step approval, note keputusan, dan waktu aksi selalu bisa dibaca kembali di mobile.
- Status `WFA` bisa bergerak dari `pending -> approved -> active -> completed` atau `rejected`.

## Ketergantungan Mobile Saat Ini

### Halaman yang memakai data ini

- `Leave / Cuti / Izin`
  - [leave_page.dart](/C:/Users/user/Desktop/FolonyActivity/lib/features/leave/presentation/leave_page.dart)
- `WFA`
  - [wfh_page.dart](/C:/Users/user/Desktop/FolonyActivity/lib/features/wfh/presentation/wfh_page.dart)
- `Approval Center`
  - [leave_approval_page.dart](/C:/Users/user/Desktop/FolonyActivity/lib/features/leave/presentation/leave_approval_page.dart)
- integrasi repository
  - [app.dart](/C:/Users/user/Desktop/FolonyActivity/lib/app/app.dart)
  - [app_controller.dart](/C:/Users/user/Desktop/FolonyActivity/lib/app/app_controller.dart)

### Aturan penting dari mobile yang backend harus ikuti

- `staff`:
  - approval chain: `SPV -> Management`
- `spv`:
  - approval chain: `Management`
- `areaManager`:
  - approval chain: `Management`
- `management`:
  - boleh final tanpa step lanjutan
- `WFA overtime`:
  - wajib menyimpan `compensation_mode`
- `WFA task update`:
  - bisa membawa attachment foto kamera atau galeri

## Urutan Implementasi Paling Efisien

### Batch 1: Fondasi user dan source record

- `GET /me`
- `GET /leave`
- `POST /leave`
- `GET /wfa`
- `POST /wfa`

Hasil yang diharapkan:

- requester bisa submit dan membaca kembali request miliknya
- approver chain sudah dibentuk backend saat record dibuat
- mobile tidak perlu menyusun approval step dari nol

### Batch 2: Approval engine

- `GET /approvals/inbox`
- `POST /approvals/{id}/approve`
- `POST /approvals/{id}/reject`

Hasil yang diharapkan:

- inbox approval hidup
- keputusan approver mengubah `approval_steps`
- status record asal ikut berubah

### Batch 3: Lifecycle WFA

- `PATCH /wfa/{id}/status`
- `POST /wfa/{id}/task-updates`
- `PATCH /leave/{id}/status`

Hasil yang diharapkan:

- sesi WFA bisa bergerak dari approved ke active ke completed
- update task tersimpan dan kembali tampil di detail mobile
- ada jalur override status source record jika diperlukan

## Skema Tabel Minimum

### `users`

Kolom minimum:

- `id`
- `full_name`
- `phone_number`
- `area_name`
- `role`
- `spv_id`
- `management_id`
- `is_active`
- `created_at`
- `updated_at`

Index minimum:

- index `role`
- index `spv_id`
- index `management_id`

### `leave_requests`

Kolom minimum:

- `id`
- `requester_id`
- `requester_name_snapshot`
- `requester_role_snapshot`
- `category`
- `compensation_option`
- `start_at`
- `end_at`
- `duration_value`
- `reason`
- `delegate_to`
- `status`
- `note`
- `submitted_at`
- `created_at`
- `updated_at`

Index minimum:

- index `requester_id`
- index `status`
- index `submitted_at`

### `wfa_requests`

Kolom minimum:

- `id`
- `requester_id`
- `requester_name_snapshot`
- `requester_role_snapshot`
- `mode`
- `compensation_mode`
- `work_date`
- `start_time`
- `end_time`
- `location_label`
- `reason`
- `initial_task`
- `status`
- `note`
- `submitted_at`
- `actual_start_at`
- `actual_end_at`
- `created_at`
- `updated_at`

Index minimum:

- index `requester_id`
- index `status`
- index `work_date`
- index `submitted_at`

### `approval_steps`

Kolom minimum:

- `id`
- `module`
- `reference_id`
- `sequence`
- `approver_role`
- `approver_id`
- `approver_name_snapshot`
- `status`
- `note`
- `acted_at`
- `created_at`
- `updated_at`

Index minimum:

- composite index `module, reference_id`
- index `approver_id`
- index `status`
- unique `module + reference_id + sequence`

### `wfa_task_updates`

Kolom minimum:

- `id`
- `wfa_request_id`
- `message`
- `created_by`
- `created_at`
- `updated_at`

Index minimum:

- index `wfa_request_id`
- index `created_at`

### `attachments`

Kolom minimum:

- `id`
- `module`
- `reference_id`
- `file_name`
- `mime_type`
- `url`
- `thumbnail_url`
- `size_in_bytes`
- `created_at`
- `updated_at`

Index minimum:

- composite index `module, reference_id`

## Bentuk Respons yang Disarankan

### Pola umum

- sukses tunggal:

```json
{
  "data": {}
}
```

- sukses daftar:

```json
{
  "data": []
}
```

- error validasi:

```json
{
  "message": "Validation failed.",
  "errors": {
    "start_at": ["Tanggal mulai wajib diisi."]
  }
}
```

### Catatan kompatibilitas

Repository mobile saat ini menerima:

- respons array langsung
- respons object langsung
- respons berbentuk `{ "data": ... }`

Tetap disarankan backend memakai wrapper `data` agar konsisten.

## Detail Route Per Endpoint

### `GET /me`

Tujuan:

- memberi identitas user login, role, area, dan approver chain

Dipakai oleh mobile:

- pembentukan sesi user
- pengisian otomatis approver `SPV` dan `Management`
- kontrol menu berdasar role

Query:

- tidak ada query khusus
- user diambil dari token aktif

Response minimum:

```json
{
  "data": {
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
}
```

Validasi bisnis:

- user harus aktif
- `spv_id` boleh null untuk `management`
- `management_id` boleh null hanya jika memang role tidak butuh approver lanjutan

### `GET /leave`

Tujuan:

- membaca semua pengajuan leave requester aktif

Dipakai oleh mobile:

- daftar riwayat di halaman `Cuti / Izin`
- detail request beserta alur approval

Query minimum:

- `user_id`

Query opsional:

- `status`
- `page`
- `per_page`

Rule query:

- jika bukan admin, `user_id` harus cocok dengan user pada token atau role yang diizinkan melihat data bawahan

Response minimum:

- array `LeaveRequestRecord`
- `approval_steps` harus sudah terurut `sequence ASC`

Validasi bisnis:

- hasil harus memuat snapshot requester
- approver note, acted time, dan status step tidak boleh hilang

### `POST /leave`

Tujuan:

- membuat pengajuan `cuti`, `sakit`, `izin per jam`, atau `izin per hari`

Dipakai oleh mobile:

- tombol submit di halaman `Cuti / Izin`

Body minimum:

```json
{
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
  "note": "Pengajuan dibuat dari mobile"
}
```

Validasi minimum:

- `requester_id` wajib ada
- `category` wajib salah satu:
  - `cuti`
  - `sakit`
  - `izinPerJam`
  - `izinPerHari`
- `compensation_option` wajib salah satu:
  - `potongSaldoCuti`
  - `potongGaji`
  - `tidakPotongGaji`
- `start_at` wajib
- `end_at` wajib untuk kategori hari
- `duration_value` wajib > 0
- `reason` wajib

Rule backend:

- backend menyusun `approval_steps` berdasar role requester
- record baru selalu dimulai dari `status = pending`
- `submitted_at` diisi backend
- snapshot approver name diambil dari tabel `users`

Response minimum:

- satu `LeaveRequestRecord` lengkap dengan `approval_steps`

### `PATCH /leave/{id}/status`

Tujuan:

- jalur override atau sinkronisasi status source record

Dipakai oleh mobile:

- repository remote `leave`
- cadangan bila status source record perlu disesuaikan di luar route approval

Body minimum:

```json
{
  "status": "approved",
  "note": "Sinkronisasi status dari approval final."
}
```

Validasi minimum:

- `status` wajib salah satu:
  - `pending`
  - `approved`
  - `rejected`
  - `cancelled`

Rule backend:

- jika status final dipaksa berubah, `approval_steps` harus tetap konsisten
- sebaiknya route ini dibatasi untuk sistem/admin, bukan flow utama approver biasa

### `GET /wfa`

Tujuan:

- membaca semua pengajuan WFA milik requester

Dipakai oleh mobile:

- riwayat WFA
- detail WFA
- sinkronisasi konteks overtime ke absensi

Query minimum:

- `user_id`

Query opsional:

- `status`
- `mode`
- `page`
- `per_page`

Response minimum:

- array `WfaRequestRecord`
- wajib menyertakan:
  - `approval_steps`
  - `task_updates`

Validasi bisnis:

- `task_updates` harus urut dari lama ke baru
- attachment pada task update harus ikut dikembalikan

### `POST /wfa`

Tujuan:

- membuat pengajuan `WFA reguler` atau `WFA overtime`

Dipakai oleh mobile:

- form submit WFA

Body minimum:

```json
{
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
  "initial_task": "Presentasi progres",
  "note": "Pengajuan WFA overtime dari mobile"
}
```

Validasi minimum:

- `mode` wajib salah satu:
  - `regular`
  - `overtime`
- `work_date` wajib
- `start_time` wajib
- `end_time` wajib
- `location_label` wajib
- `reason` wajib
- `initial_task` wajib
- `compensation_mode` wajib untuk `mode = overtime`

Rule backend:

- backend membentuk `approval_steps`
- record baru selalu `pending`
- `task_updates` awalnya kosong
- `submitted_at` diisi backend

Response minimum:

- satu `WfaRequestRecord` lengkap

### `PATCH /wfa/{id}/status`

Tujuan:

- menggerakkan sesi WFA dari approval ke pelaksanaan

Dipakai oleh mobile:

- tombol mulai sesi
- tombol selesai sesi

Body minimum:

```json
{
  "status": "active",
  "actual_start_at": "2026-04-24T12:30:00.000Z",
  "actual_end_at": null,
  "note": "Sesi WFA dimulai sesuai approval"
}
```

Validasi minimum:

- `status` wajib salah satu:
  - `approved`
  - `active`
  - `completed`
  - `rejected`
- `actual_start_at` wajib saat status jadi `active`
- `actual_end_at` wajib saat status jadi `completed`

Rule backend:

- `pending` tidak boleh langsung menjadi `active`
- `rejected` tidak boleh punya `actual_start_at`
- `completed` harus punya `actual_start_at` dan `actual_end_at`
- perubahan ke `completed` harus menjaga data agar nanti bisa dibaca modul absensi

### `POST /wfa/{id}/task-updates`

Tujuan:

- menyimpan progress task sepanjang sesi WFA

Dipakai oleh mobile:

- upload bukti kegiatan
- update task teks

Body minimum:

```json
{
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
```

Validasi minimum:

- `message` wajib
- `attachments` opsional
- setiap attachment minimal punya:
  - `file_name`
  - `mime_type`
  - `url`

Rule backend:

- task update hanya boleh untuk request berstatus:
  - `approved`
  - `active`
  - `completed`
- attachment sebaiknya di-relasi ke `wfa_task_updates`, bukan langsung ke `wfa_requests`

Response minimum:

- task update yang baru dibuat
- idealnya kembalikan juga WFA terbaru bila ingin mengurangi fetch ulang

### `GET /approvals/inbox`

Tujuan:

- mengambil item pending yang memang menjadi tanggung jawab approver aktif

Dipakai oleh mobile:

- tab `Approval` untuk `Leave` dan `WFA`

Query minimum:

- `approver_id`

Query opsional:

- `module`
- `page`
- `per_page`

Rule query:

- hanya step `pending` yang approver-nya cocok
- hanya current step aktif yang boleh muncul
- `module` bisa:
  - `leave`
  - `wfa`

Response minimum:

```json
{
  "data": [
    {
      "id": "leave::leave_001",
      "module": "leave",
      "reference_id": "leave_001",
      "requester_id": "usr_001",
      "requester_name": "Nadia Staff",
      "requester_role": "staff",
      "title": "izinPerHari",
      "summary": "Keperluan keluarga",
      "status": "pending",
      "submitted_at": "2026-04-24T02:00:00.000Z",
      "approval_steps": []
    }
  ]
}
```

Validasi bisnis:

- item inbox harus cukup kaya untuk membuka detail tanpa fetch tambahan yang mahal
- minimal tetap bawa `approval_steps`

### `POST /approvals/{id}/approve`

Tujuan:

- menyetujui step approval aktif

Dipakai oleh mobile:

- tombol `Setujui` di approval center

Body minimum:

```json
{
  "approver_id": "usr_spv_001",
  "approver_name": "Dimas SPV",
  "note": "Lanjutkan ke management"
}
```

Validasi minimum:

- `approver_id` wajib
- `note` opsional tapi disarankan

Rule backend:

- hanya boleh menyentuh current step `pending`
- `acted_at` diisi backend
- jika masih ada next step, source record tetap `pending`
- jika semua step selesai, source record jadi `approved`
- response sebaiknya mengembalikan record asal yang sudah diperbarui

### `POST /approvals/{id}/reject`

Tujuan:

- menolak step approval aktif

Dipakai oleh mobile:

- tombol `Tolak` di approval center

Body minimum:

```json
{
  "approver_id": "usr_spv_001",
  "approver_name": "Dimas SPV",
  "note": "Dokumen belum lengkap"
}
```

Validasi minimum:

- `approver_id` wajib
- `note` sebaiknya diwajibkan untuk penolakan

Rule backend:

- current step berubah jadi `rejected`
- `acted_at` diisi backend
- source record langsung jadi `rejected`
- step setelahnya tidak boleh lagi aktif

## Business Rules yang Harus Dijaga

### Leave

- `staff` harus punya step:
  - sequence 1 `spv`
  - sequence 2 `management`
- `spv` dan `areaManager` harus punya step:
  - sequence 1 `management`
- `management` bisa auto-approved atau tanpa chain tambahan, sesuai kebijakan bisnis final
- request `rejected` tidak boleh kembali ke `pending` tanpa tindakan admin eksplisit

### WFA

- `regular` dan `overtime` tetap memakai approval
- `overtime` wajib simpan `compensation_mode`
- status lifecycle yang disarankan:
  - `pending`
  - `approved`
  - `active`
  - `completed`
  - `rejected`
- `task_updates` hanya boleh masuk setelah request minimal `approved`

### Approval

- approver tidak boleh approve step milik approver lain
- step berikutnya hanya boleh aktif setelah step sebelumnya `approved`
- rejection mengakhiri flow source record
- note keputusan harus disimpan karena mobile menampilkannya di detail

## Query dan Loading Strategy

### Untuk `GET /leave`

- eager load:
  - `approval_steps`
- default sorting:
  - `submitted_at DESC`

### Untuk `GET /wfa`

- eager load:
  - `approval_steps`
  - `task_updates.attachments`
- default sorting:
  - `submitted_at DESC`

### Untuk `GET /approvals/inbox`

- query berdasarkan `approval_steps`
- join ke source record `leave_requests` atau `wfa_requests`
- hanya ambil step yang:
  - `status = pending`
  - menjadi step aktif paling rendah untuk record tersebut

## Edge Case yang Perlu Diuji

- `staff` submit leave lalu `SPV` approve, inbox pindah ke `Management`
- `Management` reject, requester langsung lihat note penolakan
- `WFA overtime` approved lalu digeser ke `active` dan `completed`
- upload task update dengan attachment tetap muncul saat refresh data
- approver mencoba approve item yang bukan miliknya harus gagal `403`
- request yang sudah `rejected` tidak boleh menerima task update baru
- inbox dengan filter `module=leave` tidak boleh membawa item WFA

## Acceptance Checklist

- `GET /me` mengembalikan relasi approver yang benar
- requester bisa submit leave dan langsung melihat record hasil submit
- requester bisa submit WFA reguler dan overtime
- approval inbox hanya menampilkan current pending step untuk approver aktif
- approve step antara `SPV` dan `Management` berpindah benar
- reject step menyimpan note dan mengubah status source record
- WFA approved bisa mulai sesi dan selesai sesi
- task update WFA tersimpan dan terbaca lagi oleh mobile
- shape respons konsisten dengan kontrak di [backend_contract.md](/C:/Users/user/Desktop/FolonyActivity/docs/backend_contract.md)
- jika backend belum aktif, mobile tetap aman karena repository masih punya fallback mock

## Implementasi Fase Berikutnya

Setelah dokumen ini selesai dieksekusi, batch backend berikutnya yang paling masuk akal:

1. `Attendance`
2. `Network`
3. `Heat Map`
4. autentikasi final dan token refresh

Urutan ini paling aman karena `Leave`, `WFA`, dan `Approval` sudah menjadi pusat workflow lintas role, sehingga modul berikutnya tinggal menempel ke struktur user dan approval yang sudah stabil.
