Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$backendRoot = Join-Path $projectRoot 'backend'
$deployRoot = Join-Path $projectRoot 'deploy'
$zipPath = Join-Path $deployRoot 'folony-laravel-clean-root.zip'
$stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("folony-clean-root-" + [System.Guid]::NewGuid().ToString('N'))

function Copy-ItemSafe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
}

New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null

$directories = @(
    'app',
    'bootstrap',
    'config',
    'database',
    'public',
    'resources',
    'routes',
    'vendor'
)

$files = @(
    '.editorconfig',
    '.gitattributes',
    '.gitignore',
    'artisan',
    'composer.json',
    'composer.lock',
    'package.json',
    'phpunit.xml',
    'README.md',
    'vite.config.js'
)

foreach ($directory in $directories) {
    Copy-ItemSafe -Source (Join-Path $backendRoot $directory) -Destination (Join-Path $stageRoot $directory)
}

foreach ($file in $files) {
    Copy-ItemSafe -Source (Join-Path $backendRoot $file) -Destination (Join-Path $stageRoot $file)
}

# Never deploy local Laravel cache files to production.
$bootstrapCacheRoot = Join-Path $stageRoot 'bootstrap\cache'
if (Test-Path -LiteralPath $bootstrapCacheRoot) {
    Get-ChildItem -LiteralPath $bootstrapCacheRoot -File -Filter '*.php' | Remove-Item -Force
}

# One-time emergency scripts are useful separately, but must not ride inside normal recovery deploys.
Get-ChildItem -LiteralPath (Join-Path $stageRoot 'public') -File -Filter '*-once.php' -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -LiteralPath (Join-Path $stageRoot 'public') -File -Filter 'diagnose-500-once.php' -ErrorAction SilentlyContinue | Remove-Item -Force

$readmePath = Join-Path $stageRoot 'RECOVERY_DEPLOY_README.txt'
@"
Folony Activity clean root recovery package

ZIP ini berisi file root Laravel secara FLAT, bukan folder pembungkus.

JANGAN upload/extract di folder config, public, bootstrap, atau subfolder lain.
Upload/extract hanya di:
/home/folony-absent/htdocs/absent.folony.co.id

Paket ini TIDAK membawa:
- .env
- storage/
- bootstrap/cache/*.php
- one-time helper scripts

Setelah extract:
1. Pastikan /public/index.php adalah front controller Laravel.
2. Pastikan /bootstrap/app.php ada.
3. Pastikan /bootstrap/cache hanya berisi .gitignore.
4. Reload https://absent.folony.co.id/admin/login
"@ | Set-Content -LiteralPath $readmePath

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory(
    $stageRoot,
    $zipPath,
    [System.IO.Compression.CompressionLevel]::Optimal,
    $false
)

Remove-Item -LiteralPath $stageRoot -Recurse -Force

Write-Host "Clean root recovery zip ready at: $zipPath"
