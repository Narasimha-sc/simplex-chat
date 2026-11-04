#!/bin/bash

set -euo pipefail

ui=$(dirname "$0")/ui
here=$(cd "$(dirname "$0")" && pwd)
: "${SIM_UDID:?}" "${UI_OUT:?}" "${RUNNER_TEMP:?}"
cli=$RUNNER_TEMP/backend/bin/simplex-chat
names_server_file=$RUNNER_TEMP/backend/names-server
work=$RUNNER_TEMP/openmsg
out=$UI_OUT/openmsg
peer_dir=$out/peer
results=$out/results.tsv
port=5226
c1_trials=6
c5_trials=8
flood_max=400
interval=0.05
tap_at=6
stop_after=3
min_valid=10
geom_re=' at (-?[0-9]+),(-?[0-9]+) size ([0-9]+)x([0-9]+)'
account_image='^Image "Account" .* at [0-9]+,(7[5-9][0-9]|8[0-9][0-9]) '
go_down_re='^(Image "Go Down"|StaticText "[0-9]+") '

case "${GITHUB_REF_NAME:-}" in
  *-before) build=base expect="bug or timing-miss" ;;
  *) build=pr expect=ok ;;
esac

cat << EOF
openmsg scenario, build $build (${GITHUB_REF_NAME:-no branch}): messages received while their chat is opening.
  Bob, a CLI peer on the test backend's SMP server, sends numbered texts; the app's chat shows them, read by OCR.
  Bob sends texts as fast as his CLI accepts them, at most one per $interval s and $flood_max in all; the tap follows his
  answer to text $tap_at, and Bob stops $stop_after s after the app log shows the apiGetChat response of the open or reload.
  C1  $c1_trials times: texts "Wave <j> number NNNN"; Bob's chat is opened from the chat list
  C5  $c5_trials times, Bob's chat open with its search open: texts "Reload <j> number NNNN";
      the search's Cancel (an initial reload of the open chat)
  C2  after a sample with lost numbers, the chat reopened without a flood shows them
  A number is lost when a screenshot shows numbers below and above it but not it.
  A sample is valid when Bob's answers come both before the apiGetChat request and after its response.
  The verdict is INCONCLUSIVE with fewer than $min_valid valid samples.
  Results: openmsg/results.tsv of the smoke test artifact.
EOF

om() {
  python3 "$here/pr-openmsg.py" "$@"
}

fail() {
  echo "SCENARIO ERROR: $1"
  "$ui" shot scenario-error >> "$out/shots.log" 2>&1 || true
  exit 1
}

record() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$build" "$2" "$3" "$4" "$5" >> "$results"
  echo "SCENARIO: $1 build=$build expected=\"$2\" observed=\"$3\" $4 shot=$5"
}

geom() {
  [[ $1 =~ $geom_re ]] || return 1
  gx=${BASH_REMATCH[1]}
  gy=${BASH_REMATCH[2]}
  gw=${BASH_REMATCH[3]}
  gh=${BASH_REMATCH[4]}
}

tap_line() {
  geom "$1" || return 1
  "$ui" tap-xy $((gx + gw / 2)) $((gy + gh / 2))
}

first_match() {
  local line
  while IFS= read -r line; do
    if [[ $line =~ $1 ]] && geom "$line" && [ "$gy" -ge "$2" ] && [ "$gy" -le "$3" ]; then
      echo "$line"
      return 0
    fi
  done
  return 0
}

tap_match() {
  local t line
  t=$("$ui" tree) || return 1
  line=$(first_match "$1" "${2:--100000}" "${3:-100000}" <<< "$t")
  [ -n "$line" ] || return 1
  tap_line "$line"
}

answer_alert() {
  local line
  line=$(first_match '^Button "(Allow Paste|Allow)" ' -100000 100000 <<< "$1")
  if [ -n "$line" ]; then
    echo "alert: tapping $(cut -d'"' -f2 <<< "$line")"
    tap_line "$line"
  fi
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
    answer_alert "$t"
    sleep 2
  done
}

shot() {
  "$ui" shot "$1" >> "$out/shots.log" 2>&1
}

shot_file() {
  find "$UI_OUT" -maxdepth 1 -name "*-$1.png" | sort | tail -n 1
}

