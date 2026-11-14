#!/bin/bash

# Received file names and links opened from messages and from the channel header (PR 8187).
# The CLI peer Bob (the test backend's simplex-chat) connects by his 1-time link and sends files with crafted names
# and messages with long links; the backend's channel cinews gets a web page, and the app joins it by its link.
#   F1  file names with control and text direction characters: the item shows [U+XXXX] markers
#   F2  long file names: the extension stays visible (judged on the screenshots)
#   L1  a link whose host is longer than 160 characters: the "Open link?" alert shows the whole host
#   L2  a link with a 3000-character user name: the alert keeps its Cancel button reachable
#   W1  the channel web page in the channel info opens the "Open link?" alert, not the browser
#   W2  a javascript: web page shows "Invalid link"
# Exits 0 whatever the checks show; non-zero only when the scenario could not run.

set -euo pipefail

ui=$(dirname "$0")/ui
: "${SIM_UDID:?}" "${UI_OUT:?}" "${RUNNER_TEMP:?}"
cli=$RUNNER_TEMP/backend/bin/simplex-chat
admin_db=$RUNNER_TEMP/backend/ci_admin
work=$RUNNER_TEMP/pr8187
files=$work/files

case "${GITHUB_REF_NAME:-}" in
  *-before) build="base" ;;
  *) build="pr" ;;
esac
echo "scenario build: $build (${GITHUB_REF_NAME:-no branch})"

label60=$(printf 'a%.0s' $(seq 1 60))
long_host="login.bank.example.com.$label60.$label60.$label60.attacker.test"
l1_link="https://$long_host/pay"
l2_user=$(printf 'u%.0s' $(seq 1 3000))
l2_link="https://$l2_user@example.com/page"
w1_page="https://$long_host/channel"
w2_page="javascript:alert(document.domain)"

fail() {
  echo "SCENARIO ERROR: $1"
  "$ui" shot scenario-error || true
  exit 1
}

[ -x "$cli" ] || fail "no $cli: start the run with -f backend=true"
[ -d "$admin_db" ] || [ -f "${admin_db}_chat.db" ] || fail "no backend admin database at $admin_db"
mkdir -p "$work" "$files"

stop_bob() {
  if [ -f "$work/bob.pid" ]; then
    kill -INT "$(cat "$work/bob.pid")" 2> /dev/null || true
  fi
  echo "::group::bob online log"
  cut -c1-300 "$work/bob-online.log" 2> /dev/null || true
  echo "::endgroup::"
}
trap stop_bob EXIT

result() {
  echo "SCENARIO: $1 build=$build observed=\"$2\" $3"
}

peer() {
  local db=$1 name=$2 secs=$3 cmd=$4 status=0
  "$cli" -d "$db" -e "$cmd" -t "$secs" --user-display-name "$name" < /dev/null > "$work/out" 2>&1 || status=$?
  echo "::group::$name: $(cut -c1-120 <<< "$cmd")"
  cut -c1-300 "$work/out"
  echo "::endgroup::"
  return "$status"
}

bob() {
  peer "$work/bob" Bob "$@"
}

admin() {
  peer "$admin_db" ci_admin "$@"
}

center() {
  local x y w h
  read -r x y w h < <(sed -E 's/.* at (-?[0-9]+),(-?[0-9]+) size ([0-9]+)x([0-9]+).*/\1 \2 \3 \4/' <<< "$1")
  echo "$((x + w / 2)) $((y + h / 2))"
}

line_y() {
  sed -E 's/.* at -?[0-9]+,(-?[0-9]+) size .*/\1/' <<< "$1"
}

tap_line() {
  local c
  c=$(center "$1")
  "$ui" tap-xy "${c% *}" "${c#* }"
}

tap_match() {
  local t line
  t=$("$ui" tree) || return 1
  line=$(grep -E -- "$1" <<< "$t" | head -n 1) || true
  [ -n "$line" ] || return 1
  tap_line "$line"
}

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

