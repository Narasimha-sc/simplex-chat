#!/bin/bash

# Chat settings kept when chat events arrive. The CLI peer Bob (the test backend's simplex-chat) owns the group
# "Garden Club" with 100 long messages of history; the app joins it by its link, with the top bar layout.
#   B1  Mentions set from the chat list row's swipe action while the history arrives; the row's swipe action is read
#       for 45 s, again after the whole history is in, and after an app restart (the database's value)
#   R1  from the row's swipe actions: Mute all (None), Unmute (All), Mute (Mentions), Favorite, each read after 10 s,
#       then after reopening the chat list and after an app restart
#   R3  the group's "Send receipts" set to no in its info; Settings, Your privacy, More privacy, "Small groups"
#       on with "Enable for all"; the info shows the default again, read without a restart
#   N1  with Mentions, a message from Bob without a mention presents no notification (the app log's willPresent lines);
#   N0  the same with All presents one, as the control
#   V1  the CLI peer Carol, connected by her 1-time link: in her info Mute, then "Verify security code", "Mark verified";
#       back in the chat list, without a restart, her row's swipe action still says "Unmute"
# The swipe action names the next mode: "Mute" = All, "Mute all" = Mentions, "Unmute" = None.
# Exits 0 whatever the checks show; non-zero only when the scenario could not run.

set -euo pipefail

ui=$(dirname "$0")/ui
: "${SIM_UDID:?}" "${UI_OUT:?}" "${RUNNER_TEMP:?}"
cli=$RUNNER_TEMP/backend/bin/simplex-chat
work=$RUNNER_TEMP/gmute
group="Garden Club"
hist_n=100

case "${GITHUB_REF_NAME:-}" in
  *-before) build=base exp_b1="BUG or OK" exp_v1="BUG" ;;
  *) build=pr exp_b1=OK exp_v1=OK ;;
esac
row_name=$group
echo "scenario build: $build (${GITHUB_REF_NAME:-no branch})"

fail() {
  echo "SCENARIO ERROR: $1"
  "$ui" shot scenario-error || true
  exit 1
}

[ -x "$cli" ] || fail "no $cli: start the run with -f backend=true"
mkdir -p "$work"

stop_bob() {
  local p
  for p in bob carol; do
    if [ -f "$work/$p.pid" ]; then
      kill -INT "$(cat "$work/$p.pid")" 2> /dev/null || true
    fi
    echo "::group::$p online log"
    cut -c1-300 "$work/$p-online.log" 2> /dev/null || true
    echo "::endgroup::"
  done
}
trap stop_bob EXIT

check() {
  local name=$1 expected=$2 observed=$3 result=MISMATCH
  if [ "$observed" = "$expected" ]; then
    result=OK
  fi
  echo "SCENARIO: $name expected=\"$expected\" observed=\"$observed\" $result"
}

peer() {
  local db=$1 name=$2 secs=$3 cmd=$4 status=0
  "$cli" -d "$work/$db" -e "$cmd" -t "$secs" --user-display-name "$name" < /dev/null > "$work/out" 2>&1 || status=$?
  cat "$work/out" >> "$work/$db-cli.log"
  echo "::group::$name: $(cut -c1-120 <<< "$cmd")"
  cut -c1-300 "$work/out"
  echo "::endgroup::"
  return "$status"
}

bob() {
  peer bob Bob "$@"
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

# system alerts (paste, camera) hide the app's tree; the tree misses some of them, so their buttons are also looked for by point
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
    tap_alert_button "Allow Paste" Allow OK > /dev/null 2>&1 || true
    sleep 1
  done
}

in_list() {
  "$ui" tree | grep -qE '^Button "Compose" '
}

# the app offers SimpleX Lock after a few launches (run 41670371612)
dismiss_lock() {
  if "$ui" tree | grep -qF '"SimpleX Lock"'; then
    echo "SimpleX Lock prompt: Cancel"
    tap_match '^Button "Cancel" ' || "$ui" tap Cancel 3 || true
  fi
}

