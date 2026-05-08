Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

& '.\tools\flutter\bin\flutter.bat' build apk --debug `
  --dart-define=HEX_ENABLE_REMOTE_WORKFLOW=true `
  --dart-define=HEX_BACKEND_BASE_URL=https://activity.foodcolony.com/api
