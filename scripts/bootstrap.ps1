$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolingRoot = Join-Path $projectRoot '.tooling'
$pointer = Join-Path $toolingRoot 'tooling-root.txt'
if (Test-Path -LiteralPath $pointer) { $toolingRoot = (Get-Content -LiteralPath $pointer -Raw).Trim() }
if (Test-Path -LiteralPath (Join-Path $toolingRoot 'flutter/bin/flutter.bat')) {
  & (Join-Path $PSScriptRoot 'flutter.ps1') --disable-analytics
  exit $LASTEXITCODE
}
if ($toolingRoot -match '[^\x00-\x7F]') { throw '请将源代码解压到英文路径后安装 Flutter，或使用已准备的云端 iOS 构建流程。' }
New-Item -ItemType Directory -Force -Path $toolingRoot | Out-Null
$version = (Get-Content -LiteralPath (Join-Path $projectRoot '.flutter-version') -Raw).Trim()
$releases = Invoke-RestMethod -Uri 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json'
$release = $releases.releases | Where-Object { $_.version -eq $version -and $_.channel -eq 'stable' } | Select-Object -First 1
if ($null -eq $release) { throw "未找到官方 Flutter $version 稳定版" }
$archive = Join-Path $toolingRoot 'flutter.zip'
if (-not (Test-Path -LiteralPath $archive)) { & curl.exe -L --fail --retry 2 --output $archive ($releases.base_url + '/' + $release.archive); if ($LASTEXITCODE -ne 0) { throw 'SDK 下载失败' } }
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLower() -ne $release.sha256) { throw 'SDK 校验失败，请移走 flutter.zip 后重试' }
if (-not (Test-Path -LiteralPath (Join-Path $toolingRoot 'flutter/bin/flutter.bat'))) {
  & tar.exe -xf $archive -C $toolingRoot
  if ($LASTEXITCODE -ne 0) { throw 'SDK 解压失败' }
}
& (Join-Path $PSScriptRoot 'flutter.ps1') --disable-analytics
