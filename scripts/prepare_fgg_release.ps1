param([string]$ReleaseName = 'FolonyActivity-FULL-ui-touchup-2026-09-16')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$backendRoot = Join-Path $projectRoot 'backend'
$zipPath = Join-Path $projectRoot ('dist/' + $ReleaseName + '.zip')
if (Test-Path -LiteralPath $zipPath) { throw "Release already exists: $zipPath" }
$helperName = 'staging-artisan-once-20260916-ui-touchup.php'
$helper = Join-Path $projectRoot ('deploy/' + $helperName)
if (-not (Test-Path -LiteralPath $helper)) {
    $helper = & (Join-Path $PSScriptRoot 'new_staging_artisan_helper.ps1') -ReleaseId '20260916-ui-touchup'
}
New-Item -ItemType Directory -Path (Join-Path $projectRoot 'dist') -Force | Out-Null
$helperSource = Get-Content -LiteralPath $helper -Raw
$token = [regex]::Match($helperSource, '\$expectedToken = ''([^'']+)''').Groups[1].Value
if (-not $token) { throw 'Missing deployment helper token' }
$link = 'https://staging-absent.folony.co.id/' + $helperName + '?token=' + $token
$instructions = @"
Folony Activity FULL BACKEND - STAGING - 16 September 2026

Extract ZIP into the existing Laravel ROOT (contains artisan and .env).
Preserve the server .env, original APP_KEY, storage, and database. If deleted, restore these from backup.
This FULL package contains code, vendor, migrations, web assets, and empty storage directories; no secrets or user uploads.
Do not regenerate APP_KEY on an existing database. Point the web root at public, and make storage/bootstrap/cache writable.
Set FGG_ENVIRONMENT=staging in the staging server .env BEFORE running Artisan.
FGG login and all shipping requests use https://dev.foodukm.com/app/.

After upload, open this helper link and press Jalankan Artisan Staging:
$link
GET only previews; POST runs migrate --force, optimize:clear, storage:link if needed.
The helper is staging-host restricted and deletes itself after successful use.
Alternatively: php artisan optimize:clear; php artisan migrate --force; php artisan config:cache

Install companion APK FolonyActivity-staging-UI-2026-09-16-v9.apk after backend deployment.
NEW UI: collapsed work update history; FGG daily-work card hidden; shipping dashboard restricted to FGG; mobile expandable sections start closed. HR navigation can be hidden, filters are collapsible, and survey catalogs start closed.
Successful delivery photos are stored privately and viewable by HR in daily field activity details. Install APK v9 for the UI touch-up changes.
Older shipments without locally saved proof show Foto bukti belum tersedia.
Attendance monitoring and CSV group per employee/work date, with a detail page and completed-session durations.
Home FGG Pengiriman is visible only for role FGG.
Deploy backend and run migrations BEFORE using the new APK delivery journey controls.
Start journey opens Google Maps directions to senders_address; Arrive records server time and fresh GPS.
New APK requires recorded arrival before sending photo proof. Reopening directions never resets start time.
Travel duration is manual start-to-arrival, not a Google ETA or background GPS track.
Successful deliveries include this duration in field activity. Legacy shipments retain unknown duration.
OSM 403 referrer fix is included on network and daily-route maps.
Mobile Heatmaps uses OpenStreetMap street map only. Web Monitoring Jaringan still has its satellite option.
Field activity is grouped by person/date, with a detail page, chronological markers and straight-line distances.
Visit durations are merged when overlapping; transactions without duration remain unknown.
Fresh phone GPS required for receive/send; stored with accuracy in field activity.
Older records retain unknown location; GPS data is never invented for old transactions.
Dashboard counts every API history page for pending (1) and sent (2), across all time.
Satellite mode overlays Esri place labels and available administrative boundaries.
Boundary detail follows Esri coverage and is not a complete village-boundary dataset.
Shipping filters: Siap dikirim (1), Sudah dikirim (2).
Successful receive/send reports now appear in /admin/network-activities.
Migration removes exact automatic FGG duplicates from employee activities,
preserving their source operations and all manual work entries.
APK points to https://staging-absent.folony.co.id/api.
Open Home > FGG Pengiriman > Hubungkan > select HUB.
Check DST, DPP details, shipment search/status/pagination, and order details.
Use an explicitly designated staging shipment to test receive and photo delivery.
Live GETs and duplicate POST rejections were verified on staging (DST 152 / order 5361).
Successful shipping POSTs are covered by automated API simulation tests.
Multi-HUB accounts remain blocked until FGG provides a hub-selection API contract.

Production deployment requires FGG_ENVIRONMENT=production, APP_ENV=production,
APP_URL=https://absent.folony.co.id and a production APK. Do not upload this
staging-only helper to production. See FGG-INTEGRATION.md for operational details.
"@
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($zipPath, [IO.Compression.ZipArchiveMode]::Create)
try {
    $rootPrefix = [IO.Path]::GetFullPath($backendRoot).TrimEnd('\') + '\'
    $sourceFiles = @(
        foreach ($directory in @('app','bootstrap','config','database/migrations','database/seeders','database/factories','public','resources','routes','vendor')) {
            Get-ChildItem -LiteralPath (Join-Path $backendRoot $directory) -Recurse -File
        }
        foreach ($file in @('.env.example','artisan','composer.json','composer.lock','package.json','vite.config.js')) {
            Get-Item -LiteralPath (Join-Path $backendRoot $file)
        }
    )
    foreach ($source in $sourceFiles) {
        $entry = $source.FullName.Substring($rootPrefix.Length).Replace('\','/')
        if ($entry -like 'public/storage/*' -or $entry -like 'bootstrap/cache/*.php' -or
            $entry -match '^public/.*(?:once|diagnos|setup|seed-demo).*\.php$') { continue }
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$source.FullName,$entry,[IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$helper,('public/'+$helperName),[IO.Compression.CompressionLevel]::Optimal) | Out-Null
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,(Join-Path $projectRoot 'docs/FGG-INTEGRATION.md'),'FGG-INTEGRATION.md',[IO.Compression.CompressionLevel]::Optimal) | Out-Null
    foreach ($dir in @('bootstrap/cache/','storage/app/private/','storage/app/public/','storage/framework/cache/data/','storage/framework/sessions/','storage/framework/views/','storage/logs/')) {
        $archive.CreateEntry($dir) | Out-Null
    }
    $entry = $archive.CreateEntry('DEPLOY-FGG.txt')
    $writer = [IO.StreamWriter]::new($entry.Open())
    try { $writer.Write($instructions) } finally { $writer.Dispose() }
} finally { $archive.Dispose() }
[IO.File]::WriteAllText((Join-Path $projectRoot 'dist/DEPLOY-ui-touchup-2026-09-16.txt'),$instructions)
Get-Item -LiteralPath $zipPath | Select-Object Name,Length
