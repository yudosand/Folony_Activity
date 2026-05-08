# Foundation Notes

Dokumen ini menyimpan keputusan awal supaya fase UI dan backend berikutnya lebih cepat.

## Keputusan Awal

- App dimulai dari satu mobile codebase.
- Routing utama mengikuti role user.
- Navigasi bawah dibentuk secara dinamis sesuai role.
- Semua modul inti dibuat sebagai placeholder page lebih dulu.
- State sesi masih lokal agar iterasi struktur tidak tertahan backend.
- Jam kerja standar mock saat ini dikunci ke `08:30 - 17:00`.
- Rule engine absensi awal sudah aktif untuk `tepat waktu`, `terlambat`, `pulang cepat`, dan `lembur`.

## Yang Perlu Kita Putuskan Nanti

- Autentikasi final: username, email, nomor HP, atau SSO.
- Kebijakan absensi: radius GPS final, toleransi telat, dan mekanisme liveness production.
- Kebijakan cuti: tipe cuti, saldo, kalender kerja.
- Integrasi maps dan provider lokasi.
- Penyimpanan foto dan dokumen.
- Apakah admin dashboard web dibangun paralel atau setelah mobile stabil.

## Saran Tahap Berikut

- Buat wireframe low fidelity per role.
- Pecah placeholder page menjadi widget section nyata.
- Definisikan model `User`, `Attendance`, `LeaveRequest`, `WfaSession`, `NetworkLead`.
- Tambahkan repository abstraction sebelum backend final masuk.

## Progress Backend Prep

- Domain contract draft sudah dibuat di `docs/backend_contract.md`.
- Model backend-ready sudah ditambahkan untuk `AppUser`, `AttendanceRecord`, `LeaveRequestRecord`, `WfaRequestRecord`, `ApprovalItem`, dan `NetworkProfile`.
- Repository abstraction dasar sudah ditambahkan untuk auth, attendance, leave, WFA, approval, dan network.
- `Network`, `Leave`, `WFA`, `Approval`, dan `Attendance` sudah mulai memakai source of truth repository mock.
- `Attendance` sudah punya mock persistence lokal dan mulai terhubung ke konteks `WFA overtime`.
- Histori approval sekarang sudah menyimpan step, acted time, dan catatan keputusan.
