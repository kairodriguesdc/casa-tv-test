# Downloads the latest CASA Test build from GitHub and installs it on the TV.
. (Join-Path $PSScriptRoot 'common.ps1')

Get-Repo
Connect-Tv

Say 'Downloading the latest build...'
$apk = Join-Path $DATA 'casa-test.apk'
try {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/$REPO/releases/download/latest/casa-test.apk" -OutFile $apk
} catch { Fail "couldn't download the build. Is the GitHub build finished, and the repository public?" }

Say 'Installing on the TV...'
$out = (Adb install -r $apk) -join "`n"
if ($out -notmatch 'Success') {
  if ($out -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE|signatures') {
    Adb uninstall $PKG | Out-Null
    $out = (Adb install $apk) -join "`n"
  }
  if ($out -notmatch 'Success') { Fail "the TV refused the install: $out" }
}

Adb shell pm grant $PKG android.permission.RECORD_AUDIO | Out-Null

# Switch on the test-3 helper, keeping whatever accessibility services the TV already has.
$bServices = Join-Path $DATA 'backup-services.txt'
$bEnabled  = Join-Path $DATA 'backup-enabled.txt'
if (-not (Test-Path $bServices)) {
  Set-Content -Path $bServices -Value (TvShell settings get secure enabled_accessibility_services)
  Set-Content -Path $bEnabled  -Value (TvShell settings get secure accessibility_enabled)
}
$cur = TvShell settings get secure enabled_accessibility_services
if ((":$cur:") -notlike "*:${SVC}:*") {
  if (-not $cur -or $cur -eq 'null') { $new = $SVC } else { $new = "${cur}:$SVC" }
  Adb shell "settings put secure enabled_accessibility_services '$new'" | Out-Null
}
Adb shell settings put secure accessibility_enabled 1 | Out-Null

Adb logcat -c | Out-Null
Adb shell am start -n "$PKG/.MainActivity" | Out-Null

Say @'
Done. CASA Test is open on the TV.

On the TV:
  1. Press the mic button, then hold it for a second.
  2. Press the mic button again and say "add a note: buy milk".
     Try a phrase in French and one in Portuguese too.
  3. Press Home, open any app, then press the mic button.
  4. Choose Run smoothness test and wait 20 seconds.

Then double-click "2 Get CASA Test results".

While CASA Test is installed, the mic button opens it instead of Google Assistant.
'@
Finish 0
