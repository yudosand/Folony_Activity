param([string]$ReleaseId = '20260921', [string]$ReleaseName = 'FolonyActivity-FULL-PRODUCTION-2026-09-21')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($ReleaseId -notmatch '^[a-zA-Z0-9-]+$') {throw 'Invalid release id'}
$root = Split-Path -Parent $PSScriptRoot
$backend = Join-Path $root 'backend'
$dist = Join-Path $root 'dist'
$zipPath = Join-Path $dist ($ReleaseName + '.zip')
if (Test-Path -LiteralPath $zipPath) {throw 'Release already exists; choose a new release name'}
New-Item -ItemType Directory -Path $dist -Force | Out-Null
$stage = Join-Path $root ('.tooling/production-package-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage -Force | Out-Null
$prefix = [IO.Path]::GetFullPath($backend).TrimEnd('\') + '\'
foreach ($directory in @('app','bootstrap','config','database/migrations','database/seeders','database/factories','public','resources','routes')) {
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $backend $directory) -Recurse -Force -File) {
        $relative = $file.FullName.Substring($prefix.Length).Replace('\','/')
        if ($relative -like 'public/storage/*' -or $relative -like 'bootstrap/cache/*.php' -or
            $relative -match '^public/.*(?:once|diagnos|setup|seed-demo).*\.php$') {continue}
        $target = Join-Path $stage $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $target
    }
}
foreach ($file in @('artisan','composer.json','composer.lock','package.json','vite.config.js')) {
    Copy-Item -LiteralPath (Join-Path $backend $file) -Destination (Join-Path $stage $file)
}
foreach ($dir in @('bootstrap/cache','storage/app/private','storage/app/public','storage/framework/cache/data','storage/framework/sessions','storage/framework/views','storage/logs')) {
    New-Item -ItemType Directory -Path (Join-Path $stage $dir) -Force | Out-Null
}
Push-Location $stage
try {
    & composer install --no-dev --prefer-dist --optimize-autoloader --no-scripts --no-interaction
    if ($LASTEXITCODE -ne 0) {throw 'Production Composer install failed'}
    & composer check-platform-reqs --no-dev
    if ($LASTEXITCODE -ne 0) {throw 'Local PHP platform check failed'}
} finally {Pop-Location}
$bytes = New-Object byte[] 24
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
try {$rng.GetBytes($bytes)} finally {$rng.Dispose()}
$token = -join ($bytes | ForEach-Object {$_.ToString('x2')})
$helperName = 'production-artisan-once-' + $ReleaseId + '.php'
$template = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'templates/production-artisan-once.php.template') -Raw
$helper = $template.Replace('__DEPLOY_TOKEN__',$token).Replace('__DEPLOY_RELEASE__',$ReleaseId)
[IO.File]::WriteAllText((Join-Path $stage ('public/'+$helperName)),$helper)
$link = 'https://absent.folony.co.id/'+$helperName+'?token='+$token
$commit = (& git -C $root rev-parse HEAD).Trim()
$instructions = @"
FOLONY ACTIVITY - FULL PRODUCTION - 21 September 2026
Application checkpoint: $commit
APK: FolonyActivity-production-0.1.12-20260926.apk (instal langsung, ARM64)

Paket ini full backend beserta vendor production (Composer --no-dev).
Tidak berisi .env server, database, foto/upload, cache lokal atau helper staging.

URUTAN DEPLOY
1. Backup database, .env asli, storage, dan kode production sebelumnya di luar folder public.
2. Jadwalkan maintenance dan hentikan transaksi sementara. Jika ada terminal: php artisan down
3. Upload/extract ZIP langsung ke ROOT Laravel production:
   /home/folony-absent/htdocs/absent.folony.co.id
   artisan, app, vendor, public harus sejajar dengan .env dan storage.
   Jika file manager membuat folder tambahan, pindahkan seluruh isinya; pastikan tidak ada nama *_copy.
   Pertahankan .env, APP_KEY asli, database dan seluruh isi storage. Jangan menjalankan key:generate.
4. Di .env production, pastikan:
   APP_ENV=production
   APP_DEBUG=false
   APP_URL=https://absent.folony.co.id
   FGG_ENVIRONMENT=production
   Pertahankan DB_*, APP_KEY, Firebase, mail dan pengaturan layanan server yang sudah benar.
   APP_URL tidak memakai trailing slash. Document root website harus mengarah ke public.
   storage dan bootstrap/cache harus writable oleh user PHP. PHP minimal 8.2 beserta extension yang dibutuhkan Composer.
5. Hapus hanya file bootstrap/cache/config.php jika tersedia agar .env baru terbaca.
   Pemeriksaan kelengkapan opsional melalui terminal: sha256sum -c FILE-MANIFEST.sha256 --quiet
6. Buka link privat berikut lalu tekan Jalankan Artisan Production:
   $link
   GET hanya pratinjau. POST memeriksa environment, lalu menjalankan migrate --force,
   optimize:clear dan storage:link bila diperlukan. Tunggu DONE; helper akan menghapus dirinya.
   Alternatif SSH: php artisan optimize:clear; php artisan migrate --force; php artisan storage:link
7. Jika tersedia SSH: php artisan config:cache; php artisan queue:restart; php artisan up
   Jika maintenance dilakukan lewat panel, aktifkan kembali website melalui panel.
8. Cek login HR, laporan harian, filter/sidebar, foto bukti, peta, lalu install APK production.
   Akun FGG production perlu dihubungkan ulang dan memilih HUB. Token staging tidak digunakan.
   FGG production menggunakan https://api.foodukm.com/app/; aplikasi memakai https://absent.folony.co.id/api.
   Uji transaksi production hanya memakai transaksi yang memang disetujui untuk diproses.

CATATAN MIGRASI DAN ROLLBACK
Migrasi membuat tabel/kolom aktivitas, FGG, GPS, perjalanan dan foto bukti.
Migrasi 000002 menghapus duplikat laporan FGG otomatis yang cocok persis dari aktivitas karyawan;
source operasi dan aktivitas manual tetap disimpan. Jangan menjalankan migrate:fresh atau db:seed.
Jika deploy gagal, pertahankan maintenance, pulihkan kode dan .env backup. Pemulihan database
memerlukan backup sebelum migrasi dan pertimbangan transaksi baru; jangan rollback database secara membabi buta.
Simpan storage/app/private untuk foto bukti dan semua upload lama saat backup/deploy.

APK memakai application ID yang sama dengan staging dan production lama.
Install production menggantikan aplikasi dengan ID tersebut; bila sebelumnya memakai staging,
logout sebelum berpindah agar sesi lama tidak terbawa. Tidak ada instal otomatis APK production oleh proses persiapan ini.
"@
[IO.File]::WriteAllText((Join-Path $stage 'DEPLOY-PRODUCTION.txt'),$instructions)
[IO.File]::WriteAllText((Join-Path $dist 'DEPLOY-PRODUCTION-2026-09-21.txt'),$instructions)
$lines = foreach($file in Get-ChildItem -LiteralPath $stage -Recurse -Force -File) {
    $name = $file.FullName.Substring($stage.Length+1).Replace('\','/')
    (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $name
}
[IO.File]::WriteAllText((Join-Path $stage 'FILE-MANIFEST.sha256'),($lines -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($stage,$zipPath,[IO.Compression.CompressionLevel]::Optimal,$false)
Write-Output ('Stage: '+$stage)
Get-Item -LiteralPath $zipPath | Select-Object Name,Length
