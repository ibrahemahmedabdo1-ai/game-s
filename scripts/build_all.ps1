# Windows helper: builds debug APKs for all games. Requires Flutter, Android SDK and Git Bash (bash on PATH).
param([string]$Mode = "apk-debug")
$root = Split-Path -Parent $PSScriptRoot
Get-ChildItem "$root/apps" -Directory | ForEach-Object {
  bash "$root/scripts/ci_build.sh" $_.Name $Mode
  if ($LASTEXITCODE -ne 0) { throw "Build failed for $($_.Name)" }
}
Write-Host "Outputs in $root/release"
