param([string]$ReleaseName = 'FolonyActivity-HR-daily-map-2026-09-10')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$backendRoot = Join-Path $projectRoot 'backend'
$outputRoot = Join-Path $projectRoot 'dist'
$zipPath = Join-Path $outputRoot ($ReleaseName + '.zip')
$helper = & (Join-Path $PSScriptRoot 'new_staging_artisan_helper.ps1') -ReleaseId '20260910-hr-v2'
$helperSource = Get-Content -LiteralPath $helper -Raw
$token = [regex]::Match($helperSource, '\$expectedToken = ''([^'']+)''').Groups[1].Value
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
if (Test-Path -LiteralPath $zipPath) { throw "Release already exists: $zipPath" }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($zipPath, [IO.Compression.ZipArchiveMode]::Create)
try {
    $directories = @('app', 'bootstrap', 'config', 'database/migrations', 'database/seeders', 'database/factories', 'public', 'resources', 'routes', 'vendor')
    $files = @('artisan', 'composer.json', 'composer.lock', 'package.json', 'vite.config.js')
    $rootPrefix = [IO.Path]::GetFullPath($backendRoot).TrimEnd('\') + '\'
    $sourceFiles = @(
        foreach ($directory in $directories) {
            Get-ChildItem -LiteralPath (Join-Path $backendRoot $directory) -Recurse -File
        }
        foreach ($file in $files) { Get-Item -LiteralPath (Join-Path $backendRoot $file) }
    )
    foreach ($source in $sourceFiles) {
        $entry = $source.FullName.Substring($rootPrefix.Length).Replace('\', '/')
        if ($entry -like 'public/storage/*' -or $entry -like 'bootstrap/cache/*.php' -or
            $entry -match '^public/.*(?:once|diagnos|setup|seed-demo).*\.php$') { continue }
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $source.FullName, $entry, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $archive,
        (Join-Path $projectRoot 'deploy/staging-artisan-once-20260910-hr-v2.php'),
        'public/staging-artisan-once-20260910-hr-v2.php',
        [IO.Compression.CompressionLevel]::Optimal
    ) | Out-Null
    $readmeEntry = $archive.CreateEntry('DEPLOY-2026-09-10.txt')
    $writer = [IO.StreamWriter]::new($readmeEntry.Open())
    try {
        $writer.Write(@"
Folony Activity - 10 September 2026

Paket update ROOT Laravel (flat). Extract ke root Laravel server staging:
/home/folony-staging-absent/htdocs/staging-absent.folony.co.id
Root yang benar berisi artisan, app, routes, dan file .env server.
Pertahankan .env serta storage server. Paket tidak menyertakan database lokal,
.env, upload pengguna, atau cache konfigurasi. Satu helper artisan staging
untuk deploy ini disertakan di folder public.

Sesudah extract, buka link ini lalu klik Jalankan Artisan Staging:
https://staging-absent.folony.co.id/staging-artisan-once-20260910-hr-v2.php?token=$token
Link baru tersedia setelah file helper diupload. Membuka link saja menampilkan
halaman; tombol menjalankan migrate --force, optimize:clear dan storage:link
jika link belum ada. Tunggu hasil DONE. Helper menghapus dirinya setelah sukses
dan menyimpan penanda selesai di storage/framework agar tidak berjalan ulang.

Alternatif bila memakai terminal, jalankan dari root Laravel:
php artisan migrate --force
php artisan optimize:clear
php artisan storage:link

Jika storage link sudah ada, pertahankan link tersebut. Pastikan storage dan
bootstrap/cache dapat ditulis oleh PHP. Jangan menjalankan migrate:fresh atau
seeder demo pada database yang sudah berisi data pengguna.

Menu HR: https://staging-absent.folony.co.id/admin/employee-activities
Nama menu: Aktifitas Karyawan
API mobile: GET/POST /api/employee-activities (login wajib)
HR melihat ringkasan per karyawan per tanggal mulai, waktu mulai/update/selesai
hingga detik, total durasi semua sesi tanpa jeda, dan tombol Detail semua update
beserta foto. Sesi lintas tengah malam tetap masuk tanggal mulai.
Monitoring Jaringan kini memuat peta satelit, cluster titik UKM/Mitra, popup
menuju detail, layar penuh, dan filter yang sama dengan tabel. Seluruh titik
berkoordinat valid dimuat bertahap; data tanpa koordinat tetap ada di tabel.
Peta menggunakan Leaflet 1.9.4 dan MarkerCluster 1.5.3 yang dibundel lokal.
Citra satelit Esri dan tile jalan OpenStreetMap memerlukan koneksi internet.
Perubahan paket ini hanya web/backend. APK staging sebelumnya tetap kompatibel.
Update lama pada versi sebelum perbaikan hanya ada di memori aplikasi dan tidak
pernah dikirim ke server, sehingga tidak dapat dimunculkan kembali oleh migrasi.

APK pasangan: FolonyActivity-staging-2026-09-10.apk
Version: 0.1.1-staging / 20260910
Backend: https://staging-absent.folony.co.id/api

Verifikasi setelah deploy:
1. Login karyawan, Mulai kerja, Simpan update dengan foto, Pekerjaan selesai.
2. Buka ulang aplikasi: riwayat dan status tetap sesuai server.
3. Login HR, buka Aktifitas Karyawan, cek semua update dan export CSV.
4. Heatmap: lokasi perangkat, titik terdekat, radius 500m/1km/2km, detail titik.
5. Face ID: wajah di tengah, capture otomatis, lanjutkan verifikasi server.
"@)
    } finally { $writer.Dispose() }
} finally { $archive.Dispose() }
Get-Item -LiteralPath $zipPath | Select-Object FullName, Length
Get-FileHash -LiteralPath $zipPath -Algorithm SHA256