to_list() {
  local i
  for i in 1 2 3; do
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

# the row of the chat row_name in the chat list
row_line() {
  "$ui" tree | grep -F -- "$row_name" | while IFS= read -r l; do
    y=$(line_y "$l")
    if [ "$y" -ge 100 ] && [ "$y" -le 820 ]; then
      echo "$l"
    fi
  done | head -n 1
}

row_cy() {
  local line c
  line=$(row_line)
  [ -n "$line" ] || return 1
  c=$(center "$line")
  echo "${c#* }"
}

ntf_of() {
  if grep -qE '^[A-Za-z]+ "Mute all" ' <<< "$1"; then
    echo Mentions
  elif grep -qE '^[A-Za-z]+ "Unmute" ' <<< "$1"; then
    echo None
  elif grep -qE '^[A-Za-z]+ "Mute" ' <<< "$1"; then
    echo All
  else
    echo unknown
  fi
}

fav_of() {
  if grep -qE '^[A-Za-z]+ "Unfav\." ' <<< "$1"; then
    echo fav
  elif grep -qE '^[A-Za-z]+ "Favorite" ' <<< "$1"; then
    echo notfav
  else
    echo unknown
  fi
}

# opens the row's leading swipe actions; actions_tree is the tree with them shown, swipe_y the row's y
open_actions() {
  local y i
  for i in 1 2 3 4; do
    to_list
    y=$(row_cy) || fail "no row of $row_name in the chat list"
    "$ui" swipe 30 "$y" 230 "$y"
    actions_tree=$("$ui" tree)
    if [ "$(ntf_of "$actions_tree")" != unknown ]; then
      swipe_y=$y
      return 0
    fi
    echo "swipe $i at y=$y showed no notification action"
  done
  "$ui" shot swipe-actions-missing
  fail "the row's swipe actions did not open"
}

close_actions() {
  "$ui" tap-xy 330 "$swipe_y"
  if ! in_list; then
    echo "the tap opened the chat, going back"
    to_list
  fi
}

# reads the row's notification mode and favorite; a shot name saves a shot with the actions shown
read_row() {
  open_actions
  last_ntf=$(ntf_of "$actions_tree")
  last_fav=$(fav_of "$actions_tree")
  if [ -n "${1:-}" ]; then
    "$ui" shot "$1"
  fi
  close_actions
}

# taps the swipe action with this label
row_action() {
  open_actions
  grep -qF "\"$1\" " <<< "$actions_tree" || fail "no swipe action \"$1\""
  "$ui" tap "$1" 5 || fail "could not tap \"$1\""
  in_list || to_list
}

ntf_action() {
  case "$1" in
    All) echo Mute ;;
    Mentions) echo "Mute all" ;;
    None) echo Unmute ;;
  esac
}

ntf_next() {
  case "$1" in
    All) echo Mentions ;;
    Mentions) echo None ;;
    None) echo All ;;
  esac
}

# the unread badge of the row_name row in a tree: a number within 60 points below the row's name
unread_count() {
  local line ry n
  line=$(grep -F -- "\"$row_name\"" <<< "$1" | head -n 1) || true
  [ -n "$line" ] || {
    echo 0
    return
  }
  ry=$(line_y "$line")
  n=$(grep -E '^StaticText "[0-9]+\+?" ' <<< "$1" | while IFS= read -r l; do
    ly=$(line_y "$l")
    if [ "$ly" -ge "$ry" ] && [ "$ly" -le $((ry + 60)) ]; then
      sed -E 's/^StaticText "([0-9]+)\+?".*/\1/' <<< "$l"
    fi
  done | head -n 1)
  echo "${n:-0}"
}

open_group_chat() {
  to_list
  local line
  line=$(row_line)
  [ -n "$line" ] || fail "no row of $row_name"
  tap_line "$line"
  wait_match '"Arrow Up Circle"|"Mic"|Message|"Join group"|"Connect"' 30 || echo "no compose bar shown"
  sleep 1
}

