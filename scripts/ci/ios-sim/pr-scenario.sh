#!/bin/bash

# Report reason "Inappropriate content". One app, two profiles: the onboarded profile (the owner) and "rita" (a member,
# created in the chat console), in the group "hikers", which rita joins by its link in the chat console. The owner
# posts two messages; rita reports them in the app as "Inappropriate content" and "Spam", and the first one again in
# the chat console with reason=content.
#   I1  the command the app sent for "Inappropriate content" (chat console row): reason=illegal (base) or
#       reason=content (PR); the owner's report items as its core stored them ("report <reason>: <text>")
#   I2  the console report with reason=content, as the owner's "Member reports" show it: "content" (base) or
#       "Inappropriate content" (PR)
#   R   the "Spam" report, as the owner's "Member reports" show it: "Spam" (both)
# Exits 0 whatever the checks show; non-zero only when the scenario could not run.

set -euo pipefail

ui=$(dirname "$0")/ui
: "${SIM_UDID:?}" "${UI_OUT:?}"
group=hikers
member=rita
msg_content="Cheap boots at the scam shop"
msg_spam="Free coins giveaway today"
text_content="fake shop"
text_spam="junk ads"
text_console="trail map leak"
backend_dir=${BACKEND_DIR:-${RUNNER_TEMP:-}/backend}

case "${GITHUB_REF_NAME:-}" in
  *-before) build=base exp_cmd=illegal exp_core=illegal exp_console="content" ;;
  *) build=pr exp_cmd=content exp_core=content exp_console="Inappropriate content" ;;
esac
echo "scenario build: $build (${GITHUB_REF_NAME:-no branch})"

fail() {
  echo "SCENARIO ERROR: $1"
  "$ui" shot scenario-error || true
  exit 1
}

check() {
  local name=$1 expected=$2 observed=$3 result=MISMATCH
  if [ "$observed" = "$expected" ]; then
    result=MATCH
  fi
  echo "CHECK $name expected=\"$expected\" observed=\"$observed\" $result"
}

# x and y of the centre of a tree line
center() {
  local x y w h
  read -r x y w h < <(sed -E 's/.* at (-?[0-9]+),(-?[0-9]+) size ([0-9]+)x([0-9]+).*/\1 \2 \3 \4/' <<< "$1")
  echo "$((x + w / 2)) $((y + h / 2))"
}

row_y() {
  sed -E 's/.* at -?[0-9]+,(-?[0-9]+) size .*/\1/' <<< "$1"
}

tap_line() {
  local c
  c=$(center "$1")
  "$ui" tap-xy "${c% *}" "${c#* }"
}

# the first (or last) tree line matching the extended regex, tapped at its centre
tap_match() {
  local t line
  t=$("$ui" tree) || return 1
  if [ "${2:-first}" = last ]; then
    line=$(grep -E -- "$1" <<< "$t" | tail -n 1) || true
  else
    line=$(grep -E -- "$1" <<< "$t" | head -n 1) || true
  fi
  [ -n "$line" ] || return 1
  tap_line "$line"
}

# taps "Allow Paste" or "Allow" when such an alert is in the tree
answer_alert() {
  local line
  line=$(grep -E '^Button "(Allow Paste|Allow)" ' <<< "$1" | head -n 1) || true
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
    if grep -qiE -- "$want" <<< "$t"; then
      return 0
    fi
    [ "$SECONDS" -lt "$deadline" ] || return 1
    answer_alert "$t"
    sleep 3
  done
}

shot_json() {
  find "$UI_OUT" -maxdepth 1 -name "*-$1.json" | sort | tail -n 1
}

# every label of a shot's tree, one per line
shot_labels() {
  jq -r '.. | objects | .AXLabel? // empty | strings' "$(shot_json "$1")"
}

# the SimpleX Lock notice (an alert missing from the tree) is marked as shown before each start
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

open_user_picker() {
  tap_match "$account_image" || fail "no profile image in the toolbar"
  "$ui" wait Settings 15 || fail "the user picker did not open"
  sleep 1
}