relaunch() {
  local prefs element
  xcrun simctl terminate "$SIM_UDID" chat.simplex.app 2> /dev/null || true
  prefs=$(xcrun simctl get_app_container "$SIM_UDID" chat.simplex.app data)/Library/Preferences/chat.simplex.app
  xcrun simctl spawn "$SIM_UDID" defaults write "$prefs" localAuthenticationNoticeShown -bool true || echo "could not mark the SimpleX Lock notice as shown"
  "$ui" relaunch || fail "the app did not restart"
  sleep 3
  element=$("$ui" point 134 523 2> /dev/null || true)
  if grep -qF '"Cancel"' <<< "$element"; then
    echo "alert: SimpleX Lock notice, tapping Cancel"
    "$ui" tap-xy 134 523
  fi
}

in_list() {
  local t
  t=$("$ui" tree) || return 1
  grep -qE '^Button "Compose" ' <<< "$t"
}

to_list() {
  local i t
  for i in 1 2 3; do
    t=$("$ui" tree) || t=""
    if grep -qF '"SimpleX Lock"' <<< "$t"; then
      echo "SimpleX Lock prompt: Cancel"
      tap_match '^Button "Cancel" ' || true
      continue
    fi
    if grep -qE '^Button "Compose" ' <<< "$t"; then
      return 0
    fi
    answer_alert "$t"
    "$ui" tap Back 2 || true
    sleep 1
  done
  echo "no way back to the chat list, restarting the app"
  relaunch
  in_list || fail "no chat list after a restart"
}

chat_shown() {
  grep -qE '^(Heading|Button) "Bob" .* at -?[0-9]+,([0-9]|[1-9][0-9]|1[01][0-9]) ' <<< "$1" && ! grep -qE '^Button "Compose" ' <<< "$1"
}

wait_chat() {
  local deadline=$((SECONDS + $1)) t
  while :; do
    t=$("$ui" tree 2> /dev/null) || t=""
    if chat_shown "$t"; then
      return 0
    fi
    [ "$SECONDS" -lt "$deadline" ] || return 1
    answer_alert "$t"
    sleep 1
  done
}

bob_row() {
  local t
  t=$("$ui" tree) || return 0
  first_match '^StaticText "Bob" ' 100 790 <<< "$t"
}

open_bob() {
  local line
  to_list
  line=$(bob_row)
  [ -n "$line" ] || fail "no row of Bob in the chat list"
  tap_line "$line"
  wait_chat 30 || fail "Bob's chat did not open"
}

back_to_list() {
  "$ui" tap Back 5 || true
  sleep 1
  to_list
}

open_user_picker() {
  tap_match "$account_image" || fail "no profile image in the toolbar"
  "$ui" wait Settings 15 || fail "the user picker did not open"
  sleep 1
}

open_console() {
  local found=""
  to_list
  open_user_picker
  "$ui" tap Settings || fail "no Settings in the user picker"
  "$ui" wait "Migrate to another device" 30 || fail "Settings did not open"
  for _ in 1 2 3 4 5 6 7 8; do
    if tap_match '"v[0-9][^"]*" ' 0 799; then
      found=yes
      break
    fi
    "$ui" swipe 201 700 201 250
  done
  [ -n "$found" ] || fail "no app version row in Settings"
  "$ui" wait "Developer" 15 || fail "no app version page"
  tap_match '"Developer"' || fail "no Developer row"
  "$ui" wait "Chat console" 15 || fail "no Developer page"
  tap_match '"([^"]*, )?Chat console"' || fail "no Chat console row"
  wait_match '"Arrow Up Circle"' 30 || fail "no chat console"
  sleep 2
}

send_button_y() {
  local t line
  t=$("$ui" tree) || return 1
  line=$(first_match '^Button "Arrow Up Circle" ' -100000 100000 <<< "$t")
  geom "$line" || return 1
  echo $((gy + gh / 2))
}

field_is() {
  local t
  t=$("$ui" tree) || return 1
  grep -qF -- "value=$(jq -rn --arg s "$1" '$s | tojson') " <<< "$t"
}

clear_field() {
  axe key-combo --modifiers 227 --key 4 --udid "$SIM_UDID" > /dev/null 2>&1 || true
  "$ui" key delete 1
}