open_group_info() {
  open_group_chat
  tap_match "^[A-Za-z]+ \"[^\"]*${row_name}[^\"]*\" .* at -?[0-9]+,([0-9]|[1-9][0-9]|1[0-9][0-9]) " || fail "no chat name in the chat toolbar"
  wait_match '"Send receipts"|"Mute all"|"Unmute"|"Mute"' 30 || fail "no chat info"
}

# swipes up until an element matching the regex is between y 100 and 800
find_scroll() {
  local i line y
  for i in 1 2 3 4 5 6 7 8; do
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

# the value next to "Send receipts" in the group info
receipts_value() {
  local t line y
  t=$("$ui" tree)
  line=$(grep -E '"Send receipts"' <<< "$t" | head -n 1) || true
  [ -n "$line" ] || {
    echo unknown
    return
  }
  y=$(line_y "$line")
  grep -E -- "^[A-Za-z]+ \"" <<< "$t" | while IFS= read -r l; do
    ly=$(line_y "$l")
    if [ $((ly - y)) -le 25 ] && [ $((y - ly)) -le 25 ]; then
      grep -oE '"(yes|no|default \((yes|no)\))"' <<< "$l" || true
    fi
  done | head -n 1 | tr -d '"' | grep . || echo unknown
}

# simctl pbcopy timed out once (run 41659973143)
set_clipboard() {
  local i
  for i in 1 2 3 4; do
    if "$ui" clipboard "$1"; then
      return 0
    fi
    echo "clipboard attempt $i failed"
    sleep 5
  done
  fail "could not set the clipboard"
}

# the connect sheet's QR scanner asks for the camera, and the alert covers "Tap to paste link"
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

ntf_presented() {
  grep -c 'NtfManager.userNotificationCenter: willPresent' "$UI_OUT/app.log" || true
}

# Bob, online since the join, is stopped to send one message and stays online 30 s to deliver it; prints how many
# notifications the app presented until the message shows in the chat list, in msg_ntfs
bob_message() {
  local text=$1 before deadline pid
  pid=$(cat "$work/bob.pid")
  kill -INT "$pid" 2> /dev/null || true
  deadline=$((SECONDS + 30))
  while kill -0 "$pid" 2> /dev/null; do
    if [ "$SECONDS" -ge "$deadline" ]; then
      kill -KILL "$pid" 2> /dev/null || true
    fi
    sleep 1
  done
  before=$(ntf_presented)
  bob 30 "/_send #$gid text $text" || fail "Bob could not send \"$text\""
  wait_match "$text" 60 || echo "\"$text\" not shown in the chat list"
  sleep 5
  msg_ntfs=$(($(ntf_presented) - before))
  echo "\"$text\": $msg_ntfs notifications presented"
  grep -E 'NtfManager\.(notifyMessageReceived|userNotificationCenter: willPresent)' "$UI_OUT/app.log" | tail -n 4 || true
}

"$ui" tap "Don’t Allow" 5 || true

# Bob's group with history
bob 1 "/_group 1 $(jq -cn --arg n "$group" '{displayName: $n, fullName: "", groupPreferences: {history: {enable: "on"}}}')" || fail "Bob could not create the group"
gid=$(sqlite3 "$work/bob_chat.db" "SELECT group_id FROM groups ORDER BY group_id DESC LIMIT 1")
[ -n "$gid" ] || fail "no group in Bob's database"
bob 5 "/_create link #$gid" || fail "Bob could not create the group link"
link=$(grep -m 1 -oE 'https://[^ ]+/g#[^ ]+' "$work/out") || link=$(grep -m 1 -oE 'simplex:/contact#[^ ]+' "$work/out") || true
[ -n "$link" ] || fail "no group link in Bob's output"
echo "group link: $link"
# near the size limit, so that each forwarded history batch holds one message
pad=$(printf 'Seeds, soil and rows of beans along the fence. %.0s' $(seq 1 230))
for from in 1 11 21 31 41 51 61 71 81 91; do
  msgs=$(jq -cn --argjson f "$from" --argjson n "$hist_n" --arg pad "$pad" '[range($f; $f + 10) | {msgContent: {type: "text", text: "Garden note \(.) of \($n). \($pad)"}}]')
  bob 2 "/_send #$gid json $msgs" > /dev/null || fail "Bob could not send notes $from+"
done
items=$(sqlite3 "$work/bob_chat.db" "SELECT count(*) FROM chat_items WHERE group_id = $gid AND item_text LIKE 'Garden note %'")
echo "Bob's group has $items notes"
[ "$items" -ge "$hist_n" ] || fail "Bob's group has $items notes, not $hist_n"
peer carol Carol 5 "/c" || fail "Carol could not create a 1-time link"
inv=$(grep -m 1 -oE 'https://[^ ]+/i#[^ ]+' "$work/out") || inv=$(grep -m 1 -oE 'simplex:/invitation#[^ ]+' "$work/out") || true
[ -n "$inv" ] || fail "no 1-time link in Carol's output"
echo "Carol's 1-time link: $inv"
nohup "$cli" -d "$work/carol" -e "/contacts" -t 3600 --user-display-name Carol < /dev/null > "$work/carol-online.log" 2>&1 &
echo $! > "$work/carol.pid"
sleep 5

# B1: join, then Mentions from the chat list while the history arrives
"$ui" layout top
set_clipboard "$link"
"$ui" tap "Connect via link or QR code" 30 || fail "no \"Connect via link or QR code\""
wait_match '"Tap to paste link"' 30 || fail "no connect sheet"
"$ui" shot B1-connect-sheet
tap_paste
wait_match '"Open group"' 90 || fail "no \"Open group\" after pasting the link"
"$ui" shot B1-open-group-alert
"$ui" tap "Open group" 10 || fail "could not tap \"Open group\""
wait_match '"Join group"' 30 || fail "no \"Join group\" button"
tap_match '^Button "Join group" ' || "$ui" tap "Join group" || fail "could not tap \"Join group\""
t_join=$SECONDS
to_list
open_actions
b1_before=$(ntf_of "$actions_tree")
b1_label=$(ntf_action "$b1_before")
unread0=$(unread_count "$actions_tree")
echo "B1: actions open $((SECONDS - t_join)) s after the Join tap, unread $unread0, mode $b1_before; Bob comes online"
# Bob, offline until now, accepts the join and sends the history while the actions are open
nohup "$cli" -d "$work/bob" -e "/groups" -t 3600 --user-display-name Bob < /dev/null > "$work/bob-online.log" 2>&1 &
echo $! > "$work/bob.pid"
t_bob=$SECONDS

deadline=$((SECONDS + 300))
seen=""
while [ "$SECONDS" -lt "$deadline" ]; do
  t=$("$ui" tree)
  unread_seen=$(unread_count "$t")
  if [ "$unread_seen" -ge $((unread0 + 1)) ]; then
    seen=yes
    break
  fi
done
b1_result=""
if [ -z "$seen" ]; then
  "$ui" shot B1-no-history
  b1_result=INVALID
  echo "B1: no history shown in 300 s"
else
  # row updates close the actions, and each tree read takes seconds on the runner: the action is tapped from the
  # tree just read, or the actions are opened again and the button is tapped where it was
  label_line=$(grep -E "^Button \"$b1_label\" " <<< "$t" | head -n 1) || true
  if [ -n "$label_line" ]; then
    tap_line "$label_line"
  else
    echo "B1: the actions closed at unread $unread_seen, opening them again"
    "$ui" swipe 30 "$swipe_y" 230 "$swipe_y"
    tap_line "$(grep -E "^Button \"$b1_label\" " <<< "$actions_tree" | head -n 1)"
  fi
  t_change=$SECONDS
  if ! in_list; then
    echo "B1: the tap opened the chat"
    to_list
  fi
  unread_at_change=$unread_seen
  echo "B1: before=$b1_before, tapped \"$b1_label\" $((t_change - t_bob)) s after Bob came online, unread $unread_at_change"
  seq=""
  saw_old=""
  i=0
  while [ $((SECONDS - t_change)) -lt 45 ]; do
    i=$((i + 1))
    dt=$((SECONDS - t_change))
    read_row "B1-sample-$i"
    seq="$seq ${dt}s:$last_ntf@$(unread_count "$actions_tree")"
    if [ "$dt" -ge 3 ] && [ "$last_ntf" = "$b1_before" ]; then
      saw_old=yes
    fi
  done
  deadline=$((SECONDS + 300))
  prev=-1
  cur_unread=$(unread_count "$("$ui" tree)")
  while [ "$cur_unread" != "$prev" ] && [ "$SECONDS" -lt "$deadline" ]; do
    prev=$cur_unread
    sleep 15
    cur_unread=$(unread_count "$("$ui" tree)")
  done
  echo "B1: unread after the history: $cur_unread"
  read_row B1-after-history
  b1_after_history=$last_ntf
  "$ui" relaunch
  read_row B1-after-restart
  b1_restart=$last_ntf
  echo "B1: samples$seq; after history $b1_after_history; after restart $b1_restart"
  if [ "$b1_restart" != Mentions ] || [ "$unread_at_change" -ge "$cur_unread" ]; then
    b1_result=INVALID
  elif [ -n "$saw_old" ] || [ "$b1_after_history" != Mentions ]; then
    b1_result=BUG
  else
    b1_result=OK
  fi
  echo "SCENARIO: B1 unread_at_change=$unread_at_change/$cur_unread samples=\"${seq# }\" after_history=$b1_after_history after_restart=$b1_restart"
