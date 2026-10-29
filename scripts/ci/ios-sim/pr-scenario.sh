#!/bin/bash

# PR #7924: the new device's temporary chat controllers get /_stop. Reinstalls the app, migrates the archive below from
# onboarding ("Migrate" → paste link → download → import → passphrase → chat list), then reads the order of commands in
# the chat console:
#   stop-before-import     a /_stop row between the download's rcvStandaloneFileComplete and /_db import (base: absent, PR: present)
#   passphrase-check-stop  a /_stop row between /_db import and the next /set file paths (base: absent, PR: present)
#   migrated               the chat list shows the contact "Bob test peer" (both: present)
# The console is read from the accessibility tree; when its rows around /_db import cannot be read, the app log
# (chatSendCmd lines) is used, and the observation says so. Exits 0 whatever the checks show; non-zero only when the
# scenario could not run.
# The archive holds only test data: profile "Alice old laptop", contact "Bob test peer". Its link expires about 48 h
# after 2026-10-29 17:01 UTC.

set -euo pipefail

ui=$(dirname "$0")/ui
: "${SIM_UDID:?}" "${UI_OUT:?}"
app_log=$UI_OUT/app.log
passphrase=migrate-test-pass
contact="Bob test peer"
archive_link='simplex:/file#/?desc=chunkSize%3A%2064kb%0Adigest%3A%20K3UZIzE5BBjYQx5xwIc6O9kjYxlUcb9BTQVkK2c6nijwItWE7o8ZorknD7T2hELTfiwky41_iF335bFAEQGO4A%3D%3D%0Akey%3A%20RhMt5a76-KidP_RvdIMZk20tioobiqeaKATaUcvMsc4%3D%0Anonce%3A%208UGbhGNTAbnXbBnOxxdOs14ud9-pj6mq%0Aparty%3A%20recipient%0Aredirect%3A%0A%20%20digest%3A%20s-AZjdgoulpdXPaufo7VEs8OxfnGUCIfFjNucAD9wTQJIf_-c-67asgEUhmBy9QKQSQ-Ws5NnStZRASPHnnEjg%3D%3D%0A%20%20size%3A%202097152%0Areplicas%3A%0A-%20chunks%3A%0A%20%20-%201%3A_bSPQvqXJSdRC7c3tro79Q%3D%3D%3AMC4CAQAwBQYDK2VwBCIEIN9zihmMpwatHMYrzZPL32pOk1t0wXh1_xkAcfPloJDk%3AqIKQNUssNVAqlHyzV_JP7WSGSdP8GsSVrTJbJVkNouo%3D%0A%20%20server%3A%20xftp%3A%2F%2Fk_GgQl40UZVV0Y4BX9ZTyMVqX5ZewcLW0waQIl7AYDE%3D%40xftp4.simplex.im%2Cq2lrjgiyo2efyweksavwxh3dlsrxetaxjztde2x5nateugrtrwzvmdid.onion%0Asize%3A%2064kb%0A&data=%7B%22networkConfig%22%3A%7B%22hostMode%22%3A%22onionViaSocks%22%2C%22requiredHostMode%22%3Afalse%7D%7D'

case "${GITHUB_REF_NAME:-}" in
  *-before) build=base expected_stop=absent ;;
  *) build=pr expected_stop=present ;;
esac
echo "scenario build: $build (${GITHUB_REF_NAME:-no branch})"

fail() {
  echo "SCENARIO ERROR: $1"
  "$ui" shot scenario-error || true
  exit 1
}

check() {
  local name=$1 expected=$2 observed=$3 result=MISMATCH
  if [ "${observed%%(*}" = "$expected" ]; then
    result=MATCH
  fi
  echo "CHECK $name expected=$expected observed=$observed $result"
  "$ui" shot "$name"
}

# the first tree line matching the extended regex, tapped at its centre
tap_match() {
  local line x y w h
  line=$("$ui" tree) || true
  line=$(grep -E -- "$1" <<< "$line" | head -n 1) || true
  if [ -z "$line" ]; then
    return 1
  fi
  read -r x y w h < <(sed -E 's/.* at (-?[0-9]+),(-?[0-9]+) size ([0-9]+)x([0-9]+).*/\1 \2 \3 \4/' <<< "$line")
  "$ui" tap-xy $((x + w / 2)) $((y + h / 2))
}

# waits until a tree line matches the regex; fails the scenario at once when one matches the second regex
wait_match() {
  local want=$1 secs=$2 bad=${3:-} deadline t
  deadline=$((SECONDS + secs))
  while [ "$SECONDS" -lt "$deadline" ]; do
    t=$("$ui" tree 2> /dev/null) || t=""
    if grep -qiE -- "$want" <<< "$t"; then
      return 0
    fi
    if [ -n "$bad" ] && grep -qiE -- "$bad" <<< "$t"; then
      fail "\"$(grep -iE -- "$bad" <<< "$t" | head -n 1)\" shown while waiting for /$want/"
    fi
    sleep 3
  done
  return 1
}