# the toolbar's profile image of the chat list (y >= 750 with the one-hand UI; chat rows carry images with the same label)
account_image='^Image "Account" .* at [0-9]+,(7[5-9][0-9]|8[0-9][0-9]) '

# back to the chat list from a chat or a pushed page; relaunches when "Back" does not get there
to_chat_list() {
  for _ in 1 2 3; do
    if "$ui" tree | grep -qE "$account_image"; then
      return 0
    fi
    "$ui" tap Back 3 || break
    sleep 2
  done
  if ! "$ui" tree | grep -qE "$account_image"; then
    relaunch
  fi
  "$ui" tree | grep -qE "$account_image" || fail "the chat list is not shown"
}

# Settings → app version → Developer → Chat console, from the chat list
open_console() {
  local found=""
  to_chat_list
  open_user_picker
  "$ui" tap Settings || fail "no Settings in the user picker"
  "$ui" wait "Migrate to another device" 30 || fail "Settings did not open"
  for _ in 1 2 3 4 5 6 7 8; do
    if tap_match '"v[0-9][^"]*" .* at [0-9]+,([0-9]|[1-7][0-9]|[1-7][0-9][0-9]) '; then
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

# centre y of the compose field: the send button's row
send_button_y() {
  local line c
  line=$("$ui" tree | grep -E '^Button "Arrow Up Circle" ' | tail -n 1) || true
  [ -n "$line" ] || return 1
  c=$(center "$line")
  echo "${c#* }"
}

field_is() {
  "$ui" tree | grep -qF -- "value=$(jq -rn --arg s "$1" '$s | tojson') "
}

field_contains() {
  "$ui" tree | grep -qiF -- "$1"
}

clear_field() {
  axe key-combo --modifiers 227 --key 4 --udid "$SIM_UDID" > /dev/null 2>&1 || true
  "$ui" key delete 1
}

# puts the text in the compose field (chat console or chat) by pasting it, typing it when pasting fails
put_text() {
  local text=$1 y line
  y=$(send_button_y) || fail "no compose field"
  "$ui" clipboard "$text"
  "$ui" tap-xy 170 "$y"
  axe key-combo --modifiers 227 --key 25 --udid "$SIM_UDID" > /dev/null 2>&1 || echo "Cmd+V failed"
  sleep 1
  if field_is "$text"; then
    return 0
  fi
  echo "Cmd+V did not paste \"$text\", trying the edit menu"
  clear_field
  for _ in 1 2 3; do
    y=$(send_button_y) || fail "no compose field"
    "$ui" tap-xy 170 "$y"
    sleep 1
    line=$("$ui" tree | grep -E '^[A-Za-z]+ "Paste" ' | head -n 1) || true
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
  if [ ${#text} -le 60 ]; then
    echo "pasting failed, typing \"$text\""
    "$ui" type "$text"
    if field_is "$text"; then
      return 0
    fi
  fi
  "$ui" shot input-error
  fail "the compose field does not hold \"$text\""
}

# Button lines below the last row of the command
rows_after() {
  local t=$1 cmd=$2 line cy
  line=$(grep -F -- ", > ${cmd:0:30}\" " <<< "$t" | tail -n 1) || true
  [ -n "$line" ] || return 0
  cy=$(row_y "$line")
  grep -E '^Button "' <<< "$t" | while IFS= read -r l; do
    if [ "$(row_y "$l")" -gt "$cy" ]; then
      echo "$l"
    fi
  done
}

# sends a command in the chat console and waits for a response row matching the regex below the command's row
console_send() {
  local cmd=$1 want=$2 secs=${3:-30} deadline t after
  put_text "$cmd"
  "$ui" tap "Arrow Up Circle" || fail "no send button in the chat console"
  deadline=$((SECONDS + secs))
  while :; do
    t=$("$ui" tree 2> /dev/null) || t=""
    after=$(rows_after "$t" "$cmd")
    if grep -qE -- ", < (\* )?($want)" <<< "$after"; then
      echo "console: $cmd -> $(grep -oE -- ", < (\* )?($want)[^\"]*" <<< "$after" | head -n 1)"
      return 0
    fi
    if [ "$SECONDS" -ge "$deadline" ]; then
      echo "::group::console rows after $cmd"
      echo "$after"
      echo "::endgroup::"
      return 1
    fi
    sleep 2
  done
}

# taps the last (or first) console row matching the regex, scrolling it onto the screen, and saves a shot of its details
open_row() {
  local regex=$1 name=$2 which=${3:-last} line y
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if [ "$which" = first ]; then
      line=$("$ui" tree | grep -E -- "$regex" | head -n 1) || true
    else
      line=$("$ui" tree | grep -E -- "$regex" | tail -n 1) || true
    fi
    [ -n "$line" ] || fail "no console row matching $regex"
    y=$(row_y "$line")
    if [ "$y" -lt 130 ]; then
      "$ui" swipe 201 250 201 600
    elif [ "$y" -gt 775 ]; then
      "$ui" swipe 201 600 201 400
    else
      tap_line "$line"
      sleep 2
      "$ui" shot "$name"
      return 0
    fi
  done
  fail "the console row matching $regex did not come onto the screen"
}

console_back() {
  "$ui" tap Back 5 || tap_match '^Button "[^"]*" .* at 0,(6[0-9]|7[0-9]|8[0-9]|9[0-9]) ' || true
  if ! wait_match '"Arrow Up Circle"' 10; then
    echo "no way back to the chat console, reopening it"
    relaunch
    open_console
  fi
}

open_group() {
  wait_match "\"[^\"]*$group" 60 || fail "no group $group in the chat list"
  tap_match "^[A-Za-z]+ \"[^\"]*${group}[^\"]*\" .* at [0-9]+,(1[0-9][0-9]|[2-6][0-9][0-9]|7[0-3][0-9]) " ||
    tap_match "\"[^\"]*$group" || fail "no row of $group"
  wait_match '"Arrow Up Circle"|"Mic"|Message' 30 || echo "no compose bar shown"
  sleep 2
}

# message bubbles: chat item texts have empty labels in the tree; received ones start at x 60..80, 30 points high or more
bubbles() {
  "$ui" tree | grep -E '^StaticText "" value=null at (6[0-9]|7[0-9]|80),([2-6][0-9][0-9]|7[0-7][0-9]) size [0-9]+x([3-9][0-9]|[1-9][0-9][0-9])$'
}

# the member reports a message in the app: long press, Report, the reason, the text, send
# the message is the bubble at the index from the end (1: the last one)
report_in_app() {
  local msg=$1 reason=$2 text=$3 tag=$4 index=$5 line c opened="" deadline
  deadline=$((SECONDS + 120))
  until [ "$(bubbles | wc -l)" -ge 2 ]; do
    [ "$SECONDS" -lt "$deadline" ] || fail "fewer than 2 message bubbles in the chat"
    sleep 3
  done
  for _ in 1 2; do
    line=$(bubbles | tail -n "$index" | head -n 1)
    echo "reporting \"$msg\": bubble $line"
    c=$(center "$line")
    "$ui" long-press "${c% *}" "${c#* }"
    if "$ui" tap Report 10; then
      opened=yes
      break
    fi
    "$ui" shot "$tag-menu-without-report"
    "$ui" tap-xy 201 150
  done
  [ -n "$opened" ] || fail "no Report item in the menu of \"$msg\""
  "$ui" wait "Report reason?" 15 || echo "no \"Report reason?\" title"
  "$ui" shot "$tag-member-report-reasons"
  "$ui" tap "$reason" 10 || fail "no reason \"$reason\""
  wait_match 'only group moderators will see it' 15 || echo "no report notice in the tree after \"$reason\""
  put_text "$text"
  "$ui" shot "$tag-member-report-compose"
  "$ui" tap "Arrow Up Circle" || fail "no send button"
  if wait_match '"Report sent to moderators"' 20; then
    "$ui" shot "$tag-member-report-sent-alert"
    "$ui" tap Ok 5 || "$ui" tap OK 5 || "$ui" tap "Don't show again" 5 || true
  fi
  sleep 2
  "$ui" shot "$tag-member-report-sent"
}

# the reason the app shows for the report with this text: ReportReason.text of the decoded reason in the console
# details (.illegal "Inappropriate content", .spam "Spam", .unknown(type:) the raw type)
shown_reason() {
  local m t
  m=$(grep -oE -- "report\(text: \"$2\", reason: [A-Za-z.]*ReportReason\.[a-z]+(\(type: \"[^\"]*\"\))?" <<< "$1" | head -n 1) || true
  echo "decoded: ${m:-none}" >&2
  case "$m" in
    "") echo "not found" ;;
    *.illegal) echo "Inappropriate content" ;;
    *.spam) echo "Spam" ;;
    *"unknown(type: "*)
      t=${m##*type: \"}
      echo "${t%\"*}"
      ;;
    *) echo "${m##*.}" ;;
  esac
}

