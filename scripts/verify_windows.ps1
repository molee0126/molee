param([string]$ValidationDirectory)
$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $PSScriptRoot
if (-not $ValidationDirectory) {
  $pointer = Join-Path $sourceRoot '.tooling/validation-root.txt'
  $ValidationDirectory = if (Test-Path -LiteralPath $pointer) { (Get-Content -LiteralPath $pointer -Raw).Trim() } else { Join-Path ([IO.Path]::GetTempPath()) 'FaceAI-validation' }
}
$validationRoot = [IO.Path]::GetFullPath($ValidationDirectory)
if ($validationRoot -match '[^\x00-\x7F]') { throw '请选择全英文验证目录以避开 Windows Flutter 路径兼容问题。' }
if ($validationRoot -eq [IO.Path]::GetFullPath($sourceRoot)) { throw '验证目录必须与源码目录不同。' }
New-Item -ItemType Directory -Force -Path $validationRoot,(Join-Path $validationRoot '.tooling') | Out-Null
foreach ($name in @('lib','test','android','ios','scripts','pubspec.yaml','pubspec.lock','analysis_options.yaml','.flutter-version','.metadata')) {
  Copy-Item -LiteralPath (Join-Path $sourceRoot $name) -Destination $validationRoot -Recurse -Force
}
$toolingPointer = Join-Path $sourceRoot '.tooling/tooling-root.txt'
if (Test-Path -LiteralPath $toolingPointer) {
  Copy-Item -LiteralPath $toolingPointer -Destination (Join-Path $validationRoot '.tooling/tooling-root.txt') -Force
}
Push-Location -LiteralPath $validationRoot
try {
  & '.\scripts\flutter.ps1' pub get
  if ($LASTEXITCODE -ne 0) { throw '依赖解析失败' }
  & '.\scripts\flutter.ps1' analyze
  if ($LASTEXITCODE -ne 0) { throw '静态分析失败' }
  & '.\scripts\flutter.ps1' test --reporter expanded
  if ($LASTEXITCODE -ne 0) { throw '测试失败' }
} finally { Pop-Location }
Write-Output "验证完成，源码仍在 $sourceRoot"