wait_match() {
  local want=$1 secs=$2 deadline t
  deadline=$((SECONDS + secs))
  while :; do
    t=$("$ui" tree 2> /dev/null) || t=""
    if grep -qE -- "$want" <<< "$t"; then
      return 0
    fi
    [ "$SECONDS" -lt "$deadline" ] || return 1
    tap_alert_button "Allow Paste" Allow > /dev/null 2>&1 || true
    sleep 1
  done
}

in_list() {
  "$ui" tree | grep -qE '^Button "Compose" '
}

dismiss_lock() {
  if "$ui" tree | grep -qF '"SimpleX Lock"'; then
    tap_match '^Button "Cancel" ' || "$ui" tap Cancel 3 || true
  fi
}

to_list() {
  for _ in 1 2 3 4; do
    dismiss_lock
    if in_list; then
      return 0
    fi
    "$ui" tap Back 2 || tap_match '^Button "[^"]*" .* at ([0-9]|[1-5][0-9]),([5-9][0-9]|1[01][0-9]) size [0-9]{1,2}x' || true
    sleep 1
  done
  echo "no way back to the chat list, restarting the app"
  "$ui" relaunch || fail "the app did not restart"
  in_list || fail "no chat list after a restart"
}

set_clipboard() {
  for _ in 1 2 3 4; do
    if "$ui" clipboard "$1"; then
      return 0
    fi
    sleep 5
  done
  fail "could not set the clipboard"
}

tap_paste() {
  local deadline=$((SECONDS + 60))
  until "$ui" tap "Tap to paste link" 2; do
    [ "$SECONDS" -lt "$deadline" ] || fail "could not tap \"Tap to paste link\""
    tap_alert_button Allow OK || true
    sleep 1
  done
}

close_sheet() {
  if ! in_list && ! grep -qE '"Arrow Up Circle"|"Mic"|"Connect"' <<< "$("$ui" tree)"; then
    "$ui" swipe 201 90 201 820
    sleep 2
  fi
}

find_scroll() {
  local line y
  for _ in 1 2 3 4 5 6 7 8; do
    line=$("$ui" tree | grep -E -- "$1" | head -n 1) || true
    if [ -n "$line" ]; then
      y=$(line_y "$line")
      if [ "$y" -ge 100 ] && [ "$y" -le 800 ]; then
        echo "$line"
        return 0
      fi
    fi
    "$ui" swipe 201 650 201 350
  done
  return 1
}

# the chat row whose label contains the text, in the list area
open_chat() {
  local line
  to_list
  line=$("$ui" tree | grep -F -- "$1" | while IFS= read -r l; do
    y=$(line_y "$l")
    if [ "$y" -ge 100 ] && [ "$y" -le 820 ]; then
      echo "$l"
    fi
  done | head -n 1)
  [ -n "$line" ] || return 1
  tap_line "$line"
  sleep 2
}

# the app was sent to the background by a link opened in Safari
back_to_app() {
  xcrun simctl launch "$SIM_UDID" chat.simplex.app > /dev/null 2>&1 || true
  sleep 3
}

# Bob's files: names with control and text direction characters, long names, names ending with dots;
# /bin/bash 3.2 on macOS has no \u in printf
python3 - "$files" > "$work/files.json" << 'EOF'
import json, os, sys
names = {
    "rlo": "invoice‮fdp.exe",
    "nl": "a.txt\nb.pdf",
    "fsi": "report⁦x⁩.pdf",
    "long": "a" * 200 + ".exe",
    "heb": "ש" * 100 + ".exe",
    "dots": "b" * 150 + "doc.exe. .",
}
paths = []
for d, n in names.items():
    os.makedirs(os.path.join(sys.argv[1], d), exist_ok=True)
    p = os.path.join(sys.argv[1], d, n)
    with open(p, "w") as f:
        f.write(d + " sample\n")
    paths.append(p)
print(json.dumps([{"filePath": p, "msgContent": {"type": "file", "text": ""}} for p in paths], ensure_ascii=False, separators=(",", ":")))
EOF
ls -R "$files" | cat -v