"$ui" tap "Don’t Allow" 5 || true

# both profiles use the test backend's SMP server on the runner (backend.sh start_names), not the preset servers
smp_server=$(cat "$backend_dir/names-server" 2> /dev/null) || fail "no $backend_dir/names-server: start the run with backend=true"
echo "local SMP server: $smp_server"

# setup in the chat console as the onboarded profile
open_console
"$ui" shot console-start
console_send "/smp $smp_server" 'cmdOk' 30 || fail "/smp failed for the owner"
console_send "/smp" 'userServers|userProtoServers' 30 || echo "no answer to /smp"
console_send "/g $group" 'groupCreated' 30 || fail "/g $group failed"
# the core sometimes answers /create link only after minutes: restart the app and try again
linked=""
for attempt in 1 2 3; do
  if console_send "/create link #$group" 'groupLinkCreated' 150; then
    linked=yes
    break
  fi
  echo "/create link: no answer, attempt $attempt"
  "$ui" shot "create-link-no-answer-$attempt"
  relaunch
  open_console
done
[ -n "$linked" ] || fail "/create link failed"
open_row ', < (\* )?groupLinkCreated' setup-group-link
labels=$(shot_labels setup-group-link)
link=$(grep -oE '(https://[^"[:space:])]+|simplex:)/g#[^"[:space:])]+' <<< "$labels" | head -n 1) || true
if [ -z "$link" ]; then
  link=$(grep -oE 'simplex:/contact#/\?[^"[:space:])]+' <<< "$labels" | head -n 1) || true