# iOS system alerts (camera, notifications, pasting) are often missing from the tree, so their buttons are also
# looked for at points of the alert's right-hand button (the smoke test found "Allow" at 275,518)
tap_alert_button() {
  local label p element
  for label in "$@"; do
    if "$ui" tap "$label" 1 > /dev/null 2>&1; then
      echo "alert: tapped $label"
      return 0
    fi
  done
  for p in "275 430" "275 460" "275 490" "275 518" "275 550" "275 580"; do
    # shellcheck disable=SC2086
    element=$("$ui" point $p 2> /dev/null || true)
    for label in "$@"; do
      if grep -qF "\"$label\"" <<< "$element"; then
        # shellcheck disable=SC2086
        "$ui" tap-xy $p
        echo "alert: tapped $label at $p"
        return 0
      fi
    done
  done
  return 1
}

# taps one of the buttons if such an alert appears within secs
answer_alert() {
  local secs=$1 deadline
  shift
  deadline=$((SECONDS + secs))
  while [ "$SECONDS" -lt "$deadline" ]; do
    if tap_alert_button "$@"; then
      return 0
    fi
    sleep 1
  done
  echo "alert: none of $* appeared in $secs s"
}

# the terminal rows ("> command", "< response") of a shot's tree, top to bottom
console_rows() {
  jq -r '[.. | objects | select((.AXLabel // "") | test("(^|[\\s,])[<>] "))] | sort_by(.frame.y) | .[].AXLabel' "$1"
}

shot_json() {
  find "$UI_OUT" -maxdepth 1 -name "*-$1.json" | sort | tail -n 1
}

# prints present or absent for a "> /_stop" row in each window, or nothing when the rows don't cover the window
read_console() {
  local rows=$1 import before after start
  import=$(grep -nF '> /_db import' <<< "$rows" | head -n 1 | cut -d: -f1)
  if [ -z "$import" ]; then
    return
  fi
  before=$(head -n $((import - 1)) <<< "$rows")
  start=$(grep -nF rcvStandaloneFileComplete <<< "$before" | tail -n 1 | cut -d: -f1)
  if [ -n "$start" ] || [ "$import" -gt 6 ]; then
    if tail -n +$((${start:-0} + 1)) <<< "$before" | grep -qE '> /_stop$'; then
      console_before=present
    else
      console_before=absent
    fi
  fi
  after=$(tail -n +$((import + 1)) <<< "$rows")
  if grep -qF '> /set file paths' <<< "$after"; then
    if sed '/> \/set file paths/,$d' <<< "$after" | grep -qE '> /_stop$'; then
      console_after=present
    else
      console_after=absent
    fi
  fi
}

# the same windows in the app log's command lines
read_log() {
  local lines import
  lines=$(grep -nE 'chatSendCmd (apiStopChat|apiImportArchive|apiSetAppFilePaths)$|processReceivedMsg: rcvStandaloneFileComplete' "$app_log" | sed -E 's/^([0-9]+):.*(apiStopChat|apiImportArchive|apiSetAppFilePaths|rcvStandaloneFileComplete).*/\1 \2/') || true
  echo "::group::app log: commands around the import"
  echo "$lines"
  echo "::endgroup::"
  import=$(awk '$2 == "apiImportArchive" { print NR; exit }' <<< "$lines")
  if [ -z "$import" ]; then
    return
  fi
  if head -n $((import - 1)) <<< "$lines" | awk '$2 == "rcvStandaloneFileComplete" { s = 0 } $2 == "apiStopChat" { s = 1 } END { exit !s }'; then
    log_before=present
  else
    log_before=absent
  fi
  if tail -n +$((import + 1)) <<< "$lines" | awk '$2 == "apiSetAppFilePaths" { exit } $2 == "apiStopChat" { s = 1 } END { exit !s }'; then
    log_after=present
  else
    log_after=absent
  fi
}

# a new install shows onboarding, the only place with "Migrate from another device"
"$ui" reset
"$ui" shot fresh-install
"$ui" tap "Get started"
"$ui" wait "Create profile" 30 || fail "no profile creation screen"
# "Tap to paste link" is enabled only when the clipboard has text as the sheet opens
"$ui" clipboard "$archive_link"
tap_match '^Button "[^"]*Migrate' || fail "no Migrate button"
# the sheet's QR code scanner asks for the camera, and the alert hides the sheet from the tree
answer_alert 15 Allow OK
"$ui" wait "Tap to paste link" 30 || fail "no migration sheet"
"$ui" shot migrate-sheet
if "$ui" tree | grep -F '"Tap to paste link"' | grep ' disabled$'; then
  fail "Tap to paste link is disabled: the clipboard was empty when the sheet opened"
