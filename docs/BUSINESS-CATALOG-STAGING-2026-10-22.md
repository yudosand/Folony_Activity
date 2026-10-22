# Uji kategori dan jenis usaha — staging

Perubahan diterapkan hanya pada staging-absent.folony.co.id. Form UKM dan Mitra menggunakan kategori lalu jenis usaha dari master HR. Mengubah kategori mengosongkan jenis usaha. APK lama dan CSV tetap dapat mengirim teks bebas; alias yang dikenali dipetakan, selebihnya masuk Perlu ditinjau.

## Master dan data awal

- Master tersedia melalui Monitoring Jaringan → Pengaturan → Master Jenis Usaha (`/admin/business-catalog`): tambah/edit kategori dan warna, tambah/edit jenis dan ikon, aktif/nonaktif, serta pemetaan kelompok data lama yang belum diklasifikasikan. Pengaturan tertutup saat halaman dibuka; master tidak memiliki tautan terpisah di sidebar.
- API katalog aktif: `GET /api/business-catalog`, wajib login aktif.
- Sumber awal: rekap 14.714 profil staging, 1.336 variasi label. Master awal 6 kategori, 176 jenis, 757 alias ternormalisasi.
- 13.453 profil terpetakan, 1.261 profil tetap Perlu ditinjau. Isian seperti meeting, kegiatan non-usaha, serta campuran yang belum jelas tidak ditebak. Campuran jenis yang jelas dalam satu kategori memakai jenis Beragam dan tetap menyimpan teks asal.
- Pemetaan tidak mengubah `business_type`, koordinat, pemilik atau waktu pembaruan. `business_kind_id` menautkan master; kategori diturunkan dari jenis agar tidak berbeda pasangan.
- Master yang nonaktif tidak dapat dipilih untuk profil baru, tetapi riwayat profil tetap ditampilkan.

## Peta dan form

Monitoring Jaringan memiliki filter kategori dan jenis yang berlaku sama pada daftar, ekspor dan titik peta. Warna mengikuti kategori; ikon mengikuti jenis. Ayam Geprek menggunakan ikon ayam, Mie Ayam dan Bakso memakai mangkuk. Cluster menampilkan jumlah lokasi dan dapat mencampur kategori. Legenda kategori dapat diklik untuk memfilter peta. Jenis asli dan jenis baku terlihat pada detail profil.

APK menampilkan pilihan kategori dan jenis; kategori besar menyediakan kolom pencarian jenis. Jika master gagal dimuat, pengguna harus mencoba lagi, tidak menyimpan pasangan yang tidak valid. APK staging 0.1.15 / 20261024, ARM64, demo nonaktif.

## Deployment dan pemulihan

Migrasi tambahan `2026_10_22_000003_create_business_catalog.php`. Data master awal disimpan di `database/data/business-catalog.json` dan wajib masuk paket backend. `php artisan business:bootstrap` menampilkan pratinjau; `--apply` menyimpan backup privat sebelum membuat master dan memetakan profil yang belum terklasifikasi. Perintah ini membatasi host ke staging. Tidak memakai migrate:fresh atau menghapus data jaringan.

Backup klasifikasi ada pada `storage/app/private/business-catalog-backups/`; paket pemulihan kode sebelum uji berada pada `storage/app/private/business-catalog-code-20261022/pretrial-recovery.tar.gz`, disusun dari paket staging terverifikasi sebelumnya. Paket kode lama dapat dipulihkan tanpa menghapus tabel tambahan. Jangan rollback skema selagi kode baru masih digunakan. Tidak ada deployment production atau git push pada perubahan ini.

## Verifikasi

- 167 tes backend / 1.174 assertions lulus: akses HR, katalog login, pasangan kategori/jenis, master nonaktif, APK lama, filter daftar/peta, pemetaan konservatif dan idempotensi.
- 3 tes Flutter lulus: pergantian kategori, validasi jenis, gagal muat/retry dan perjalanan ID melalui mapper/API.
- Analisis Dart pada file yang berubah lulus; syntax kedua JavaScript dan kompilasi Blade lulus.
- Verifikasi MySQL staging: 0 perubahan pada label asli, koordinat dan timestamp yang dicadangkan. Ayam Geprek 293 titik, Mie Ayam 502, Bakso 764.
- Browser HR staging: seluruh 14.714 titik termuat; filter Kuliner memuat 11.435; filter Ayam Geprek memuat 293; ikon ayam oranye terlihat setelah cluster diperbesar.
- APK 0.1.15 / 20261024 berhasil diinstal dengan pembaruan tanpa menghapus data pada Infinix X678B (10268333AG000364). Binary diverifikasi memuat endpoint staging dan katalog bisnis. Pengujian form APK menggunakan tes widget; belum membuat profil UKM/Mitra baru dari perangkat fisik.
- Paket lengkap tersedia pada `dist/business-catalog-staging-2026-10-22/`; 8.804 berkas backend diverifikasi cocok, CRC ZIP lulus, dan root ZIP langsung Laravel tanpa pembungkus. Paket menyertakan `database/data/business-catalog.json`, tanpa `.env` atau data server.

Pemetaan awal merupakan bahan uji. Data abu-abu perlu ditinjau melalui master sebelum menentukan klasifikasi; jumlah yang sudah terpetakan bukan penilaian akurasi lokasi usaha.
