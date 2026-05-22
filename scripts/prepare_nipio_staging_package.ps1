Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$backendRoot = Join-Path $projectRoot 'backend'
$deployRoot = Join-Path $projectRoot 'deploy\folony-27-112-79-213.nip.io'
$backendDeployRoot = Join-Path $deployRoot 'backend-app'
$publicDeployRoot = Join-Path $deployRoot 'public_html'

function Reset-DeployDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedRoot
    )

    $resolvedRoot = [System.IO.Path]::GetFullPath($ExpectedRoot)
    $resolvedPath = [System.IO.Path]::GetFullPath($Path)

    if (-not $resolvedPath.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to modify path outside deploy root: $resolvedPath"
    }

    if (Test-Path -LiteralPath $resolvedPath) {
        Remove-Item -LiteralPath $resolvedPath -Recurse -Force
    }

    New-Item -ItemType Directory -Path $resolvedPath | Out-Null
}

Reset-DeployDirectory -Path $backendDeployRoot -ExpectedRoot $deployRoot
Reset-DeployDirectory -Path $publicDeployRoot -ExpectedRoot $deployRoot

$excludeDirectories = @(
    '.git',
    '.idea',
    '.vscode',
    'node_modules',
    'tests'
)

$excludeFiles = @(
    '.env',
    '.env.mysql.example',
    'database.sqlite'
)

Get-ChildItem -LiteralPath $backendRoot -Force | ForEach-Object {
    if ($_.Name -eq 'public') {
        return
    }

    if ($excludeDirectories -contains $_.Name) {
        return
    }

    if (-not $_.PSIsContainer -and $excludeFiles -contains $_.Name) {
        return
    }

    $destination = Join-Path $backendDeployRoot $_.Name

    if ($_.PSIsContainer) {
        Copy-Item -LiteralPath $_.FullName -Destination $destination -Recurse -Force
    } else {
        Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
    }
}

Get-ChildItem -LiteralPath (Join-Path $backendRoot 'public') -Force | ForEach-Object {
    $destination = Join-Path $publicDeployRoot $_.Name

    if ($_.PSIsContainer) {
        Copy-Item -LiteralPath $_.FullName -Destination $destination -Recurse -Force
    } else {
        Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
    }
}

Copy-Item -LiteralPath (Join-Path $backendRoot '.env.nipio.staging.example') -Destination (Join-Path $backendDeployRoot '.env') -Force

$indexPath = Join-Path $publicDeployRoot 'index.php'
$indexContent = Get-Content -LiteralPath $indexPath -Raw
$indexContent = $indexContent.Replace("__DIR__.'/../storage/framework/maintenance.php'", "__DIR__.'/../backend-app/storage/framework/maintenance.php'")
$indexContent = $indexContent.Replace("__DIR__.'/../vendor/autoload.php'", "__DIR__.'/../backend-app/vendor/autoload.php'")
$indexContent = $indexContent.Replace("__DIR__.'/../bootstrap/app.php'", "__DIR__.'/../backend-app/bootstrap/app.php'")
Set-Content -LiteralPath $indexPath -Value $indexContent -NoNewline

$readmePath = Join-Path $deployRoot 'README.txt'
@"
Deploy package untuk staging host folony-27-112-79-213.nip.io

Struktur upload yang disarankan:
- upload isi folder public_html ke document root host folony-27-112-79-213.nip.io
- upload folder backend-app ke sibling document root

Paket ini memakai template .env.nipio.staging.example
Penting:
1. SESSION_DOMAIN harus tetap kosong
2. SANCTUM_STATEFUL_DOMAINS harus tetap folony-27-112-79-213.nip.io
3. edit DB_PASSWORD dan APP_KEY
4. jalankan migrate --force, storage:link, optimize:clear

Login web admin nanti ada di:
- /admin/login
"@ | Set-Content -LiteralPath $readmePath

Write-Host "Deploy package ready at: $deployRoot"
