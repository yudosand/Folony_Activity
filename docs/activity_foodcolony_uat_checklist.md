# UAT Checklist `activity.foodcolony.com`

Checklist ini dipakai setelah backend Laravel benar-benar live di `https://activity.foodcolony.com`.

## Pre-Check

1. Buka `https://activity.foodcolony.com/api/me` tanpa token dan pastikan response `401 JSON`.
2. Pastikan folder upload publik bisa diakses.
3. Pastikan `php artisan migrate --seed --force` sudah selesai tanpa error.
4. Pastikan `storage` dan `bootstrap/cache` writable.

## Staff

1. Login sebagai `Staff`.
2. Lakukan `Check-in` dengan verifikasi wajah mock dan lokasi aktif.
3. Cek apakah riwayat absensi tersimpan.
4. Buat pengajuan `Cuti / Izin`.
5. Buat pengajuan `WFA Reguler`.
6. Buat `WFA Overtime`.
7. Tambah update task dengan upload foto.
8. Cek status pengajuan setelah approval.

## SPV

1. Login sebagai `SPV`.
2. Buka `Approval Center`.
3. Approve satu pengajuan `Cuti / Izin` dari `Staff`.
4. Approve satu pengajuan `WFA` dari `Staff`.
5. Tolak satu pengajuan dan isi alasan.
6. Pastikan histori approval tampil di detail request.

## Management

1. Login sebagai `Management`.
2. Buka inbox approval.
3. Approve satu pengajuan yang sudah melewati `SPV`.
4. Approve atau reject satu `WFA Overtime`.
5. Cek apakah status akhir sinkron di halaman asal.

## FGG

1. Login sebagai `FGG`.
2. Tambah `UKM` baru.
3. Cari `UKM` dengan search nama.
4. Buka detail `UKM`.
5. Tambahkan follow-up.
6. Pastikan `UKM` muncul di `Heat Map` jika koordinat valid.

## Area Manager

1. Login sebagai `Area Manager`.
2. Buka `UKM Tim FGG`.
3. Pastikan data `FGG` muncul sesuai area.
4. Buka detail `UKM`.
5. Buka `Heat Map` dan ganti radius `500m`, `1km`, `2km`.
6. Ajukan `WFA` dan `Cuti / Izin`.

## Global Error Check

1. Putuskan internet lalu cek handling error di mobile.
2. Login dengan password salah.
3. Upload file terlalu besar atau tipe tidak valid.
4. Akses endpoint tanpa token.
5. Cek apakah snackbar/pesan error tetap jelas.

## Sign-Off Minimum

1. Semua role bisa login.
2. Semua pengajuan utama bisa dibuat.
3. Approval berantai bekerja.
4. Upload berjalan.
5. Absensi menyimpan lokasi.
6. Data jaringan tersimpan dan terbaca ulang.
7. `Heat Map` memuat titik live dari backend.