fi
echo "SCENARIO: B1 expected=\"$exp_b1\" observed=\"$b1_result\""

# R1: chat list swipe actions without events
to_list
read_row R1-start
cur=$last_ntf
for target in None All Mentions; do
  n=0
  while [ "$cur" != "$target" ] && [ "$n" -lt 3 ]; do
    row_action "$(ntf_action "$cur")"
    cur=$(ntf_next "$cur")
    n=$((n + 1))
  done
  sleep 10
  read_row "R1-$target-after-10s"
  check "R1-ntf-$target-10s" "$target" "$last_ntf"
  cur=$last_ntf
done
if [ "$last_fav" = fav ]; then
  row_action "Unfav."
  sleep 3
fi
row_action Favorite
sleep 10
read_row R1-favorite-after-10s
check R1-favorite-10s "Mentions fav" "$last_ntf $last_fav"
open_group_chat
"$ui" shot R1-chat-opened
to_list
read_row R1-after-reopening-list
check R1-after-reopening-list "Mentions fav" "$last_ntf $last_fav"
"$ui" relaunch
read_row R1-after-restart
check R1-after-restart "Mentions fav" "$last_ntf $last_fav"

# N1 / N0: a message from Bob without a mention, with Mentions, then with All as the control
n1_text="Garden plain update one"
n0_text="Garden plain update two"
bob_message "$n1_text"
n1_shown=$msg_ntfs
"$ui" shot N1-mentions-message-received
check N1-mentions-notifications 0 "$n1_shown"
read_row N1-mode
check N1-mode Mentions "$last_ntf"
n=0
while [ "$last_ntf" != All ] && [ "$n" -lt 3 ]; do
  n=$((n + 1))
  row_action "$(ntf_action "$last_ntf")"
  read_row
