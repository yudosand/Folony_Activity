# Deploy `activity.foodcolony.com`

Dokumen ini khusus untuk deploy backend Laravel ke shared hosting dengan database:

- `DB_DATABASE=sql_activity_foodcolony_com`
- `DB_USERNAME=sql_activity_foodcolony_com`
- `DB_HOST=localhost`

## File Yang Sudah Disiapkan

- template environment: [backend/.env.activity.foodcolony.example](/C:/Users/user/Desktop/FolonyActivity/backend/.env.activity.foodcolony.example)
- generator package deploy: [scripts/prepare_activity_foodcolony_shared_hosting.ps1](/C:/Users/user/Desktop/FolonyActivity/scripts/prepare_activity_foodcolony_shared_hosting.ps1)

## Jalankan Generator Package

```powershell
cd C:\Users\user\Desktop\FolonyActivity
powershell -ExecutionPolicy Bypass -File .\scripts\prepare_activity_foodcolony_shared_hosting.ps1
```

Output akan dibuat di:

- [deploy/activity.foodcolony.com/backend-app](/C:/Users/user/Desktop/FolonyActivity/deploy/activity.foodcolony.com/backend-app)
- [deploy/activity.foodcolony.com/public_html](/C:/Users/user/Desktop/FolonyActivity/deploy/activity.foodcolony.com/public_html)

## Struktur Upload

Karena shared hosting sering tidak mengizinkan document root diarahkan langsung ke folder Laravel `public`, package ini memakai layout:

```text
activity.foodcolony.com/
  public_html/
    index.php
    .htaccess
    storage/
  backend-app/
    app/
    bootstrap/
    config/
    database/
    public/
    resources/
    routes/
    storage/
    vendor/
    .env
```

`public_html/index.php` sudah diubah agar menunjuk ke folder `../backend-app`.

## Langkah Upload

1. Upload semua isi folder `public_html` ke document root subdomain `activity.foodcolony.com`.
2. Upload folder `backend-app` ke lokasi sibling yang sejajar dengan `public_html`.
3. Edit `backend-app/.env`.
4. Ganti `DB_PASSWORD` dengan password database yang terbaru.
5. Isi `APP_KEY` jika belum ada.

## Nilai `.env` Yang Disarankan

```dotenv
APP_NAME=FolonyActivity
APP_ENV=production
APP_DEBUG=false
APP_URL=https://activity.foodcolony.com

DB_CONNECTION=mysql
DB_HOST=localhost
DB_PORT=3306
DB_DATABASE=sql_activity_foodcolony_com
DB_USERNAME=sql_activity_foodcolony_com
DB_PASSWORD=replace-with-rotated-password

FILESYSTEM_DISK=public
SESSION_DRIVER=database
QUEUE_CONNECTION=database
```

## Command Setelah Upload

Jika hosting menyediakan terminal atau SSH:

```bash
cd ~/backend-app
php artisan key:generate
php artisan migrate --seed --force
php artisan storage:link
php artisan optimize:clear
php artisan test
```

Kalau tidak ada terminal:

1. generate `APP_KEY` secara lokal lalu tempel ke `.env`
2. import migration atau dump SQL via phpMyAdmin
3. buat folder/link `public_html/storage` sesuai kemampuan hosting

## Permission Minimum

Folder berikut harus writable:

- `backend-app/storage`
- `backend-app/bootstrap/cache`

## Build Mobile Ke Domain Production

Setelah backend live, build APK dengan base URL production:

```powershell
cd C:\Users\user\Desktop\FolonyActivity
& '.\tools\flutter\bin\flutter.bat' build apk --debug `
  --dart-define=HEX_ENABLE_REMOTE_WORKFLOW=true `
  --dart-define=HEX_BACKEND_BASE_URL=https://activity.foodcolony.com/api
```

## Smoke Test Setelah Live

1. `POST /api/auth/login`
2. `GET /api/me`
3. submit `WFA`
4. submit `Cuti / Izin`
5. buka `Approval Inbox`
6. tambah `UKM`
7. upload foto
8. buka `Heat Map`
9. lakukan `Check-in` dan `Check-out`