fi
[ -n "$link" ] || fail "no group link in the details"
owner_gid=$(grep -oE 'groupId: [0-9]+' <<< "$labels" | head -n 1 | grep -oE '[0-9]+') || true
[ -n "$owner_gid" ] || fail "no group id in the details"
echo "owner group id $owner_gid, link $link"
console_back

console_send "/create user $member" 'activeUser' 30 || fail "/create user failed"
console_send "/smp $smp_server" 'cmdOk' 30 || fail "/smp failed for $member"
console_send "/c $link" 'userJoinedGroup' 300 || fail "$member did not join $group"
sleep 10
console_send "/_user 1" 'activeUser' 30 || fail "/_user 1 failed"
console_send "#$group $msg_content" 'newChatItems' 60 || fail "the owner's message was not sent"
console_send "#$group $msg_spam" 'newChatItems' 60 || fail "the owner's message was not sent"
console_send "/user $member" 'activeUser' 30 || fail "/user $member failed"
"$ui" shot setup-console
relaunch

# the member reports in the app
open_group
"$ui" shot member-group-chat
report_in_app "$msg_content" "Inappropriate content" "$text_content" I1 2
to_chat_list
open_group
report_in_app "$msg_spam" "Spam" "$text_spam" R 1
to_chat_list

# the member's console: the commands the app sent, then the console report
open_console
t=""
i1_row=""
for _ in 1 2 3 4 5 6; do
  t=$("$ui" tree)
  i1_row=$(grep -E '^Button "[^"]*, > /_report #[0-9]+ [0-9]+ reason=' <<< "$t" | grep -v 'reason=spam' | head -n 1) || true
  [ -n "$i1_row" ] && break
  "$ui" swipe 201 250 201 600
