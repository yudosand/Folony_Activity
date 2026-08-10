Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

& '.\tools\flutter\bin\flutter.bat' build apk --release --target-platform android-arm64 `
  --dart-define=HEX_ENABLE_REMOTE_WORKFLOW=true `
  --dart-define=HEX_BACKEND_BASE_URL=https://absent.folony.co.id/api `
  --dart-define=HEX_ENABLE_DEMO_MODE=false
