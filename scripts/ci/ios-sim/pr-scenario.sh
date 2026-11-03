#!/bin/bash

# Member reports preference text on Group preferences, as the owner of a new group "hikers".
#   E  English footer of the Member reports row: "Allow to report messsages to moderators." (base) or
#      "Allow to report messages to moderators." (PR)
#   D  the same footer with the app language German: "Melden von Nachrichten an Moderatoren erlauben." (both)
# Exits 0 whatever the checks show; non-zero only when the scenario could not run.

set -euo pipefail

ui=$(dirname "$0")/ui
: "${SIM_UDID:?}" "${UI_OUT:?}"
bundle_id=chat.simplex.app
group=hikers
exp_de="Melden von Nachrichten an Moderatoren erlauben."

case "${GITHUB_REF_NAME:-}" in
  *-before) build=base exp_en="Allow to report messsages to moderators." ;;
  *) build=pr exp_en="Allow to report messages to moderators." ;;
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
  echo "CHECK $name build=$build expected=\"$expected\" observed=\"$observed\" $result"
}

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

tap_match() {
  local t line
  t=$("$ui" tree) || return 1
  if [ "${2:-first}" = last ]; then
    line=$(grep -iE -- "$1" <<< "$t" | tail -n 1) || true
  else
    line=$(grep -iE -- "$1" <<< "$t" | head -n 1) || true
  fi
  [ -n "$line" ] || return 1
  tap_line "$line"
}

