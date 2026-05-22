# Deploy Staging `folony-27-112-79-213.nip.io`

Dokumen ini dipakai untuk menaikkan Laravel yang sama ke host staging `nip.io`, supaya:

- mobile app membaca API staging yang sama
- web admin HR membaca database yang sama
- data WFA, Cuti, Approval, Jaringan, dan Absensi benar-benar sinkron

## Package Yang Sudah Disiapkan

- generator package: [scripts/prepare_nipio_staging_package.ps1](/C:/Users/user/Desktop/FolonyActivity/scripts/prepare_nipio_staging_package.ps1)
- template env staging: [backend/.env.nipio.staging.example](/C:/Users/user/Desktop/FolonyActivity/backend/.env.nipio.staging.example)

Setelah generator dijalankan, output ada di:

- [deploy/folony-27-112-79-213.nip.io/backend-app](/C:/Users/user/Desktop/FolonyActivity/deploy/folony-27-112-79-213.nip.io/backend-app)
- [deploy/folony-27-112-79-213.nip.io/public_html](/C:/Users/user/Desktop/FolonyActivity/deploy/folony-27-112-79-213.nip.io/public_html)

## Kenapa Perlu Package Khusus `nip.io`

Host `nip.io` dipakai untuk staging live mobile. Web admin HR juga harus dibuka dari host yang sama agar source datanya satu.

Catatan penting:
- `SESSION_DOMAIN` harus kosong
- `SANCTUM_STATEFUL_DOMAINS` harus `folony-27-112-79-213.nip.io`
- jangan pakai template `.foodcolony.com` untuk login web admin di host ini

## Langkah Upload

1. Upload isi `public_html` ke document root host `folony-27-112-79-213.nip.io`
2. Upload folder `backend-app` sebagai sibling document root
3. Edit `backend-app/.env`
4. Isi `APP_KEY`
5. Isi `DB_PASSWORD`
6. Jalankan:

```bash
php artisan migrate --force
php artisan storage:link
php artisan optimize:clear
```

Catatan:
- jangan jalankan `--seed` lagi di database staging yang sudah berisi data, karena data demo seperti `leave_001` bisa bentrok
- package deploy ini memang tidak ditujukan untuk menjalankan `php artisan test` di server

## URL Penting

- API: `http://folony-27-112-79-213.nip.io/api`
- Web Admin Login: `http://folony-27-112-79-213.nip.io/admin/login`
- Web Admin Dashboard: `http://folony-27-112-79-213.nip.io/admin/dashboard`

## Login HR Demo

- email: `hr@hex.local`
- phone: `086666666666`
- employee code: `EMP-HR-001`
- password: `123456`

## Validasi Setelah Live

1. Buka `/admin/login`
2. Login HR
3. Cek panel `Source Data Mobile` di dashboard
4. Pastikan `DB Connection` bukan `sqlite`
5. Submit data dari mobile staging
6. Pastikan data yang sama tampil di:
   - `Monitoring Absensi`
   - `Cuti / Izin`
   - `Monitoring WFA`
   - `Approval Center`
   - `Monitoring Jaringan`
