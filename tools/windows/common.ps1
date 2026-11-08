# Shared steps for the CASA Test scripts on Windows. No AI, no Android SDK needed.
$ErrorActionPreference = 'Continue'
$PKG  = 'app.casa.test'
$SVC  = 'app.casa.test/.MicWatchService'
$DATA = Join-Path $env:LOCALAPPDATA 'CASA Test'
New-Item -ItemType Directory -Force -Path $DATA | Out-Null

function Say($text) { Write-Host ''; Write-Host $text }
function Finish($code = 0) { Write-Host ''; Read-Host 'Press Enter to close this window' | Out-Null; exit $code }
function Fail($text) { Say "Stopped: $text"; Finish 1 }

function Get-Repo {
  $f = Join-Path $PSScriptRoot '..\repo.txt'
  if (-not (Test-Path $f)) { $f = Join-Path $PSScriptRoot 'repo.txt' }
  $script:REPO = ''
  if (Test-Path $f) { $script:REPO = (Get-Content $f -Raw).Trim() }
  if (-not $script:REPO -or $script:REPO -like 'OWNER/*') { Fail "repo.txt doesn't name the GitHub repository yet." }
}

# adb: use one that's already installed, else download Google's official platform-tools once.
function Find-Adb {
  $cands = @()
  $cmd = Get-Command adb.exe -ErrorAction SilentlyContinue
  if ($cmd) { $cands += $cmd.Source }
  $cands += (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe')
  $cands += (Join-Path $DATA 'platform-tools\adb.exe')
  foreach ($c in $cands) { if ($c -and (Test-Path $c)) { $script:ADB = $c; return } }
  Say "Getting Google's adb tool (one time, about 15 MB)..."
  $zip = Join-Path $DATA 'platform-tools.zip'
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -Uri 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' -OutFile $zip
    Expand-Archive -Force -Path $zip -DestinationPath $DATA
    Remove-Item $zip -Force
  } catch { Fail "couldn't download adb. Check the internet connection." }
  $script:ADB = Join-Path $DATA 'platform-tools\adb.exe'
  if (-not (Test-Path $script:ADB)) { Fail "adb didn't install." }
}

function Get-TvIp {
  $f = Join-Path $DATA 'tv.txt'
  $ip = ''
  if (Test-Path $f) { $ip = (Get-Content $f -Raw).Trim() }
  if (-not $ip) {
    Say "What is the TV's IP address? (TV Settings > Network & Internet > your Ethernet connection)"
    $ip = (Read-Host 'IP address').Trim()
    if (-not $ip) { Fail 'no IP address given.' }
    Set-Content -Path $f -Value $ip
  }
  if ($ip -like '*:*') { $script:T = $ip } else { $script:T = "${ip}:5555" }
}

function Adb { & $script:ADB -s $script:T @args 2>$null }
function TvShell { ((& $script:ADB -s $script:T shell @args 2>$null) -join "`n").Trim() }

# Connect, and wait while the TV shows its "Allow debugging?" prompt.
function Connect-Tv {
  Find-Adb
  Get-TvIp
  Say "Connecting to the TV at $script:T..."
  & $script:ADB connect $script:T 2>$null | Out-Null
  for ($i = 1; $i -le 30; $i++) {
    $state = ((& $script:ADB -s $script:T get-state 2>$null) -join '').Trim()
    if ($state -eq 'device') { Say 'Connected.'; return }
    if ($i -eq 2) { Say 'If the TV asks "Allow debugging?", tick Always allow and choose OK.' }
    Start-Sleep -Seconds 2
    & $script:ADB connect $script:T 2>$null | Out-Null
  }
  Remove-Item (Join-Path $DATA 'tv.txt') -Force -ErrorAction SilentlyContinue
  Fail "the TV didn't answer. Check that it's on, that network debugging is on (Developer options), and the IP address. Run this again to re-enter the IP."
}
