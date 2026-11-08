# Puts the TV's settings back exactly as they were and uninstalls CASA Test.
. (Join-Path $PSScriptRoot 'common.ps1')

Connect-Tv

$bServices = Join-Path $DATA 'backup-services.txt'
$bEnabled  = Join-Path $DATA 'backup-enabled.txt'
if (Test-Path $bServices) {
  $old = (Get-Content $bServices -Raw).Trim()
  if (-not $old -or $old -eq 'null') {
    Adb shell settings delete secure enabled_accessibility_services | Out-Null
  } else {
    Adb shell "settings put secure enabled_accessibility_services '$old'" | Out-Null
  }
  $oldOn = ''
  if (Test-Path $bEnabled) { $oldOn = (Get-Content $bEnabled -Raw).Trim() }
  if (-not $oldOn -or $oldOn -eq 'null') {
    Adb shell settings delete secure accessibility_enabled | Out-Null
  } else {
    Adb shell settings put secure accessibility_enabled $oldOn | Out-Null
  }
  Remove-Item $bServices, $bEnabled -Force -ErrorAction SilentlyContinue
  Say 'TV settings restored.'
} else {
  # No backup: take only CASA Test's helper out of the list, keep everything else.
  $cur = TvShell settings get secure enabled_accessibility_services
  $new = (($cur -split ':') | Where-Object { $_ -and $_ -ne $SVC }) -join ':'
  if ($new -ne $cur) {
    if (-not $new) { Adb shell settings delete secure enabled_accessibility_services | Out-Null }
    else { Adb shell "settings put secure enabled_accessibility_services '$new'" | Out-Null }
  }
}

Adb uninstall $PKG | Out-Null
Say 'CASA Test is removed. The mic button opens Google Assistant again.'
Finish 0
