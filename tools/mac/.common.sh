#!/bin/bash
# Shared steps for the CASA Test scripts on a Mac. No AI, no Android SDK needed.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PKG="app.casa.test"
SVC="app.casa.test/.MicWatchService"
DATA="$HOME/Library/Application Support/CASA Test"
mkdir -p "${DATA}"

say() { printf '\n%s\n' "$*"; }
finish() {
  printf '\n'
  read -r -p "Press Return to close this window. " _
  exit "${1:-0}"
}
fail() { say "Stopped: $*"; finish 1; }

# GitHub repository that builds the app, from repo.txt next to the scripts (one level up).
repo() {
  local f="${HERE}/../repo.txt"
  [ -f "$f" ] || f="${HERE}/repo.txt"
  REPO="$(tr -d ' \r\n' < "$f" 2>/dev/null)"
  case "${REPO}" in
    ""|OWNER/*) fail "repo.txt doesn't name the GitHub repository yet." ;;
  esac
}

# adb: use one that's already installed, else download Google's official platform-tools once.
find_adb() {
  local c
  for c in "$(command -v adb 2>/dev/null)" "$HOME/Library/Android/sdk/platform-tools/adb" "${DATA}/platform-tools/adb"; do
    if [ -n "$c" ] && [ -x "$c" ]; then ADB="$c"; return 0; fi
  done
  say "Getting Google's adb tool (one time, about 15 MB)..."
  curl -fsSL -o "${DATA}/platform-tools.zip" "https://dl.google.com/android/repository/platform-tools-latest-darwin.zip" \
    || fail "couldn't download adb. Check the internet connection."
  unzip -qo "${DATA}/platform-tools.zip" -d "${DATA}" && rm -f "${DATA}/platform-tools.zip"
  ADB="${DATA}/platform-tools/adb"
  xattr -dr com.apple.quarantine "${DATA}/platform-tools" 2>/dev/null || true
  [ -x "${ADB}" ] || fail "adb didn't install."
}

# The TV's address, asked once and remembered.
tv_ip() {
  IP="$(cat "${DATA}/tv.txt" 2>/dev/null | tr -d ' \r\n')"
  if [ -z "${IP}" ]; then
    say "What is the TV's IP address? (TV Settings > Network & Internet > your Ethernet connection)"
    read -r -p "IP address: " IP
    IP="$(printf '%s' "${IP}" | tr -d ' ')"
    [ -n "${IP}" ] || fail "no IP address given."
    printf '%s\n' "${IP}" > "${DATA}/tv.txt"
  fi
  case "${IP}" in *:*) T="${IP}" ;; *) T="${IP}:5555" ;; esac
}

# Connect, and wait while the TV shows its "Allow debugging?" prompt.
connect() {
  find_adb
  tv_ip
  say "Connecting to the TV at ${T}..."
  "${ADB}" connect "${T}" >/dev/null 2>&1
  local i state
  for i in $(seq 1 30); do
    state="$("${ADB}" -s "${T}" get-state 2>/dev/null | tr -d '\r')"
    [ "${state}" = "device" ] && { say "Connected."; return 0; }
    if [ "${i}" -eq 2 ]; then
      say "If the TV asks \"Allow debugging?\", tick Always allow and choose OK."
    fi
    sleep 2
    "${ADB}" connect "${T}" >/dev/null 2>&1
  done
  rm -f "${DATA}/tv.txt"
  fail "the TV didn't answer. Check that it's on, that network debugging is on (Developer options), and the IP address. Run this again to re-enter the IP."
}

sh_tv() { "${ADB}" -s "${T}" shell "$@" 2>/dev/null | tr -d '\r'; }