done
[ -n "$i1_row" ] || fail "no /_report row of the in-app report in the chat console"
r_row=$(grep -E '^Button "[^"]*, > /_report #[0-9]+ [0-9]+ reason=spam' <<< "$t" | head -n 1) || true
gid=$(sed -E 's/.*> \/_report #([0-9]+) ([0-9]+) .*/\1/' <<< "$i1_row")
item_id=$(sed -E 's/.*> \/_report #([0-9]+) ([0-9]+) .*/\2/' <<< "$i1_row")
i1_cmd=$(grep -oE 'reason=[a-z]+' <<< "$i1_row" | head -n 1 | cut -d= -f2)
r_cmd=$(grep -oE 'reason=[a-z]+' <<< "$r_row" | head -n 1 | cut -d= -f2) || true
echo "in-app report rows: $i1_row / $r_row"
console_send "/_report #$gid $item_id reason=content $text_console" 'newChatItems' 30 || echo "the console report got no newChatItems row"
"$ui" shot I2-member-console-report
console_send "/_user 1" 'activeUser' 30 || fail "/_user 1 failed"
open_row "^Button \"[^\"]*, > /_report #$gid $item_id reason=[ic]" I1-member-command-details first
i1_full=$(shot_labels I1-member-command-details | grep -oE '/_report #[0-9]+ [0-9]+ reason=[a-z]+ .*' | head -n 1) || true
echo "I1 command: ${i1_full:-$i1_row}"
relaunch

# the owner's member reports
open_group
tap_match "^Button \"[^\"]*${group}[^\"]*\" .* at -?[0-9]+,([0-9]|[1-9][0-9]|1[0-9][0-9]) " ||
  tap_match "\"[^\"]*${group}[^\"]*\" .* at -?[0-9]+,([0-9]|[1-9][0-9]|1[0-9][0-9]) " || fail "no group name in the chat toolbar"
"$ui" wait "Member reports" 30 || fail "no Member reports in the group info"
"$ui" shot owner-group-info
tap_match '"([^"]*, )?Member reports(,[^"]*)?"' || fail "no Member reports row"
"$ui" wait "Member reports" 15 || echo "no Member reports title"
sleep 8
"$ui" shot I2-owner-member-reports
"$ui" swipe 201 300 201 650
"$ui" shot R-owner-member-reports

# the owner's report items as the core stored them
relaunch
open_console
console_send "/_get chat #$owner_gid content=report count=10" 'apiChat' 30 || echo "no apiChat response"
open_row ', < (\* )?apiChat' I1-owner-core-report-items
core_items=$(shot_labels I1-owner-core-report-items | grep -oE 'itemText: "report [a-z]+: [^"]*"') || true
echo "::group::the owner's report items"
echo "$core_items"
echo "::endgroup::"
i1_core=$(grep -iF "$text_content" <<< "$core_items" | head -n 1 | sed -E 's/itemText: "report ([a-z]+): .*/\1/') || true
i2_core=$(grep -iF "$text_console" <<< "$core_items" | head -n 1 | sed -E 's/itemText: "report ([a-z]+): .*/\1/') || true
labels=$(shot_labels I1-owner-core-report-items)
i2_shown=$(shown_reason "$labels" "$text_console")
r_shown=$(shown_reason "$labels" "$text_spam")
i1_shown=$(shown_reason "$labels" "$text_content")

check I1-member-command-reason "$exp_cmd" "${i1_cmd:-unknown}"
check I1-owner-core-reason "$exp_core" "${i1_core:-unknown}"
check I1-owner-shown "Inappropriate content" "$i1_shown"
check I2-owner-core-reason content "${i2_core:-unknown}"
check I2-owner-shown "$exp_console" "$i2_shown"
check R-member-command-reason spam "${r_cmd:-unknown}"
check R-owner-shown Spam "$r_shown"

if [ "${i1_cmd:-}" = illegal ] || [ "$i2_shown" = content ]; then
  echo "SCENARIO: BUG PRESENT"
elif [ "${i1_cmd:-}" = content ] && [ "$i2_shown" = "Inappropriate content" ]; then
  echo "SCENARIO: BUG ABSENT"
else
  fail "inconclusive: command reason ${i1_cmd:-unknown}, console report shown as $i2_shown"
fi
