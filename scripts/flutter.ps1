param([Parameter(ValueFromRemainingArguments = $true)][string[]]$FlutterArgs)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolingRoot = Join-Path $projectRoot '.tooling'
$locationFile = Join-Path $toolingRoot 'tooling-root.txt'
if (Test-Path -LiteralPath $locationFile) { $toolingRoot = (Get-Content -LiteralPath $locationFile -Raw).Trim() }
$flutterExecutable = Join-Path $toolingRoot 'flutter/bin/flutter.bat'
if (-not (Test-Path -LiteralPath $flutterExecutable)) { throw '请先运行 scripts/bootstrap.ps1 或安装 Flutter SDK。' }
$env:APPDATA = Join-Path $toolingRoot 'appdata'
$env:LOCALAPPDATA = Join-Path $toolingRoot 'localappdata'
$env:PUB_CACHE = Join-Path $toolingRoot 'pub-cache'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:CI = 'true'
$env:TEMP = Join-Path $toolingRoot 'tmp'
$env:TMP = $env:TEMP
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA,$env:TEMP | Out-Null
Push-Location -LiteralPath $projectRoot
try { & $flutterExecutable @FlutterArgs; $resultCode = $LASTEXITCODE } finally { Pop-Location }
exit $resultCode