done
bob_message "$n0_text"
n0_shown=$msg_ntfs
"$ui" shot N0-all-message-received
if [ "$n0_shown" = 0 ]; then
  echo "SCENARIO: N0 control expected=\"1 or more\" observed=\"0\" UNVERIFIABLE (no notification in All mode either)"
else
  echo "SCENARIO: N0 control expected=\"1 or more\" observed=\"$n0_shown\" OK"
fi

# R3: a per-group receipts override cleared by "Enable for all"
open_group_info
find_scroll '"Send receipts"' > /dev/null || fail "no Send receipts in the group info"
r3_start=$(receipts_value)
echo "R3: Send receipts shows $r3_start"
t=$("$ui" tree)
sr=$(grep -E '"Send receipts"' <<< "$t" | head -n 1)
sr_y=$(line_y "$sr")
"$ui" tap-xy 330 $((sr_y + 10))
sleep 1
"$ui" shot R3-receipts-menu
tap_match '^[A-Za-z]+ "no" ' || fail "no \"no\" item in the Send receipts menu"
sleep 2
r3_override=$(receipts_value)
"$ui" shot R3-info-override-no
check R3-override-set no "$r3_override"
"$ui" relaunch
tap_match '^Image "Account" .* at [0-9]+,([0-9]|[1-9][0-9]|1[01][0-9]) ' || fail "no profile image in the toolbar"
wait_match '"Settings"' 15 || fail "the user picker did not open"
"$ui" tap Settings || fail "no Settings"
find_scroll '"Your privacy"' > /dev/null || fail "no Your privacy row"
tap_match '"Your privacy"' || fail "could not tap Your privacy"
find_scroll '"More privacy"' > /dev/null || fail "no More privacy row"
tap_match '"More privacy"' || fail "could not tap More privacy"
sw=$(find_scroll '"Small groups \(max 20\)"') || fail "no Small groups switch"
echo "R3: $sw"
sw_y=$(center "$sw")
sw_y=${sw_y#* }
# the switch's centre: 25 points left of the element's right edge (taps at x=360 did not toggle it, run 41730366969)
sw_x=$(sed -E 's/.* at (-?[0-9]+),-?[0-9]+ size ([0-9]+)x.*/\1 \2/' <<< "$sw")
sw_x=$((${sw_x% *} + ${sw_x#* } - 25))
toggle_switch() {
  local v0
  v0=$(switch_value) || v0=""
  "$ui" tap-xy "$sw_x" "$sw_y"
  sleep 3
  if [ "$(switch_value || true)" = "$v0" ]; then
    echo "R3: the tap did not change the switch, dragging its knob"
    "$ui" swipe $((sw_x - 12)) "$sw_y" $((sw_x + 12)) "$sw_y"
    "$ui" swipe $((sw_x + 12)) "$sw_y" $((sw_x - 12)) "$sw_y"
    sleep 2
  fi
}
switch_value() {
  "$ui" tree | grep -F '"Small groups (max 20)"' | grep -oE 'value="[^"]*"' | head -n 1
}
r3_dialog=""
for i in 1 2 3; do
  v=$(switch_value) || v=""
  echo "R3: switch $v"
  if grep -qE 'value="(1|on|On)"' <<< "$v"; then
    toggle_switch
    "$ui" shot "R3-small-groups-off-$i"
    tap_alert_button "Disable (keep overrides)" || true
    continue
  fi
  toggle_switch
  "$ui" shot "R3-small-groups-on-$i"
  if wait_match '"Enable for all"' 10 || tap_alert_button "Enable for all"; then
    r3_dialog=yes
    break
  fi
  for p in 650 680 710 740 770 800 830; do
    if "$ui" point 201 "$p" | grep -qF '"Enable for all"'; then
      r3_dialog=$p
      break 2
    fi
  done
done
if [ -n "$r3_dialog" ]; then
  "$ui" shot R3-enable-for-all-dialog
  if [ "$r3_dialog" = yes ]; then
    tap_match '^[A-Za-z]+ "Enable for all" ' || "$ui" tap "Enable for all" 5 || tap_alert_button "Enable for all" || echo "R3: could not tap \"Enable for all\""
  else
    "$ui" tap-xy 201 "$r3_dialog"
  fi
else
  echo "R3: no \"Enable for all\" dialog found"
fi
sleep 3
"$ui" shot R3-small-groups-enabled
r3_restarted=""
for i in 1 2 3; do
  "$ui" swipe 201 80 201 820
  sleep 2
  if in_list; then
    break
  fi
  "$ui" tap Back 2 || true
done
if ! in_list; then
  r3_restarted=yes
  echo "R3: Settings did not close, restarting the app (the value is then read from the database)"
fi
open_group_info
find_scroll '"Send receipts"' > /dev/null || fail "no Send receipts in the group info"
r3_after=$(receipts_value)
"$ui" shot R3-info-after-enable-for-all
case "$r3_after" in
  "default ("*) r3_obs=default ;;
  *) r3_obs=$r3_after ;;
esac
if [ -n "$r3_dialog" ]; then
  check R3-cleared${r3_restarted:+-after-restart} default "$r3_obs"
else
  echo "SCENARIO: R3-cleared expected=\"default\" observed=\"$r3_obs\" UNVERIFIED (no \"Enable for all\" dialog)"
fi
echo "R3: before $r3_start, override $r3_override, after Enable for all $r3_after"

# V1: mute in the contact's info, then verify the security code
close_sheet
to_list
set_clipboard "$inv"
"$ui" tap Compose || fail "no Compose button"
"$ui" tap "Scan / Paste link" 15 || fail "no \"Scan / Paste link\""
wait_match '"Tap to paste link"' 30 || fail "no connect sheet"
"$ui" shot V1-connect-sheet
tap_paste
wait_match '"Open new chat"|"Connect"' 90 || fail "no \"Open new chat\" after pasting Carol's link"
"$ui" shot V1-open-new-chat-alert
"$ui" tap "Open new chat" 5 || true
wait_match '"Connect"' 30 || fail "no \"Connect\" button"
tap_match '^Button "Connect" ' || "$ui" tap Connect || fail "could not tap \"Connect\""
sleep 3
"$ui" shot V1-connect-tapped
row_name=Carol
v1_ready=""
deadline=$((SECONDS + 300))
while [ "$SECONDS" -lt "$deadline" ]; do
  close_sheet
  to_list
  open_group_info
  t=$("$ui" tree)
  if grep -qF '"Verify security code"' <<< "$t" && grep -E '^[A-Za-z]+ "Mute" ' <<< "$t" | grep -qv ' disabled$'; then
    v1_ready=yes
    break
  fi
  sleep 10
done
v1_result=""
if [ -z "$v1_ready" ]; then
  "$ui" shot V1-not-connected
  v1_result=INVALID
  echo "V1: Carol's info has no enabled Mute and Verify security code after 300 s"
else
  "$ui" shot V1-info-before-mute
  tap_match '^[A-Za-z]+ "Mute" ' || fail "could not tap Mute in Carol's info"
  wait_match '"Unmute"' 15 || echo "V1: no Unmute in the info after Mute"
  "$ui" shot V1-info-muted
  find_scroll '"Verify security code"' > /dev/null || fail "no Verify security code in Carol's info"
  tap_match '"Verify security code"' || fail "could not tap Verify security code"
  wait_match '"Mark verified"' 20 || fail "no Mark verified"
  "$ui" shot V1-security-code
  tap_match '^[A-Za-z]+ "Mark verified" ' || fail "could not tap Mark verified"
  sleep 3
  t=$("$ui" tree)
  v1_info=$(ntf_of "$t")
  "$ui" shot V1-info-after-verify
  close_sheet
  restarted=""
  if ! in_list; then
    "$ui" tap Back 2 || true
    sleep 1
  fi
  if ! in_list; then
    restarted=yes
  fi
  read_row V1-row-after-verify
  v1_row=$last_ntf
  "$ui" relaunch
  read_row V1-row-after-restart
  v1_db=$last_ntf
  echo "SCENARIO: V1 info_after_verify=$v1_info row_after_verify=$v1_row${restarted:+ (read after a restart)} after_restart=$v1_db"
  if [ -n "$restarted" ] || [ "$v1_db" != None ]; then
    v1_result=INVALID
  elif [ "$v1_info" = None ] && [ "$v1_row" = None ]; then
    v1_result=OK
  else
    v1_result=BUG
  fi
fi
echo "SCENARIO: V1 expected=\"$exp_v1\" observed=\"$v1_result\""
row_name=$group

to_list
"$ui" layout reachable

case "$b1_result" in
  BUG) echo "SCENARIO: BUG PRESENT" ;;
  OK) echo "SCENARIO: BUG ABSENT" ;;
  *) echo "SCENARIO: INCONCLUSIVE (B1 $b1_result)" ;;
esac