put_text() {
  local text=$1 y t line
  y=$(send_button_y) || fail "no compose field"
  "$ui" clipboard "$text"
  "$ui" tap-xy 170 "$y"
  axe key-combo --modifiers 227 --key 25 --udid "$SIM_UDID" > /dev/null 2>&1 || echo "Cmd+V failed"
  sleep 1
  if field_is "$text"; then
    return 0
  fi
  echo "Cmd+V did not paste the text, trying the edit menu"
  clear_field
  for _ in 1 2 3; do
    y=$(send_button_y) || fail "no compose field"
    "$ui" tap-xy 170 "$y"
    sleep 1
    t=$("$ui" tree) || t=""
    line=$(first_match '^[A-Za-z]+ "Paste" ' -100000 100000 <<< "$t")
    if [ -n "$line" ]; then
      tap_line "$line"
      sleep 1
      answer_alert "$("$ui" tree)"
    fi
    if field_is "$text"; then
      return 0
    fi
    clear_field
  done
  "$ui" shot input-error >> "$out/shots.log" 2>&1 || true
  fail "the compose field does not hold the text"
}

rows_after() {
  local t=$1 cmd=$2 line cy l
  line=$({ grep -F -- ", > ${cmd:0:30}\" " <<< "$t" || true; } | tail -n 1)
  [ -n "$line" ] || return 0
  geom "$line" || return 0
  cy=$gy
  while IFS= read -r l; do
    if [[ $l == 'Button "'* ]] && geom "$l" && [ "$gy" -gt "$cy" ]; then
      echo "$l"
    fi
  done <<< "$t"
}

console_send() {
  local cmd=$1 want=$2 secs=${3:-30} deadline t after
  put_text "$cmd"
  "$ui" tap "Arrow Up Circle" || fail "no send button in the chat console"
  deadline=$((SECONDS + secs))
  while :; do
    t=$("$ui" tree 2> /dev/null) || t=""
    after=$(rows_after "$t" "$cmd")
    if grep -qE -- ", < (\* )?($want)" <<< "$after"; then
      echo "console: ${cmd:0:40} -> $(grep -oE -- ", < (\* )?($want)[^\"]*" <<< "$after" | head -n 1)"
      return 0
    fi
    if [ "$SECONDS" -ge "$deadline" ]; then
      echo "::group::console rows after ${cmd:0:40}"
      echo "$after"
      echo "::endgroup::"
      return 1
    fi
    sleep 2
  done
}

stop_peer() {
  local pid deadline
  printf 'QUIT' > "$peer_dir/in/quit.cmd" 2> /dev/null || true
  if [ -f "$work/bob.pid" ]; then
    pid=$(cat "$work/bob.pid")
    kill -INT "$pid" 2> /dev/null || true
    deadline=$((SECONDS + 20))
    while kill -0 "$pid" 2> /dev/null; do
      if [ "$SECONDS" -ge "$deadline" ]; then
        kill -KILL "$pid" 2> /dev/null || true
      fi
      sleep 1
    done
  fi
  if [ -f "$work/peer.pid" ]; then
    kill "$(cat "$work/peer.pid")" 2> /dev/null || true
  fi
  echo "::group::Bob's CLI log, last 60 lines"
  tail -n 60 "$out/bob-cli.log" 2> /dev/null || true
  echo "::endgroup::"
  echo "::group::peer log, last 60 lines"
  tail -n 60 "$out/peer.log" 2> /dev/null || true
  echo "::endgroup::"
}

go_down_line() {
  local t line
  t=$("$ui" tree) || return 0
  while IFS= read -r line; do
    if [[ $line =~ $go_down_re ]] && geom "$line" && [ "$gx" -ge 330 ] && [ "$gy" -ge 600 ] && [ "$gy" -le 790 ]; then
      echo "$line"
      return 0
    fi
  done <<< "$t"
}

scroll_newer() {
  local line
  line=$(go_down_line)
  if [ -n "$line" ]; then
    tap_line "$line"
  else
    axe swipe --start-x 201 --start-y 650 --end-x 201 --end-y 250 --duration 0.2 --udid "$SIM_UDID" > /dev/null 2>&1 || true
    axe swipe --start-x 201 --start-y 650 --end-x 201 --end-y 250 --duration 0.2 --udid "$SIM_UDID" > /dev/null 2>&1 || true
  fi
  sleep 2
}

scroll_older() {
  axe swipe --start-x 201 --start-y 300 --end-x 201 --end-y 600 --duration 1.5 --udid "$SIM_UDID" > /dev/null 2>&1 || true
  sleep 1.5
}

read_page() {
  local word=$1 j=$2 name=$3 png
  shot "$name"
  png=$(shot_file "$name")
  [ -n "$png" ] || fail "no screenshot $name"
  "$work/pr-ocr" "$screen_h" "$png" >> "$ocr" || echo "OCR of $png failed"
  cnt="" low="" high="" older="" sig=""
  read -r cnt low high older sig < <(om page "$ocr" "$png" "$word" "$j") || true
  echo "read $name: ${cnt:-?} numbers ${low:-?}..${high:-?}, older texts ${older:-?}"
}

