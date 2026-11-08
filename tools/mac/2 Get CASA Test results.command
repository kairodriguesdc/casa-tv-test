#!/bin/bash
# Double-click: reads the test results from the TV and copies them, ready to paste into the chat.
. "$(cd "$(dirname "$0")" && pwd)/.common.sh"

connect

log="$("$ADB" -s "$T" logcat -d -s CasaTest 2>/dev/null | tr -d '\r')"
result="$(printf '%s\n' "$log" | grep 'RESULT ' | tail -1 | sed 's/.*RESULT //')"
keys="$(printf '%s\n' "$log" | grep -e 'KEY ' -e 'WATCH ' | tail -12 | sed 's/^.*CasaTest[^:]*: //')"
voice="$(printf '%s\n' "$log" | grep 'VOICE ' | grep -e '"done"' -e '"error"' | tail -6 | sed 's/^.*VOICE //')"
model="$(sh_tv getprop ro.product.model)"

[ -n "$result" ] || fail "no results yet. Run the tests on the TV first (CASA Test must be open)."

file="$HOME/Desktop/CASA Test results.txt"
{
  echo "CASA Test results · $(date '+%Y-%m-%d %H:%M') · TV $model"
  echo
  echo "RESULT"
  echo "$result"
  echo
  echo "VOICE (latest)"
  echo "${voice:-none}"
  echo
  echo "BUTTONS (latest)"
  echo "${keys:-none}"
} > "$file"

pbcopy < "$file"
say "Results saved to your Desktop as \"CASA Test results.txt\" and copied.
Paste them into the chat with Claude."
finish 0
