# Reads the test results from the TV and copies them, ready to paste into the chat.
. (Join-Path $PSScriptRoot 'common.ps1')

Connect-Tv

$log = @(Adb logcat -d -s CasaTest)
$result = ($log | Where-Object { $_ -match 'RESULT ' } | Select-Object -Last 1) -replace '^.*RESULT ', ''
$keys   = ($log | Where-Object { $_ -match 'KEY |WATCH ' } | Select-Object -Last 12 | ForEach-Object { $_ -replace '^.*CasaTest[^:]*: ', '' }) -join "`r`n"
$voice  = ($log | Where-Object { $_ -match 'VOICE ' -and $_ -match '"done"|"error"' } | Select-Object -Last 6 | ForEach-Object { $_ -replace '^.*VOICE ', '' }) -join "`r`n"
$model  = TvShell getprop ro.product.model

if (-not $result) { Fail 'no results yet. Run the tests on the TV first (CASA Test must be open).' }
if (-not $voice) { $voice = 'none' }
if (-not $keys) { $keys = 'none' }

$text = @"
CASA Test results - $(Get-Date -Format 'yyyy-MM-dd HH:mm') - TV $model

RESULT
$result

VOICE (latest)
$voice

BUTTONS (latest)
$keys
"@

$file = Join-Path ([Environment]::GetFolderPath('Desktop')) 'CASA Test results.txt'
Set-Content -Path $file -Value $text -Encoding UTF8
Set-Clipboard -Value $text
Say 'Results saved to your Desktop as "CASA Test results.txt" and copied.
Paste them into the chat with Claude.'
Finish 0