read_burst() {
  local word=$1 j=$2 name=$3 tag=$4 p=0 newest prev_high=-1 prev=""
  ocr=$out/$name.ocr
  : > "$ocr"
  newest=$(om sent "$peer_dir" "$tag")
  while [ "$p" -lt 8 ]; do
    p=$((p + 1))
    scroll_newer
    read_page "$word" "$j" "$name-page$p"
    if [ "$high" = - ] || [ "$high" -ge "$newest" ] || [ "$high" = "$prev_high" ]; then
      break
    fi
    prev_high=$high
  done
  echo "read $name: bottom at ${high:-?} of $newest sent"
  prev=$sig
  while [ "$p" -lt 30 ] && [ "$low" != 1 ] && [ "$older" != 1 ]; do
    p=$((p + 1))
    scroll_older
    read_page "$word" "$j" "$name-page$p"
    if [ "$sig" = "$prev" ]; then
      break
    fi
    prev=$sig
  done
}

app_log_lines() {
  echo "app log, the last apiGetChat lines:"
  { grep -E 'chatSendCmd apiGetChat' "$UI_OUT/app.log" || true; } | tail -n 4
}

verdict_of() {
  if [ "$2" != valid ]; then
    echo INVALID
    return
  fi
  case "$1" in
    bug) if [ "$build" = base ]; then echo MATCH; else echo MISMATCH; fi ;;
    ok) echo MATCH ;;
    *) echo INVALID ;;
  esac
}

flood_and_tap() {
  local tag=$1 text=$2 x=$3 y=$4 name=$5 t0 t1
  load_request="" load_response=""
  om flood "$peer_dir" "$tag" "$cid" "$flood_max" "$interval" "$text"
  om flood-reached "$peer_dir" "$tag" "$tap_at" 60 || fail "Bob did not send $tap_at texts in 60 s"
  load_mark=$(wc -c < "$UI_OUT/app.log" | tr -d ' ')
  t0="" t1=""
  read -r t0 t1 < <(om tap "$x" "$y") || true
  echo "$name: tapped between ${t0:-?} and ${t1:-?}"
  read_load 60
  if [ -n "$load_response" ]; then
    sleep "$stop_after"
    om stop "$peer_dir" "$tag"
  else
    echo "$name: no apiGetChat response in the app log yet, the flood runs to $flood_max texts"
  fi
  om flood-wait "$peer_dir" "$tag" 400 || echo "flood $tag: not every message got a response"
  om stop "$peer_dir" "$tag"
  if [ -z "$load_response" ]; then
    read_load 30
  fi
}

read_load() {
  local type=""
  read -r load_request load_response type < <(om load-time "$UI_OUT/app.log" "$load_mark" "$1") || true
  echo "apiGetChat after app log byte $load_mark: request ${load_request:-none}, response ${load_response:-none} ${type:-}"
}

c2_reopen() {
  local check=$1 word=$2 j=$3 missing=$4 name=$5 tag=$6 res v
  back_to_list
  open_bob
  sleep 2
  read_burst "$word" "$j" "$name-reopen" "$tag"
  res=$(om shown "$out/$name-reopen.ocr" "$word" "$j" "$missing")
  case "$res" in
    all*) v=MATCH ;;
    *) v=MISMATCH ;;
  esac
  record "C2-reopen-shows-missing-$name" "lost numbers $missing shown" "$res" "$v" "$(basename "$(shot_file "$name-reopen-page1")")"
}

judge_sample() {
  local check=$1 tag=$2 word=$3 j=$4 name=$5 outcome missing gap validity obs v
  om judge "$peer_dir" "$tag" "$word" "$j" "$load_request" "$load_response" "$out/$name.ocr" > "$out/$name.judge" || fail "the judge failed for $name"
  app_log_lines >> "$out/$name.judge"
  cat "$out/$name.judge"
  read -r outcome missing gap validity < "$out/$name.judge"
  obs=$(sed -n 2p "$out/$name.judge")
  if [ "$build" = base ] && [ "$outcome" = ok ]; then
    obs="timing-miss $obs"
  fi
  v=$(verdict_of "$outcome" "$validity")
  if [ "$gap" = - ]; then
    gap=$(basename "$(shot_file "$name-page1")")
  fi
  record "$check" "$expect" "$obs" "$v" "$gap"
  if [ "$outcome" = bug ]; then
    c2_reopen "$check" "$word" "$j" "$missing" "$name" "$tag"
  fi
}