# Bob's 1-time link; he stays online until the app connects
bob 5 "/c" || fail "Bob could not create a 1-time link"
inv=$(grep -m 1 -oE 'https://[^ ]+/i#[^ ]+' "$work/out") || inv=$(grep -m 1 -oE 'simplex:/invitation#[^ ]+' "$work/out") || true
[ -n "$inv" ] || fail "no 1-time link in Bob's output"
nohup "$cli" -d "$work/bob" -e "/contacts" -t 3600 --user-display-name Bob < /dev/null > "$work/bob-online.log" 2>&1 &
echo $! > "$work/bob.pid"
sleep 5

to_list
set_clipboard "$inv"
"$ui" tap Compose || fail "no Compose button"
"$ui" tap "Scan / Paste link" 15 || fail "no \"Scan / Paste link\""
wait_match '"Tap to paste link"' 30 || fail "no connect sheet"
tap_paste
wait_match '"Open new chat"|"Connect"' 90 || fail "no \"Open new chat\" after pasting Bob's link"
"$ui" tap "Open new chat" 5 || true
wait_match '"Connect"' 30 || fail "no \"Connect\" button"
tap_match '^Button "Connect" ' || "$ui" tap Connect || fail "could not tap \"Connect\""
deadline=$((SECONDS + 300))
until grep -q 'contact is connected' "$work/bob-online.log" 2> /dev/null; do
  [ "$SECONDS" -lt "$deadline" ] || fail "Bob did not connect in 300 s"
  sleep 3
done
echo "Bob is connected"
kill -INT "$(cat "$work/bob.pid")" 2> /dev/null || true
for _ in $(seq 1 30); do
  kill -0 "$(cat "$work/bob.pid")" 2> /dev/null || break
  sleep 1
done
rm -f "$work/bob.pid"

ct=$(sqlite3 "$work/bob_chat.db" "SELECT contact_id FROM contacts WHERE is_user = 0 AND deleted = 0 ORDER BY contact_id DESC LIMIT 1")
[ -n "$ct" ] || fail "no contact in Bob's database"
msgs=$(cat "$work/files.json")
bob 120 "/_send @$ct json $msgs" || fail "Bob could not send the files"
texts=$(jq -cn --arg a "$l1_link" --arg b "$l2_link" '[{msgContent: {type: "text", text: $a}}, {msgContent: {type: "text", text: $b}}]')
bob 30 "/_send @$ct json $texts" || fail "Bob could not send the links"

# F1, F2: the file items
close_sheet
open_chat Bob || fail "no chat with Bob"
wait_match 'doc\.exe' 120 || echo "F: not all file items shown in 120 s"
"$ui" shot F-files-bottom
"$ui" swipe 201 300 201 700
"$ui" shot F-files-top
t=$("$ui" tree)
f1=""
for marker in 'invoice\[U\+202E\]fdp\.exe' 'a\.txt\[U\+000A\]b\.pdf' 'report\[U\+2066\]x\[U\+2069\]\.pdf'; do
  if grep -qE -- "$marker" <<< "$t"; then f1="$f1 shown:$marker"; else f1="$f1 missing:$marker"; fi
done
grep -E 'invoice|report|a\.txt' <<< "$t" || true
result F1 "${f1# }" "(pr: every marker shown; base: none)"
result F2 "see shots F-files-top, F-files-bottom" "(pr: .exe after the truncated names)"

# L1: the long host link
"$ui" swipe 201 650 201 250
line=$("$ui" tree | grep -F "login.bank.example.com" | tail -n 1) || true
[ -n "$line" ] || fail "no L1 message in the chat"
tap_line "$line"
if wait_match '"Open link\?"' 15; then
  "$ui" shot L1-alert
  t=$("$ui" tree)
  if grep -qF "$long_host…" <<< "$t" || grep -qF "$long_host/" <<< "$t"; then l1="whole host shown"; else l1="host cut"; fi
  grep -F 'login.bank' <<< "$t" | cut -c1-400 || true
  tap_match '^Button "Cancel" ' || "$ui" tap Cancel 5 || true
else
  "$ui" shot L1-no-alert
  l1="no alert"
fi
result L1 "$l1" "(pr: whole host shown; base: host cut)"

# L2: the 3000-character user name
line=$("$ui" tree | grep -F "uuuuuuuuuu" | tail -n 1) || true
if [ -z "$line" ]; then
  "$ui" shot L2-no-message
  result L2 "no message" ""
