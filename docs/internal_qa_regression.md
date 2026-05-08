# Internal QA Regression

Dokumen ini merangkum internal testing per batch untuk rollout backend dan integrasi mobile `HEX Activity`.

## Batch 1. Auth

- Login API `POST /api/auth/login`
- Token Sanctum dipakai mobile melalui `Authorization: Bearer`
- Restore session dari token cache
- Logout API `POST /api/auth/logout`

Status:
- Backend test lulus
- Flutter analyze lulus
- Flutter test lulus

## Batch 2. Leave, WFA, Approval

- Submit `Leave`
- Submit `WFA`
- Approval inbox
- Approve / reject dengan identifier komposit
- Status sumber ikut berubah setelah approval

Status:
- Backend test lulus
- Flutter analyze lulus
- Flutter test lulus

## Batch 3. Network

- `GET /api/network`
- `GET /api/network/team-ukm`
- `POST /api/network`
- `PATCH /api/network/{id}`
- `DELETE /api/network/{id}`
- `POST /api/network/{id}/follow-ups`

Status:
- Backend feature test lulus
- Authorization test untuk akses tim FGG lulus
- Integrasi mobile repository lulus compile/analyze/test

## Batch 4. Attendance

- `GET /api/attendance`
- `POST /api/attendance/check-in`
- `POST /api/attendance/check-out`
- `GET /api/attendance/daily-summary`
- `DELETE /api/attendance`

Status:
- Backend feature test lulus
- Rule engine backend menghasilkan summary harian
- Mobile repository lulus compile/analyze/test

## Batch 5. Heat Map

- `GET /api/heat-map`
- Radius filter berdasarkan lokasi user aktif
- Source data dari network profile yang punya koordinat

Status:
- Backend feature test lulus
- Mobile page sudah pakai lokasi device + fallback koordinat area
- Flutter analyze/test lulus

## Batch 6. Upload Nyata

- `POST /api/uploads/attachments`
- Foto WFA di-upload sebelum task update dikirim saat mode remote aktif
- Foto data jaringan di-upload sebelum profile disimpan saat mode remote aktif
- UI image renderer mendukung local file dan remote URL

Status:
- Backend upload test lulus
- Flutter analyze/test lulus

## Batch 7. Hardening

- Authorization test untuk endpoint terbatas
- Fallback repository tetap aman kalau remote gagal
- Rendering attachment remote/local tidak crash
- Analisis kode tanpa warning

Status:
- Backend test suite lulus
- Flutter analyze lulus tanpa issue
- Flutter test lulus

## Batch 8. Deployment Prep

- Route inventory backend sudah diverifikasi
- Dokumen deployment dan runtime checklist tersedia
- Konfigurasi `APP_URL`, storage, dan mobile `dart-define` terdokumentasi

Status:
- Dokumen deployment siap dipakai

## Command Baseline

Backend:

```powershell
cd C:\Users\user\Desktop\FolonyActivity\backend
& 'C:\xampp\php\php.exe' artisan test
& 'C:\xampp\php\php.exe' artisan route:list --path=api
```

Mobile:

```powershell
cd C:\Users\user\Desktop\FolonyActivity
& '.\tools\flutter\bin\flutter.bat' analyze
& '.\tools\flutter\bin\flutter.bat' test
```