c1_trial() {
  local j=$1 tag=c1o$1 word=Wave name=C1-open$1 line
  to_list
  line=$(bob_row)
  [ -n "$line" ] || fail "no row of Bob in the chat list"
  geom "$line"
  flood_and_tap "$tag" "$word $j number" $((gx + gw / 2)) $((gy + gh / 2)) "$name"
  if ! wait_chat 20; then
    shot "$name-not-opened"
    record "C1-open-during-flood-$j" "$expect" "the chat did not open" INVALID "$(basename "$(shot_file "$name-not-opened")")"
    return 0
  fi
  if [ -z "$load_response" ]; then
    shot "$name-no-load"
    record "C1-open-during-flood-$j" "$expect" "no apiGetChat response in the app log" INVALID "$(basename "$(shot_file "$name-no-load")")"
    back_to_list
    return 0
  fi
  sleep 4
  read_burst "$word" "$j" "$name" "$tag"
  judge_sample "C1-open-during-flood-$j" "$tag" "$word" "$j" "$name"
  back_to_list
  sleep 2
}

cancel_line() {
  local t
  t=$("$ui" tree) || return 0
  first_match '^Button "Cancel" ' 0 220 <<< "$t"
}

open_search() {
  local i
  for i in 1 2 3; do
    tap_match '^PopUpButton "More" ' 0 200 || tap_match '^(Button|Image) "More" ' 0 200 || return 1
    if wait_match '^[A-Za-z]+ "Search" ' 10 && tap_match '^[A-Za-z]+ "Search" '; then
      sleep 1
      if [ -n "$(cancel_line)" ]; then
        return 0
      fi
    fi
    "$ui" shot "search-not-opened-$i" >> "$out/shots.log" 2>&1 || true
    "$ui" tap-xy 201 450 || true
  done
  return 1
}

c5_trial() {
  local j=$1 tag=c5r$1 word=Reload name=C5-reload$1 line t
  t=$("$ui" tree) || t=""
  if ! chat_shown "$t"; then
    open_bob
  fi
  open_search || fail "the chat search did not open"
  line=$(cancel_line)
  [ -n "$line" ] || fail "no Cancel of the chat search"
  geom "$line"
  shot "$name-search-open"
  flood_and_tap "$tag" "$word $j number" $((gx + gw / 2)) $((gy + gh / 2)) "$name"
  sleep 4
  if [ -z "$load_response" ]; then
    shot "$name-no-load"
    record "C5-search-closed-during-flood-$j" "$expect" "no apiGetChat response in the app log" INVALID "$(basename "$(shot_file "$name-no-load")")"
    "$ui" tap Cancel 5 || true
    return 0
  fi
  if [ -n "$(cancel_line)" ]; then
    shot "$name-search-not-closed"
    record "C5-search-closed-during-flood-$j" "$expect" "the search did not close" INVALID "$(basename "$(shot_file "$name-search-not-closed")")"
    "$ui" tap Cancel 5 || true
    return 0
  fi
  read_burst "$word" "$j" "$name" "$tag"
  judge_sample "C5-search-closed-during-flood-$j" "$tag" "$word" "$j" "$name"
}

run_check() {
  local check=$1 status
  shift
  set +e
  (
    set -e
    "$@"
  )
  status=$?
  set -e
  if [ "$status" -ne 0 ]; then
    record "$check" "$expect" "the check stopped (exit $status)" ERROR -
  fi
}

"$ui" tap "Don’t Allow" 5 || true
[ -x "$cli" ] || fail "no $cli: start the run with -f backend=true"
smp_server=$(cat "$names_server_file" 2> /dev/null) || fail "no $names_server_file: start the run with -f backend=true"
echo "local SMP server: $smp_server"
mkdir -p "$work" "$out" "$peer_dir/in"
: > "$results"
xcrun swiftc -O -o "$work/pr-ocr" "$here/pr-ocr.swift" || fail "the OCR helper did not compile"

