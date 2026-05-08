# HEX Activity

Scaffold awal aplikasi mobile untuk menerjemahkan dokumen kebutuhan sistem HEX Activity ke fondasi proyek yang rapi dan bertahap.

## Fokus Scaffold

- Menyediakan struktur folder yang siap dikembangkan.
- Menyiapkan alur aplikasi berdasarkan role.
- Membuat placeholder screen untuk modul utama.
- Menjaga UI tetap sederhana agar mudah dipoles di fase berikutnya.
- Belum terhubung ke backend, database, atau service pihak ketiga.

## Asumsi Awal

- Stack mobile menggunakan Flutter.
- Login masih berupa simulasi role selector untuk mempercepat iterasi awal.
- Backend, autentikasi nyata, notifikasi, maps, dan upload file akan ditambahkan di fase berikutnya.
- Role utama yang dipakai: `Area Manager`, `FGG`, `Staff`, `SPV`, `Management`.

## Struktur Utama

```text
lib/
  app/
  core/
  features/
    attendance/
    auth/
    dashboard/
    heatmap/
    home/
    leave/
    network/
    profile/
    shell/
    wfh/
docs/
```

## Modul yang Sudah Disiapkan

- Login simulasi berbasis role
- Home / ringkasan
- Absensi
- Dashboard Area / FGG
- Jaringan
- Heat Map
- WFA Activity
- Pengajuan Cuti
- Approval Cuti
- Profil / akun

## Catatan Pengembangan Lanjut

Urutan yang saya sarankan setelah scaffold ini:

1. Sempurnakan UI flow per role.
2. Finalkan detail UKM, Mitra, dan monitoring Area Manager.
3. Definisikan model domain dan validasi form.
4. Tentukan kontrak API dan backend.
5. Sambungkan repository, persistence, dan service eksternal.

## Menjalankan Proyek

Saat Flutter SDK sudah tersedia:

```bash
flutter pub get
flutter run
```
