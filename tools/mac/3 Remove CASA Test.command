#!/bin/bash
# Double-click: puts the TV's settings back exactly as they were and uninstalls CASA Test.
. "$(cd "$(dirname "$0")" && pwd)/.common.sh"

connect

if [ -f "$DATA/backup-services.txt" ]; then
  old="$(tr -d '\r\n' < "$DATA/backup-services.txt")"
  if [ -z "$old" ] || [ "$old" = "null" ]; then
    "$ADB" -s "$T" shell settings delete secure enabled_accessibility_services >/dev/null 2>&1
  else
    "$ADB" -s "$T" shell "settings put secure enabled_accessibility_services '$old'"
  fi
  oldon="$(tr -d '\r\n' < "$DATA/backup-enabled.txt" 2>/dev/null)"
  if [ -z "$oldon" ] || [ "$oldon" = "null" ]; then
    "$ADB" -s "$T" shell settings delete secure accessibility_enabled >/dev/null 2>&1
  else
    "$ADB" -s "$T" shell settings put secure accessibility_enabled "$oldon"
  fi
  rm -f "$DATA/backup-services.txt" "$DATA/backup-enabled.txt"
  say "TV settings restored."
else
  # No backup: take only CASA Test's helper out of the list, keep everything else.
  cur="$(sh_tv settings get secure enabled_accessibility_services)"
  new="$(printf '%s' "$cur" | tr ':' '\n' | grep -v -x "$SVC" | paste -sd ':' -)"
  if [ "$new" != "$cur" ]; then
    if [ -z "$new" ]; then
      "$ADB" -s "$T" shell settings delete secure enabled_accessibility_services >/dev/null 2>&1
    else
      "$ADB" -s "$T" shell "settings put secure enabled_accessibility_services '$new'"
    fi
  fi
fi

"$ADB" -s "$T" uninstall "$PKG" >/dev/null 2>&1
say "CASA Test is removed. The mic button opens Google Assistant again."
finish 0