nohup "$cli" -d "$work/bob" -p "$port" --user-display-name Bob -s "$smp_server" < /dev/null > "$out/bob-cli.log" 2>&1 &
echo $! > "$work/bob.pid"
nohup python3 "$here/pr-openmsg.py" peer "$port" "$peer_dir" < /dev/null > "$out/peer.log" 2>&1 &
echo $! > "$work/peer.pid"
trap stop_peer EXIT
deadline=$((SECONDS + 180))
until [ -f "$peer_dir/peer-ready" ]; do
  if [ -f "$peer_dir/peer-closed" ] || [ "$SECONDS" -ge "$deadline" ] || ! kill -0 "$(cat "$work/peer.pid")" 2> /dev/null; then
    fail "the peer did not connect to Bob's chat server"
  fi
  sleep 1
done

resp=$(om cmd "$peer_dir" clink "/c" 60) || fail "Bob could not create a 1-time link"
link=$({ grep -oE 'https://[^"[:space:]]+/i#[^"[:space:]]+' <<< "$resp" || true; } | head -n 1)
if [ -z "$link" ]; then
  link=$({ grep -oE 'simplex:/invitation#[^"[:space:]]+' <<< "$resp" || true; } | head -n 1)
fi
[ -n "$link" ] || fail "no 1-time link in Bob's response: ${resp:0:300}"
echo "Bob's 1-time link: $link"

open_console
shot console-start
console_send "/smp $smp_server" 'cmdOk' 30 || fail "/smp failed"
console_send "/c $link" 'sentConfirmation|sentInvitation|contactAlreadyExists|chatCmdError|error' 90 || echo "no response row for /c"
shot console-connect
connected=$(om event "$peer_dir" contactConnected 180) || fail "Bob's contact with the app did not connect"
cid=$(jq -r '.contact.contactId' <<< "$connected")
[[ $cid =~ ^[0-9]+$ ]] || fail "no contact id in Bob's contactConnected event"
echo "Bob's contact id of the app: $cid"
relaunch

om cmd "$peer_dir" chello "/_send @$cid text Hello from Bob" 30 > /dev/null || fail "Bob could not send"
wait_match '"Hello from Bob' 90 || fail "the app did not show Bob's first message"
open_bob
sleep 2
shot setup-chat
png=$(shot_file setup-chat)
screen_h=$(jq -r '.[0].frame.height | floor' "${png%.png}.json")
[[ $screen_h =~ ^[0-9]+$ ]] || fail "no screen height in the tree"
"$work/pr-ocr" "$screen_h" "$png" > "$out/setup-chat.ocr" || true
cat "$out/setup-chat.ocr"
grep -qF "Hello from Bob" "$out/setup-chat.ocr" || fail "OCR did not read \"Hello from Bob\" in the chat"
back_to_list

for j in $(seq 1 "$c1_trials"); do
  run_check "C1-open-during-flood-$j" c1_trial "$j"
done
for j in $(seq 1 "$c5_trials"); do
  run_check "C5-search-closed-during-flood-$j" c5_trial "$j"
done
set +e
(
  set -e
  to_list
)
set -e

echo "::group::results"
cat "$results"
echo "::endgroup::"
read -r c1_valid c5_valid bugs oks confirmed < <(awk -F'\t' '
  $1 ~ /^C1-/ && ($5 == "MATCH" || $5 == "MISMATCH") { v1++ }
  $1 ~ /^C5-/ && ($5 == "MATCH" || $5 == "MISMATCH") { v5++ }
  $1 ~ /^C[15]-/ && ($5 == "MATCH" || $5 == "MISMATCH") && $4 ~ /outcome=bug/ { b++ }
  $1 ~ /^C[15]-/ && ($5 == "MATCH" || $5 == "MISMATCH") && $4 ~ /outcome=ok/ { o++ }
  $1 ~ /^C2-/ && $5 == "MATCH" { c++ }
  END { print v1 + 0, v5 + 0, b + 0, o + 0, c + 0 }' "$results")
valid=$((c1_valid + c5_valid))
echo "valid samples: C1 $c1_valid of $c1_trials, C5 $c5_valid of $c5_trials; with lost numbers $bugs (confirmed by a reopen: $confirmed), without $oks"
if [ "$valid" -lt "$min_valid" ]; then
  echo "SCENARIO: INCONCLUSIVE (valid samples $valid, fewer than $min_valid)"
elif [ "$confirmed" -gt 0 ]; then
  echo "SCENARIO: BUG PRESENT"
elif [ "$bugs" -eq 0 ]; then
  echo "SCENARIO: BUG ABSENT"
else
  echo "SCENARIO: INCONCLUSIVE (lost numbers not confirmed by a reopen)"
fi
