#!/bin/bash
# Double-click: downloads the latest CASA Test build from GitHub and installs it on the TV.
. "$(cd "$(dirname "$0")" && pwd)/.common.sh"

repo
connect

say "Downloading the latest build…"
curl -fsSL -o "$DATA/casa-test.apk" "https://github.com/$REPO/releases/download/latest/casa-test.apk" \
  || fail "couldn't download the build. Is the GitHub build finished, and the repository public?"

say "Installing on the TV…"
out="$("$ADB" -s "$T" install -r "$DATA/casa-test.apk" 2>&1)"
if ! printf '%s' "$out" | grep -q Success; then
  if printf '%s' "$out" | grep -q -e INSTALL_FAILED_UPDATE_INCOMPATIBLE -e signatures; then
    "$ADB" -s "$T" uninstall "$PKG" >/dev/null 2>&1
    out="$("$ADB" -s "$T" install "$DATA/casa-test.apk" 2>&1)"
  fi
  printf '%s' "$out" | grep -q Success || fail "the TV refused the install: $out"
fi

"$ADB" -s "$T" shell pm grant "$PKG" android.permission.RECORD_AUDIO >/dev/null 2>&1

# Switch on the test-3 helper, keeping whatever accessibility services the TV already has.
if [ ! -f "$DATA/backup-services.txt" ]; then
  sh_tv settings get secure enabled_accessibility_services > "$DATA/backup-services.txt"
  sh_tv settings get secure accessibility_enabled > "$DATA/backup-enabled.txt"
fi
cur="$(sh_tv settings get secure enabled_accessibility_services)"
case ":$cur:" in
  *":$SVC:"*) : ;;
  ":null:"|"::") "$ADB" -s "$T" shell "settings put secure enabled_accessibility_services '$SVC'" ;;
  *) "$ADB" -s "$T" shell "settings put secure enabled_accessibility_services '$cur:$SVC'" ;;
esac
"$ADB" -s "$T" shell settings put secure accessibility_enabled 1

"$ADB" -s "$T" logcat -c >/dev/null 2>&1
"$ADB" -s "$T" shell am start -n "$PKG/.MainActivity" >/dev/null 2>&1

say "Done. CASA Test is open on the TV.

On the TV:
  1. Press the mic button, then hold it for a second.
  2. Press the mic button again and say \"add a note: buy milk\".
     Try a phrase in French and one in Portuguese too.
  3. Press Home, open any app, then press the mic button.
  4. Choose Run smoothness test and wait 20 seconds.

Then double-click \"2 Get CASA Test results\".

While CASA Test is installed, the mic button opens it instead of Google Assistant."
finish 0
