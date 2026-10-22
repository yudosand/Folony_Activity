# Modul Supplier — staging, 22 Oktober 2026

## Perilaku

- Mobile: SPV, Management, dan Area Manager mendapat shortcut **Tambah Supplier** dan **Supplier yang saya tambahkan** pada Home. Staff dan FGG tidak mendapat menu atau akses API Supplier.
- Form: nama supplier, nama PIC supplier, nomor HP, alamat/lokasi, 1–50 nama barang, serta catatan opsional. Barang ganda ditolak.
- Mobile: alamat manual meminta provinsi, kota/kabupaten, kecamatan dan alamat; boleh tanpa koordinat. Setelah GPS atau titik peta dipilih, input wilayah/alamat manual disembunyikan. Koordinat cukup untuk menyimpan; reverse geocoding mengisi wilayah/alamat jika tersedia dan kegagalannya tidak menghalangi penyimpanan. Kembali ke manual menghapus koordinat dan hasil alamat otomatis. Web menyediakan GPS/pin peta dengan pilihan wilayah dan alamat manual.
- PIC supplier adalah kontak yang diisi pengguna. PIC pembuat tetap diambil dari akun autentikasi server; input `created_by` dari klien tidak digunakan.
- Daftar dan detail API mobile selalu dibatasi pada `created_by` pengguna. Management juga tidak dapat membaca supplier pengguna lain.
- HR mendapat Daftar Supplier, detail, tambah supplier, filter provinsi/kota/kecamatan, pencarian nama supplier/PIC, serta filter Kebutuhan / Barang. Filter kebutuhan mencocokkan sebagian nama setiap barang dan berlaku pada tabel serta peta. Peta memakai komponen Monitoring Jaringan, termasuk cluster, pilihan jalan/satelit, label, zoom dan layar penuh.
- Filter tabel dan peta memakai query yang sama. Data tanpa koordinat tetap tampil pada tabel dan dihitung sebagai belum dipetakan. Titik dimuat dengan cursor, tidak dibatasi pada halaman tabel.
- Supplier yang dibuat HR dicatat atas akun HR, tidak ditambahkan ke daftar pribadi pengguna mobile.

## Struktur dan deploy

Migrasi: `2026_10_22_000001_create_suppliers_table.php` dan `2026_10_22_000002_add_supplier_pic_and_optional_gps_address.php`. Migrasi kedua menambah PIC supplier dan mengizinkan alamat/wilayah null untuk GPS. Data lama dipertahankan, PIC kontak lama ditampilkan sebagai Belum diisi. Tabel terpisah dari jaringan UKM/Mitra. Belum ada edit/hapus atau approval Supplier karena tidak termasuk permintaan ini.

API: `GET /api/suppliers`, `POST /api/suppliers`, `GET /api/suppliers/{uuid}`.

Web HR: `/admin/suppliers`, `/admin/suppliers/create`, `/admin/suppliers/{uuid}`, `/admin/suppliers/map-points`.

Gunakan paket staging dari `dist/supplier-staging-2026-10-22-v2/`. ZIP berisi root Laravel dan vendor lengkap, tanpa `.env`, database atau upload lama. Pertahankan `.env`, `APP_KEY`, dan storage server. Jalankan `optimize:clear` dan `migrate --force` sebelum memakai form APK terbaru. Link helper staging sekali pakai tersedia dalam panduan privat paket. Tidak menjalankan migrasi pada production.

APK staging v2: versi 0.1.14, versionCode 20261023, ARM64; backend `https://staging-absent.folony.co.id/api`, demo nonaktif. APK memakai application ID/signing yang sama seperti sebelumnya, sehingga instal mengganti APK yang ada. Logout terlebih dahulu ketika beralih dari production.

## Verifikasi

- 161 tes backend / 1109 assertions lulus, termasuk 8 tes Supplier / 107 assertions.
- 8 tes Flutter Supplier lulus: menu per role, daftar bertahap, detail, PIC kontak, submit multi-barang manual, serta GPS tanpa isian wilayah saat reverse geocoding gagal.
- Uji upgrade SQLite terisolasi lulus: data supplier lama dan creator tetap utuh setelah migrasi kedua; data GPS tanpa alamat dapat disimpan.
- Analisis statis pada seluruh berkas Dart yang berubah: tidak ada masalah.
- Syntax JavaScript form supplier dan peta lulus.
- ZIP v2: 8.793 berkas cocok dan CRC lulus. APK: metadata 0.1.14 / 20261023, tanda tangan valid/cocok dengan versi sebelumnya; binary memuat backend staging dan perubahan form GPS/PIC terbaru.
- APK v2 berhasil diinstal dengan `adb install -r` pada Infinix X678B yang terhubung. Data aplikasi dipertahankan.
- Belum menguji GPS fisik/perizinan perangkat atau transaksi pada server staging live pada pekerjaan ini. Backend v2 dan migrasinya perlu dideploy sebelum menggunakan form terbaru.

Kode dan artefak disiapkan pada branch staging. Tidak melakukan push, deployment server, atau perubahan production. Instal APK staging pada perangkat telah selesai.
