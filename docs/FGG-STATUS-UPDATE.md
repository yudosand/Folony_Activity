# Pembaruan filter pengiriman FGG

- DST pertama kali dibuka dengan `status=1` (bisa diterima).
- Tab Kiriman pertama kali dibuka dengan `status=1` (Siap dikirim).
- Perpindahan tab mengembalikan filter ke status utama masing-masing dan halaman 1.
- DST menyediakan filter Bisa diterima, Sudah diterima, dan Semua status.
- Kartu DST menunjukkan kemampuan penerimaan dari `recipient_button`; tombol
  Terima kiriman hanya muncul jika flag tersebut true. Nilai status dari API
  juga ditampilkan jika tersedia.
- Sesudah penerimaan berhasil, aplikasi membuka tab Kiriman status Siap dikirim.
- Filter Kiriman hanya Siap dikirim (1) dan Sudah dikirim (2).

APK: `FolonyActivity-FGG-staging-2026-09-16-v4.apk`, versi 0.1.5-staging,
build 20260919. Gunakan ZIP FolonyActivity-FGG-lapangan-2026-09-16.zip dan jalankan migrasi agar laporan FGG pindah ke Aktivitas Lapangan.

Validasi: empat widget test FGG lulus; Dart analyzer tidak menemukan masalah.
