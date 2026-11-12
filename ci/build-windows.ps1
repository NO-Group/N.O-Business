# Builds the release Windows app into dist\:
#   NO-Business-<version>-windows.zip   portable folder
#   NO-Business-<version>.msix          installer
#
# Backend configuration and signing material come from the environment and
# are never written to the repository:
#   NOB_SUPABASE_URL, NOB_SUPABASE_ANON_KEY   backend (public client key only)
#   NOB_WINDOWS_PFX_BASE64                    code-signing certificate, base64
#   NOB_SIGNING_PASSWORD                      certificate password
#
# Without the signing values msix signs the installer with a throw-away test
# certificate, which Windows will not trust; use that build for testing only.
#
# Usage: pwsh ci/build-windows.ps1
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent
$workDir = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }
$flutterVersion = (Get-Content (Join-Path $PSScriptRoot "flutter-version") -Raw).Trim()

# Emits the end of a step's log as GitHub error annotations (in chunks,
# because one annotation is truncated at a few kilobytes), so the cause of a
# failure is visible on the run summary page.
function Write-FailureAnnotation {
  param([string]$Title, [string]$LogPath)
  $text = if (Test-Path $LogPath) { Get-Content $LogPath -Raw } else { "" }
  if (-not $text) { $text = "(no output)" }
  $chunk = 3800
  $max = 9
  if ($text.Length -gt $chunk * $max) { $text = $text.Substring($text.Length - $chunk * $max) }
  $count = [int][Math]::Ceiling($text.Length / $chunk)
  for ($i = 0; $i -lt $count; $i++) {
    $part = $text.Substring($i * $chunk, [Math]::Min($chunk, $text.Length - $i * $chunk))
    $body = $part.Replace("%", "%25").Replace("`r", "").Replace("`n", "%0A")
    Write-Host "::error title=$Title [$($i + 1)/$count]::$body"
  }
}

function Invoke-Checked {
  param([string]$Name, [scriptblock]$Command)
  $log = Join-Path $workDir (($Name -replace '[^A-Za-z0-9]', '-') + ".log")
  Write-Host "::group::$Name"
  # Native tools write progress to stderr; that must not abort the script.
  $previous = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  & $Command 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath $log | Out-Host
  $code = $LASTEXITCODE
  $ErrorActionPreference = $previous
  Write-Host "::endgroup::"
  if ($code -ne 0) {
    if ($env:GITHUB_ACTIONS) { Write-FailureAnnotation $Name $log }
    throw "$Name failed with exit code $code"
  }
  Write-Host "ok: $Name"
}

# --- Flutter (pinned in ci/flutter-version) ----------------------------------
$flutterDir = Join-Path $workDir "flutter-$flutterVersion"
if (-not (Test-Path (Join-Path $flutterDir "bin\flutter.bat"))) {
  git clone --quiet --depth 1 --branch $flutterVersion https://github.com/flutter/flutter.git $flutterDir
  if ($LASTEXITCODE -ne 0) { throw "Could not download Flutter $flutterVersion" }
}
$env:PATH = "$flutterDir\bin;$env:PATH"
flutter config --no-analytics 2>$null | Out-Null
flutter --version

# --- Build --------------------------------------------------------------------
Set-Location (Join-Path $repoRoot "app")
$pubspec = Get-Content "pubspec.yaml" -Raw
$match = [regex]::Match($pubspec, '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$')
if (-not $match.Success) { throw "Cannot read the version from app/pubspec.yaml" }
$buildName = $match.Groups[1].Value
$buildNumber = if ($env:GITHUB_RUN_NUMBER) { $env:GITHUB_RUN_NUMBER } else { $match.Groups[2].Value }

if (-not $env:NOB_SUPABASE_URL -or -not $env:NOB_SUPABASE_ANON_KEY) {
  Write-Host "::warning::NOB_SUPABASE_URL / NOB_SUPABASE_ANON_KEY are not set; this build opens on the 'not configured' screen."
}

# Each switch is one pre-expanded argument so PowerShell never splits
# --dart-define=KEY=VALUE at the equals signs.
$buildArgs = @(
  "--build-name=$buildName",
  "--build-number=$buildNumber",
  "--dart-define=APP_VERSION=$buildName+$buildNumber",
  "--dart-define=SUPABASE_URL=$($env:NOB_SUPABASE_URL)",
  "--dart-define=SUPABASE_ANON_KEY=$($env:NOB_SUPABASE_ANON_KEY)"
)
Invoke-Checked "flutter pub get" { flutter pub get }
Invoke-Checked "flutter build windows" { flutter build windows --release @buildArgs }

$out = "build\windows\x64\runner\Release"
if (-not (Test-Path (Join-Path $out "no_business.exe"))) { throw "no_business.exe was not produced" }

$dist = Join-Path $repoRoot "dist"
New-Item -ItemType Directory -Force -Path $dist | Out-Null

# Portable folder first, before the installer is written into the same folder.
$zip = Join-Path $dist "NO-Business-$buildName-windows.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path "$out\*" -DestinationPath $zip

# --- Installer ------------------------------------------------------------------
$msixArgs = @("--version", "$buildName.0")
$pfx = $null
if ($env:NOB_WINDOWS_PFX_BASE64 -and $env:NOB_SIGNING_PASSWORD) {
  $pfx = Join-Path $workDir "no-business-signing.pfx"
  [IO.File]::WriteAllBytes($pfx, [Convert]::FromBase64String($env:NOB_WINDOWS_PFX_BASE64))
  $msixArgs += @("--certificate-path", $pfx, "--certificate-password", $env:NOB_SIGNING_PASSWORD)
  Write-Host "Packaging with the release certificate."
} else {
  Write-Host "::warning::Windows signing secrets are not set; the installer is signed with a test certificate and is for testing only."
}
try {
  Invoke-Checked "msix installer" { dart run msix:create @msixArgs }
} finally {
  if ($pfx -and (Test-Path $pfx)) { Remove-Item $pfx -Force }
}
Copy-Item (Join-Path $out "NO-Business-Setup.msix") (Join-Path $dist "NO-Business-$buildName.msix") -Force

Get-ChildItem $dist | Format-Table Name, Length