fi
"$ui" tap "Tap to paste link"
deadline=$((SECONDS + 40))
until wait_match 'Downloading|Open chat|Importing' 1; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    fail "the link was not pasted"
  fi
  tap_alert_button "Allow Paste" || true
done
"$ui" shot downloading

failure='Download failed|Error downloading|Error importing|Error deleting|Invalid link|Import failed'
wait_match 'Open chat' 600 "$failure" || fail "no passphrase screen after 600 s"
"$ui" shot passphrase-screen
"$ui" tap-value "Current passphrase…" 10 || echo "passphrase field not found by its placeholder, typing into the focused field"
"$ui" type "$passphrase"
tap_match '"([^"]*, )?Open chat"' || fail "no Open chat button"

# the started chat asks for notifications, and the alert hides the migration result from the tree
deadline=$((SECONDS + 300))
until wait_match 'Chat migrated!|Confirm network settings' 3 "Wrong passphrase|Error starting chat|Database downgrade|Incompatible database"; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    fail "the migration did not finish after 300 s"
  fi
  tap_alert_button Allow || true
done
if wait_match 'Confirm network settings' 1; then
  "$ui" shot network-settings
  tap_match '"([^"]*, )?Apply"' || fail "no Apply button"
  wait_match 'Chat migrated!' 120 || fail "no Chat migrated! alert"
fi
"$ui" shot chat-migrated
"$ui" tap OK || fail "no OK in the Chat migrated! alert"
answer_alert 20 Allow
wait_match 'Compose' 60 || fail "no chat list after the migration"

if wait_match "\"$contact\"|\"[^\"]*${contact}[^\"]*\"" 120; then
  check migrated present present
else
  check migrated present absent
fi

# Settings → app version → Developer → Chat console
# chat rows show contacts' images under the same label: the toolbar one is at the bottom (y 804 in the smoke test)
tap_match '^Image "Account" .* at [0-9]+,(7[5-9][0-9]|8[0-9][0-9]) ' || fail "no profile image in the toolbar"
"$ui" tap Settings || fail "no Settings in the user picker"
"$ui" wait "Migrate to another device" 30 || fail "Settings did not open"
for _ in 1 2 3 4 5 6 7 8; do
  if tap_match '"v[0-9][^"]*" .* at [0-9]+,([0-9]|[1-7][0-9]|[1-7][0-9][0-9]) '; then
    break
  fi
  "$ui" swipe 201 700 201 250
done
"$ui" wait "Developer" 15 || fail "no app version page"
tap_match '"Developer"' || fail "no Developer row"
"$ui" wait "Chat console" 15 || fail "no Developer page"
tap_match '"([^"]*, )?Chat console"' || fail "no Chat console row"
wait_match '[<>] /' 30 || fail "the chat console shows no rows"
"$ui" shot console-bottom

# older rows are above: scroll up until the import row shows, then bring it to the middle of the screen
found=""
previous=""
for _ in $(seq 1 60); do
  t=$("$ui" tree)
  if grep -qF '> /_db import' <<< "$t"; then
    found=$(grep -F '> /_db import' <<< "$t" | head -n 1)
    break
  fi
  if [ "$t" = "$previous" ]; then
    break
  fi
  previous=$t
  "$ui" swipe 201 300 201 600
done
console_before="" console_after=""
if [ -n "$found" ]; then
  y=$(sed -E 's/.* at -?[0-9]+,(-?[0-9]+) .*/\1/' <<< "$found")
  if [ "$y" -lt 380 ]; then
    "$ui" swipe 201 300 201 $((300 + 430 - y))
  fi
  "$ui" shot console-import
  rows=$(console_rows "$(shot_json console-import)")
  echo "::group::console rows around the import"
  echo "$rows"
  echo "::endgroup::"
  read_console "$rows"
else
  echo "the chat console has no /_db import row (the console keeps the last 200 rows)"
fi

log_before="" log_after=""
read_log
echo "app log: stop before import ${log_before:-unknown}, stop after the passphrase check ${log_after:-unknown}"

observe() {
  if [ -n "$1" ]; then
    echo "$1(console)"
  elif [ -n "$2" ]; then
    echo "$2(log)"
  else
    echo "unknown"
  fi
}
stop_before=$(observe "$console_before" "$log_before")
stop_after=$(observe "$console_after" "$log_after")
check stop-before-import "$expected_stop" "$stop_before"
check passphrase-check-stop "$expected_stop" "$stop_after"

if [ "$stop_before" = unknown ] || [ "$stop_after" = unknown ]; then
  fail "the order of /_stop and /_db import could be read neither from the console nor from the app log"
fi
if [ "${stop_before%%(*}" = present ] && [ "${stop_after%%(*}" = present ]; then
  echo "SCENARIO: BUG ABSENT"
else
  echo "SCENARIO: BUG PRESENT"
fi