else
  tap_line "$line"
  if wait_match '"Open link\?"' 15; then
    "$ui" shot L2-alert
    if "$ui" tree | grep -qE '^Button "Cancel" '; then
      tap_match '^Button "Cancel" '
      sleep 2
      if "$ui" tree | grep -qF '"Open link?"'; then l2="Cancel did not close the alert"; else l2="Cancel reachable"; fi
    else
      "$ui" swipe 201 600 201 200
      "$ui" shot L2-alert-scrolled
      if tap_match '^Button "Cancel" '; then l2="Cancel reachable after scrolling"; else l2="no Cancel button"; fi
    fi
  else
    "$ui" shot L2-no-alert
    l2="no alert"
  fi
  result L2 "$l2" "(expected: Cancel reachable)"
fi

# W1, W2: the channel web page
admin 10 "/public group access #cinews web=$w1_page" || fail "the admin could not set the web page"
grep -q "updated public group access" "$work/out" || fail "the web page was not set"
admin 1 "/show link #cinews" || fail "no channel link"
clink=$(grep -m 1 -oE 'https://[^ ]+/c#[^ ]+' "$work/out") || fail "no channel link in the output"
to_list
set_clipboard "$clink"
"$ui" tap Compose || fail "no Compose button"
"$ui" tap "Scan / Paste link" 15 || fail "no \"Scan / Paste link\""
wait_match '"Tap to paste link"' 30 || fail "no connect sheet"
tap_paste
wait_match '"Open channel"' 90 || fail "no \"Open channel\" after pasting the channel link"
"$ui" tap "Open channel" 10 || fail "could not tap \"Open channel\""
if wait_match '"Join channel"' 30; then
  tap_match '^Button "Join channel" ' || "$ui" tap "Join channel" || true
  wait_match 'you are subscriber' 120 || echo "W: not subscribed in 120 s"
fi
"$ui" shot W-channel
tap_match '^[A-Za-z]+ "[^"]*cinews[^"]*" .* at -?[0-9]+,([0-9]|[1-9][0-9]|1[0-9][0-9]) ' || fail "no channel name in the chat toolbar"
line=$(find_scroll "\"$w1_page\"") || line=""
if [ -z "$line" ]; then
  "$ui" shot W1-no-web-page
  result W1 "no web page in the channel info" ""
else
  "$ui" shot W1-info
  tap_line "$line"
  if wait_match '"Open link\?"' 15; then
    "$ui" shot W1-alert
    if "$ui" tree | grep -qF "$long_host"; then w1="alert with whole host"; else w1="alert, host cut"; fi
    tap_match '^Button "Cancel" ' || "$ui" tap Cancel 5 || true
  else
    "$ui" shot W1-no-alert
    w1="no alert"
    back_to_app
  fi
  result W1 "$w1" "(pr: alert with whole host; base: no alert, Safari)"
fi

admin 10 "/public group access #cinews web=$w2_page" || fail "the admin could not set the second web page"
deadline=$((SECONDS + 120))
line=""
while [ "$SECONDS" -lt "$deadline" ]; do
  line=$(find_scroll '"javascript:' 2> /dev/null) && break
  "$ui" tap Back 2 || true
  tap_match '^[A-Za-z]+ "[^"]*cinews[^"]*" .* at -?[0-9]+,([0-9]|[1-9][0-9]|1[0-9][0-9]) ' || true
  sleep 5
done
if [ -z "$line" ]; then
  "$ui" shot W2-no-web-page
  result W2 "the javascript: page did not reach the app in 120 s" ""
else
  "$ui" shot W2-info
  tap_line "$line"
  if wait_match '"Invalid link"' 15; then
    "$ui" shot W2-alert
    w2="Invalid link alert"
    tap_match '^Button "OK" ' || "$ui" tap OK 5 || true
  elif wait_match '"Open link\?"' 2; then
    "$ui" shot W2-open-alert
    w2="Open link alert"
    tap_match '^Button "Cancel" ' || true
  else
    "$ui" shot W2-no-alert
    w2="no alert"
    back_to_app
  fi
  result W2 "$w2" "(pr: Invalid link alert; base: no alert)"
fi
echo "scenario finished"
