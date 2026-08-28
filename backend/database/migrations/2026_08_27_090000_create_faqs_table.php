<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('faqs', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->string('title');
            $table->text('body');
            $table->unsignedInteger('sort_order')->default(0);
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });

        $now = now();
        DB::table('faqs')->insert([
            [
                'id' => (string) Str::uuid(),
                'title' => 'Cara Absensi',
                'body' => "1. Buka menu Absensi.\n2. Pastikan GPS aktif dan posisi berada di area kerja.\n3. Daftarkan wajah jika status Face ID belum aktif.\n4. Saat scan, lihat ke kamera dan pastikan cahaya cukup.\n5. Tekan check-in atau check-out setelah verifikasi wajah berhasil.",
                'sort_order' => 10,
                'is_active' => true,
                'created_at' => $now,
                'updated_at' => $now,
            ],
            [
                'id' => (string) Str::uuid(),
                'title' => 'Cara Absensi di Luar Kantor',
                'body' => "1. Buka menu Absensi.\n2. Pilih absensi luar kantor jika role Anda memiliki akses.\n3. Verifikasi wajah.\n4. Isi lokasi/keperluan dan ambil foto dokumentasi dari kamera.\n5. Simpan saat mulai dan selesaikan saat aktivitas berakhir agar durasi tercatat di HR.",
                'sort_order' => 20,
                'is_active' => true,
                'created_at' => $now,
                'updated_at' => $now,
            ],
            [
                'id' => (string) Str::uuid(),
                'title' => 'Cara Pengajuan Cuti / Izin',
                'body' => "1. Buka menu Cuti.\n2. Pilih jenis pengajuan dan tanggal.\n3. Isi alasan serta lampirkan bukti jika diwajibkan.\n4. Kirim pengajuan.\n5. Pantau status approval di riwayat pengajuan.",
                'sort_order' => 30,
                'is_active' => true,
                'created_at' => $now,
                'updated_at' => $now,
            ],
            [
                'id' => (string) Str::uuid(),
                'title' => 'Cara WFA',
                'body' => "1. Buka menu WFA.\n2. Isi alasan, task awal, dan approver.\n3. Ajukan WFA.\n4. Setelah disetujui, mulai sesi WFA dan update aktivitas kerja.\n5. Semua update tersimpan sebagai histori WFA.",
                'sort_order' => 40,
                'is_active' => true,
                'created_at' => $now,
                'updated_at' => $now,
            ],
            [
                'id' => (string) Str::uuid(),
                'title' => 'Cara Tambah UKM / Mitra',
                'body' => "1. Buka menu Jaringan.\n2. Tekan tombol tambah dan pilih UKM atau Mitra.\n3. Ambil foto dari kamera.\n4. Gunakan GPS untuk mengisi wilayah atau isi manual jika alamat belum sesuai.\n5. Simpan data. Data milik Anda tetap tampil di UKM/Mitra Saya, sedangkan data area tampil sesuai wilayah kerja.",
                'sort_order' => 50,
                'is_active' => true,
                'created_at' => $now,
                'updated_at' => $now,
            ],
            [
                'id' => (string) Str::uuid(),
                'title' => 'Cara Heat Map dan Kunjungan',
                'body' => "1. Buka menu Heat Map.\n2. Pastikan GPS aktif, lalu pilih radius.\n3. Titik UKM/Mitra terdekat akan tampil sesuai radius posisi Anda.\n4. Tekan titik untuk melihat detail, direction, atau mulai kunjungan.\n5. Saat kunjungan, isi tipe kunjungan, ambil foto, lalu simpan agar durasi tercatat di HR.",
                'sort_order' => 60,
                'is_active' => true,
                'created_at' => $now,
                'updated_at' => $now,
            ],
            [
                'id' => (string) Str::uuid(),
                'title' => 'Cara Survey',
                'body' => "1. Buka menu Survey dari Home.\n2. Pilih Survey Kios atau Survey Harga.\n3. Ambil foto dan pastikan GPS aktif.\n4. Lengkapi data kios/pasar dan checklist yang tersedia.\n5. Simpan survey agar masuk ke Web Admin HR.",
                'sort_order' => 70,
                'is_active' => true,
                'created_at' => $now,
                'updated_at' => $now,
            ],
        ]);
    }

    public function down(): void
    {
        Schema::dropIfExists('faqs');
    }
};
