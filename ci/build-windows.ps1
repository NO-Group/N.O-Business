# ============================================================================
# MFSL Office - Windows build + publish (GitHub Actions).
#
# ALL CI logic lives here in ci/ so that .github/workflows/build-mfsl.yml
# never has to change: editing files under .github/workflows/ requires a
# GitHub token with the special "workflows" permission, while normal git
# pushes to ci/ work for everyone. Change the build HERE, not in the shim.
#
# What it does:
#   1. Installs Flutter (stable) by shallow clone - no setup action needed.
#   2. Builds the release EXE + MSIX installer (VS2022 is preinstalled).
#   3. Uploads the installer and a portable zip to the rolling GitHub Release
#      tagged "ci" as RAW assets. GitHub serves release assets byte-for-byte:
#      never re-zipped, never encrypted - no "password protected" errors, ever.
#
# Local usage: pwsh ci/build-windows.ps1   (needs Flutter prerequisites + gh)
# ============================================================================
$ErrorActionPreference = "Stop"

# Not strictly needed for the CMake/VS build, but pin JDK 17 when present so
# any Java-based tooling behaves the same as the Android job.
if ($env:JAVA_HOME_17_X64) { $env:JAVA_HOME = $env:JAVA_HOME_17_X64 }

# --- 1. Flutter (stable) -----------------------------------------------------
$flutter = Join-Path $env:RUNNER_TEMP "flutter"
if (-not (Test-Path (Join-Path $flutter "bin\flutter.bat"))) {
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git $flutter
}
$env:PATH = "$flutter\bin;$env:PATH"
flutter config --no-analytics 2>$null | Out-Null
flutter --version

# --- 2. Build -----------------------------------------------------------------
$repoRoot = Split-Path $PSScriptRoot -Parent
Set-Location (Join-Path $repoRoot "app")
# Read the SAME version as Android from pubspec.yaml and bake it into
# APP_VERSION. Previously Windows got no --dart-define at all, so the About
# screen and the update checker saw the stale 0.1.0+1 fallback.
$pubspecText = Get-Content "pubspec.yaml" -Raw
$versionMatch = [regex]::Match($pubspecText, '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+\+([0-9]+))\s*$')
if (-not $versionMatch.Success) { throw "Cannot read version from app/pubspec.yaml" }
$appVersion = $versionMatch.Groups[1].Value
$buildName = $appVersion -replace '\+.*$', ''
$buildNumber = $versionMatch.Groups[2].Value
$edgeText = Get-Content (Join-Path $repoRoot "supabase\functions\data-api\index.ts") -Raw
$edgeMatch = [regex]::Match($edgeText, "const APP_VERSION = '([^']+)'")
if (-not $edgeMatch.Success -or $edgeMatch.Groups[1].Value -ne $appVersion) {
  throw "App version drift: pubspec.yaml=$appVersion but data-api APP_VERSION=$($edgeMatch.Groups[1].Value)"
}
Write-Host "App version $appVersion"
flutter pub get
# Build each switch as a single pre-expanded argument so PowerShell never
# splits --dart-define=KEY=VALUE at the equals signs.
$buildNameArg = "--build-name=$buildName"
$buildNumberArg = "--build-number=$buildNumber"
$dartDefineArg = "--dart-define=APP_VERSION=$appVersion"
flutter build windows --release $buildNameArg $buildNumberArg $dartDefineArg

$OUT = "build\windows\x64\runner\Release"
Copy-Item "$OUT\mtek_inventory.exe" "$OUT\MFSL Office.exe"
if ($env:MFSL_WINDOWS_PFX_BASE64 -and $env:MFSL_SIGNING_PASSWORD) {
  $pfx = Join-Path $env:RUNNER_TEMP "mfsl-office-windows.pfx"
  [IO.File]::WriteAllBytes($pfx, [Convert]::FromBase64String($env:MFSL_WINDOWS_PFX_BASE64))
  Write-Host "Packaging with the persistent N.O Group self-signed certificate."
  dart run msix:create --certificate-path $pfx --certificate-password $env:MFSL_SIGNING_PASSWORD
} else {
  Write-Warning "Persistent Windows signing secrets are absent; msix will generate a temporary certificate."
  dart run msix:create
}
Copy-Item "$OUT\MFSL-Office-Setup.msix" "$OUT\MFSL.Inventory.Setup.msix"

# Portable zip - WE zip it ourselves; GitHub then serves it byte-for-byte
# (unlike artifacts, GitHub never adds its own wrapper around release assets).
$ZIP = Join-Path $env:RUNNER_TEMP "MFSL-Office-portable.zip"
if (Test-Path $ZIP) { Remove-Item $ZIP -Force }
Compress-Archive -Path "$OUT\*" -DestinationPath $ZIP

# --- 3. Publish to the rolling "ci" release (raw assets, no zip wrapper) ------
$TAG = "ci"
$MSIX = "$OUT\MFSL.Inventory.Setup.msix"
$sha = if ($env:GITHUB_SHA) { $env:GITHUB_SHA.Substring(0, 7) } else { "local" }
$ref = if ($env:GITHUB_REF_NAME) { $env:GITHUB_REF_NAME } else { "local" }
$stamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm 'UTC'")
$notes = Join-Path $env:RUNNER_TEMP "notes.md"
@"
Auto build ``$sha`` ($ref), $stamp.

These assets are RAW files - GitHub never re-zips release assets, so there is
nothing to extract and no "password protected" errors. Ever.

- ``MFSL.Inventory.Setup.msix`` - double-click to install (Windows).
- ``MFSL-Office-portable.zip`` - portable folder; run ``MFSL Office.exe`` inside it.
- ``MFSL.Inventory.apk`` - Android sideload (from the Android job).
"@ | Set-Content -Path $notes -Encoding utf8

$target = @()
if ($env:GITHUB_SHA) { $target = @("--target", $env:GITHUB_SHA) }

$ok = $false
foreach ($i in 1..3) {
  gh release view $TAG *> $null
  if ($LASTEXITCODE -ne 0) {
    gh release create $TAG @target --prerelease `
      --title "MFSL Office - auto builds (rolling)" `
      --notes-file $notes *> $null
  }
  gh release upload $TAG $MSIX $ZIP --clobber
  if ($LASTEXITCODE -eq 0) {
    # Refresh notes so the body always shows the latest build.
    gh release edit $TAG --notes-file $notes *> $null
    $ok = $true; break
  }
  Start-Sleep -Seconds 15
}
if (-not $ok) { throw "Could not upload assets to release $TAG" }
Write-Host "Published $MSIX and $ZIP to release $TAG"
