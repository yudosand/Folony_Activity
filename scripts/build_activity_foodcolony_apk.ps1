param([string]$VersionName = '0.1.12', [int]$VersionCode = 20260926)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

& '.\tools\flutter\bin\flutter.bat' build apk --release --target-platform android-arm64 `
  --build-name=$VersionName --build-number=$VersionCode `
  --dart-define=HEX_ENABLE_REMOTE_WORKFLOW=true `
  --dart-define=HEX_BACKEND_BASE_URL=https://absent.folony.co.id/api `
  --dart-define=HEX_ENABLE_DEMO_MODE=false `
  --dart-define=HEX_APP_ENV_LABEL=PRODUCTION

if ($LASTEXITCODE -ne 0) { throw 'Production APK build failed' }
New-Item -ItemType Directory -Path (Join-Path $projectRoot 'dist') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'build/app/outputs/flutter-apk/app-release.apk') `
  -Destination (Join-Path $projectRoot ('dist/FolonyActivity-production-' + $VersionName + '-' + $VersionCode + '.apk')) -Force
