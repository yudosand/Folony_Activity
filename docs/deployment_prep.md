# Deployment Prep

Dokumen ini dipakai untuk menyiapkan backend Laravel dan aplikasi Flutter saat pindah dari local development ke staging atau production.

## Backend Checklist

1. Set `APP_ENV`, `APP_DEBUG`, dan `APP_URL` dengan benar.
2. Pastikan database target sudah tersedia.
3. Jalankan migration dan seeder awal bila perlu.
4. Buat symbolic link storage publik.
5. Pastikan token auth Sanctum aktif.
6. Pastikan upload publik mengarah ke URL yang bisa diakses device.

## Shared Hosting / Panel DB

Kalau database diambil dari panel hosting seperti contoh `folony_activity`, backend Laravel bisa langsung memakai database itu selama aplikasi Laravel berjalan di server yang sama.

Konfigurasi minimum yang biasanya dipakai:

```dotenv
DB_CONNECTION=mysql
DB_HOST=localhost
DB_PORT=3306
DB_DATABASE=folony_activity
DB_USERNAME=folony_activity
DB_PASSWORD=isi-password-panel
```

Catatan penting:
- `DB_HOST=localhost` hanya benar jika backend Laravel dijalankan di server hosting yang sama dengan database tersebut.
- Jika backend masih dijalankan dari laptop atau server lain, `localhost` tidak akan menuju database hosting itu. Dalam kondisi itu dibutuhkan host/IP MySQL eksternal dan izin remote access dari panel/hosting.
- Template siap pakai untuk mode ini ada di [backend/.env.mysql.example](/C:/Users/user/Desktop/FolonyActivity/backend/.env.mysql.example).
- Untuk target `activity.foodcolony.com`, template khususnya ada di [backend/.env.activity.foodcolony.example](/C:/Users/user/Desktop/FolonyActivity/backend/.env.activity.foodcolony.example) dan panduan deploy lengkapnya ada di [activity_foodcolony_shared_hosting.md](/C:/Users/user/Desktop/FolonyActivity/docs/activity_foodcolony_shared_hosting.md).

Command minimum:

```powershell
cd C:\Users\user\Desktop\FolonyActivity\backend
copy .env.example .env
& 'C:\xampp\php\php.exe' artisan key:generate
& 'C:\xampp\php\php.exe' artisan migrate --seed
& 'C:\xampp\php\php.exe' artisan storage:link
& 'C:\xampp\php\php.exe' artisan optimize:clear
& 'C:\xampp\php\php.exe' artisan test
```

## Nilai `.env` Minimum

```dotenv
APP_ENV=local
APP_DEBUG=true
APP_URL=http://127.0.0.1:8000

DB_CONNECTION=sqlite
FILESYSTEM_DISK=public
SESSION_DRIVER=database
QUEUE_CONNECTION=database
```

Untuk server MySQL hosting, nilai minimumnya berubah menjadi:

```dotenv
APP_ENV=production
APP_DEBUG=false
APP_URL=https://your-domain.example

DB_CONNECTION=mysql
DB_HOST=localhost
DB_PORT=3306
DB_DATABASE=folony_activity
DB_USERNAME=folony_activity
DB_PASSWORD=isi-password-panel

FILESYSTEM_DISK=public
SESSION_DRIVER=database
QUEUE_CONNECTION=database
```

Catatan:
- Untuk upload attachment, `APP_URL` harus benar agar URL file yang dikembalikan backend valid.
- Untuk device Android fisik di local, base URL mobile tetap aman memakai `http://127.0.0.1:8000/api` jika `adb reverse` aktif.

## Perpindahan Dari SQLite Ke MySQL Hosting

1. Copy [backend/.env.mysql.example](/C:/Users/user/Desktop/FolonyActivity/backend/.env.mysql.example) menjadi `.env` di server Laravel.
2. Isi `APP_KEY`, domain aplikasi, dan password database panel.
3. Jalankan:

```powershell
& 'C:\xampp\php\php.exe' artisan key:generate
& 'C:\xampp\php\php.exe' artisan migrate --seed
& 'C:\xampp\php\php.exe' artisan storage:link
& 'C:\xampp\php\php.exe' artisan optimize:clear
& 'C:\xampp\php\php.exe' artisan test
```

4. Jika database lama sudah berisi tabel manual, cek dulu konflik nama tabel sebelum menjalankan migration.
5. Jika server memakai phpMyAdmin panel, data seed atau dump SQL juga bisa diimpor dari sana setelah struktur final dikunci.

## Menjalankan Backend Lokal Untuk Device

```powershell
cd C:\Users\user\Desktop\FolonyActivity\backend
& 'C:\xampp\php\php.exe' artisan serve --host=127.0.0.1 --port=8000
```

ADB reverse:

```powershell
cd C:\Users\user\Desktop\FolonyActivity
& '.\tools\android-sdk\platform-tools\adb.exe' -s 10268333AG000364 reverse tcp:8000 tcp:8000
```

## Build Mobile Remote Mode

```powershell
cd C:\Users\user\Desktop\FolonyActivity
& '.\tools\flutter\bin\flutter.bat' build apk --debug `
  --dart-define=HEX_ENABLE_REMOTE_WORKFLOW=true `
  --dart-define=HEX_BACKEND_BASE_URL=http://127.0.0.1:8000/api
```

Install ke device:

```powershell
cd C:\Users\user\Desktop\FolonyActivity
& '.\tools\flutter\bin\flutter.bat' install -d 10268333AG000364
```

## Smoke Test Minimum Setelah Deploy

1. Login dengan user demo valid.
2. Buka `GET /me` implicit dari mobile restore/login.
3. Submit `WFA`.
4. Tambah update task WFA dengan upload foto.
5. Submit `Cuti / Izin`.
6. Approve request dari role approver.
7. Tambah `UKM` dan pastikan muncul di daftar.
8. Cek `Heat Map` dengan radius 500 m, 1 km, dan 2 km.
9. Lakukan `Check-in` dan `Check-out`.

## Web Admin HR Dan Source Data Bersama

Web admin HR dibangun di Laravel yang sama dengan API mobile. Artinya, web admin hanya akan membaca data yang sama dengan aplikasi mobile jika keduanya berjalan di environment dan database yang sama.

Aturan praktisnya:
- Jika mobile staging mengarah ke database MySQL hosting, web admin HR juga harus dibuka dari deploy Laravel staging yang memakai database MySQL yang sama.
- Jika web admin masih dibuka dari `localhost` dengan `sqlite`, maka data yang tampil masih data lokal, bukan data live dari aplikasi.

Checklist cepat verifikasi:
1. Buka dashboard admin HR.
2. Cek panel `Source Data Mobile`.
3. Pastikan `DB Connection` bukan `sqlite` jika targetnya monitoring live.
4. Pastikan `APP URL` sesuai host staging/production yang dipakai mobile.

Route web admin:
- `/admin/login`
- `/admin/dashboard`

Untuk UAT live, gunakan URL web admin dari deploy Laravel yang sama dengan base URL API mobile aktif.

### Staging `nip.io`

Untuk host staging seperti:

- `http://folony-27-112-79-213.nip.io`

gunakan template:

- [backend/.env.nipio.staging.example](/C:/Users/user/Desktop/FolonyActivity/backend/.env.nipio.staging.example)

Catatan penting:
- `SESSION_DOMAIN` harus dikosongkan untuk host `nip.io`, supaya login web admin HR bisa menyimpan cookie session dengan benar.
- `SANCTUM_STATEFUL_DOMAINS` harus mengikuti host `nip.io` yang dipakai.
- setelah deploy, web admin live bisa dibuka di `/admin/login` pada host yang sama dengan API mobile.

## Route Inventory Yang Sudah Aktif

- Auth: `login`, `logout`, `me`
- Workflow: `leave`, `wfa`, `approvals`
- Field ops: `network`, `attendance`, `heat-map`
- Upload: `uploads/attachments`
