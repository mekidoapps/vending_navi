$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
  $worktreeStatus = git status --porcelain
  if ($LASTEXITCODE -ne 0) {
    throw 'Could not verify the working tree state.'
  }
  if ($worktreeStatus) {
    throw 'Release candidate build requires a clean working tree.'
  }

  $sourceSha = git rev-parse HEAD
  if ($LASTEXITCODE -ne 0) {
    throw 'Could not resolve the build source SHA.'
  }

  $versionLine = Get-Content pubspec.yaml | Where-Object { $_ -match '^version:\s*\d+\.\d+\.\d+\+\d+\s*$' } | Select-Object -First 1
  if (-not $versionLine) {
    throw 'Could not resolve the canonical pubspec version.'
  }

  Write-Output "build_source_sha=$sourceSha"
  Write-Output "app_version=$(($versionLine -split ':', 2)[1].Trim())"

  & flutter build appbundle --release --dart-define=APP_ENTRY=v2
  if ($LASTEXITCODE -ne 0) {
    throw "Release candidate build failed with exit code $LASTEXITCODE."
  }

  $aabPath = Join-Path $repoRoot 'build/app/outputs/bundle/release/app-release.aab'
  if (-not (Test-Path $aabPath -PathType Leaf)) {
    throw 'Release candidate AAB was not found at the expected output path.'
  }

  Write-Output "aab_path=$aabPath"
  Write-Output "aab_sha256=$((Get-FileHash $aabPath -Algorithm SHA256).Hash.ToLowerInvariant())"
} finally {
  Pop-Location
}