answer_alert() {
  local line
  line=$(grep -E '^Button "(Allow|Erlauben)" ' <<< "$1" | head -n 1) || true
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

# the first label of a shot's tree that matches the extended regex
shot_label() {
  jq -r '.. | objects | .AXLabel? // empty | strings' "$(shot_json "$1")" | grep -E -- "$2" | head -n 1 || true
}

toolbar_title="^Button \"[^\"]*${group}[^\"]*\" .* at -?[0-9]+,([0-9]|[1-9][0-9]|1[0-9][0-9]) "

open_chat_from_list() {
  wait_match "\"[^\"]*$group" 90 || fail "no $group in the chat list"
  tap_match "^[A-Za-z]+ \"[^\"]*${group}[^\"]*\" .* at -?[0-9]+,(1[0-9][0-9]|[2-6][0-9][0-9]|7[0-3][0-9]) " ||
    fail "no row of $group in the chat list"
}

# the group name in the chat toolbar opens the group info, which shows the preferences row with this label
open_group_info() {
  local label=$1
  for _ in 1 2 3; do
    wait_match "$toolbar_title" 30 || fail "no group name in the chat toolbar"
    sleep 2
    tap_match "$toolbar_title" || fail "no group name in the chat toolbar"
    if wait_match "\"([^\"]*, )?$label" 15; then
      return 0
    fi
    for _ in 1 2 3; do
      "$ui" swipe 201 650 201 350
      if wait_match "\"([^\"]*, )?$label" 3; then
        return 0
      fi
    done
    "$ui" shot "no-group-info"
  done
  fail "no \"$label\" in the group info"
}

# taps the row with this label in the group info, scrolling it onto the screen
open_row() {
  local label=$1 line y
  for _ in 1 2 3 4 5 6; do
    line=$("$ui" tree | grep -E -- "^[A-Za-z]+ \"([^\"]*, )?$label(,[^\"]*)?\" " | head -n 1) || true
    if [ -n "$line" ]; then
      y=$(row_y "$line")
      if [ "$y" -ge 100 ] && [ "$y" -le 760 ]; then
        tap_line "$line"
        sleep 2
        return 0
      fi
    fi
    "$ui" swipe 201 650 201 350
  done
  fail "no row \"$label\" on the screen"
}

# scrolls Group preferences until the Member reports footer is on the screen, takes the shot and sets footer_text
footer_text=""
reports_footer() {
  local footer=$1 row=$2 name=$3 line y
  footer_text=""
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    line=$("$ui" tree | grep -E -- "^[A-Za-z]+ \"$footer\" " | head -n 1) || true
    if [ -z "$line" ]; then
      line=$("$ui" tree | grep -E -- "^[A-Za-z]+ \"([^\"]*, )?$row(,[^\"]*)?\" " | head -n 1) || true
    fi
    if [ -n "$line" ]; then
      y=$(row_y "$line")
      if [ "$y" -ge 150 ] && [ "$y" -le 680 ]; then
        "$ui" shot "$name"
        footer_text=$(shot_label "$name" "^$footer\$")
        echo "$name: footer \"$footer_text\""
        return 0
      fi
      if [ "$y" -lt 150 ]; then
        "$ui" swipe 201 350 201 500
        continue
      fi
    fi
    "$ui" swipe 201 650 201 400
  done
  "$ui" shot "$name-not-found"
  fail "the Member reports row did not come onto the screen"
}

"$ui" tap "Don’t Allow" 5 || true

# E: the owner creates the group and opens Group preferences
"$ui" tap Compose || fail "no Compose button"
"$ui" tap "Create group" 30 || fail "no Create group item"
"$ui" tap-value "Enter group name…" 30 || fail "no group name field"
"$ui" type "$group"
"$ui" shot new-group
tap_match '^Button "Create group" ' last || fail "no Create group button"
"$ui" tap Skip 30 || echo "no Skip button"
sleep 3
"$ui" shot group-created
if ! wait_match "$toolbar_title" 10; then
  echo "the new group's chat is not open, opening it from the chat list"
  open_chat_from_list
fi
open_group_info "Group preferences"
"$ui" shot E-owner-group-info
open_row "Group preferences"
"$ui" shot E-owner-group-preferences-top
reports_footer "[^\"]*report[^\"]* to moderators\\." "Member reports" E-owner-group-preferences-member-reports
en=$footer_text

# D: the app restarts in German and the owner opens Gruppen-Präferenzen
xcrun simctl terminate "$SIM_UDID" "$bundle_id" 2> /dev/null || true
prefs=$(xcrun simctl get_app_container "$SIM_UDID" "$bundle_id" data)/Library/Preferences/$bundle_id
xcrun simctl spawn "$SIM_UDID" defaults write "$prefs" localAuthenticationNoticeShown -bool true || echo "could not mark the SimpleX Lock notice as shown"
xcrun simctl spawn "$SIM_UDID" defaults write "$prefs" AppleLanguages -array de || echo "could not set AppleLanguages in the app defaults"
xcrun simctl launch "$SIM_UDID" "$bundle_id" -AppleLanguages "(de)" -AppleLocale de_DE > /dev/null
sleep 5
element=$("$ui" point 134 523 2> /dev/null || true)
if grep -qE '"(Cancel|Abbrechen)"' <<< "$element"; then
  echo "alert: SimpleX Lock notice, tapping it away"
  "$ui" tap-xy 134 523
fi
"$ui" shot D-chat-list
open_chat_from_list
open_group_info "Gruppen-Präferenzen"
"$ui" shot D-owner-group-info
open_row "Gruppen-Präferenzen"
"$ui" shot D-owner-group-preferences-top
reports_footer "[^\"]*Moderatoren[^\"]*" "Mitglieder-Meldungen" D-owner-group-preferences-member-reports
de=$footer_text

check E-owner-reports-footer "$exp_en" "${en:-not in the tree}"
check D-owner-reports-footer-de "$exp_de" "${de:-not in the tree}"

case "$en" in
  *messsages*) echo "SCENARIO: BUG PRESENT" ;;
  "Allow to report messages to moderators.") echo "SCENARIO: BUG ABSENT" ;;
  *) echo "SCENARIO: INCONCLUSIVE, the footer text is not in the tree: read the screenshots" ;;
esac
