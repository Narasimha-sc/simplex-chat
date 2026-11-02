#!/bin/bash

# Import of a file that is not a chat archive: Settings → Chat data → Database passphrase & export → Import database
# → holiday-notes.zip (plain text) → Import. Before the import a second profile "Alice laptop" is created;
# after the import alert and an app restart the scenario looks for that profile.
#   BUG PRESENT: the profile is gone after the restart (the app deleted the chat data before the import failed)
#   BUG ABSENT: the profile is still there
# The document picker offers only .zip files (DatabaseView fileImporter, allowedContentTypes [.zip]), so the text file
# has the .zip extension. It is put in the Files app's "On My iPhone" folder: the File Provider Storage folder of the
# app group group.com.apple.FileProvider.LocalStorage.
# Exits 0 whatever the result; non-zero only when the scenario could not run.

set -euo pipefail

ui=$(dirname "$0")/ui
: "${SIM_UDID:?}" "${UI_OUT:?}"
profile="Alice laptop"
file_name=holiday-notes.zip

fail() {
  echo "SCENARIO ERROR: $1"
  "$ui" shot scenario-error || true
  exit 1
}

# the first tree line matching the extended regex, tapped at its centre
tap_match() {
  local t line x y w h
  t=$("$ui" tree) || true
  line=$(grep -E -- "$1" <<< "$t" | head -n 1) || true
  if [ -z "$line" ]; then
    return 1
  fi
  read -r x y w h < <(sed -E 's/.* at (-?[0-9]+),(-?[0-9]+) size ([0-9]+)x([0-9]+).*/\1 \2 \3 \4/' <<< "$line")
  "$ui" tap-xy $((x + w / 2)) $((y + h / 2))
}

# an element (of the type, any by default) whose label is the text, alone or among comma-separated parts
label() {
  printf '^%s "([^"]*, )?%s(,[^"]*)?" ' "${2:-[A-Za-z]+}" "$1"
}

wait_match() {
  local want=$1 secs=$2 deadline t
  deadline=$((SECONDS + secs))
  while [ "$SECONDS" -lt "$deadline" ]; do
    t=$("$ui" tree 2> /dev/null) || t=""
    if grep -qiE -- "$want" <<< "$t"; then
      return 0
    fi
    sleep 3
  done
  return 1
}

# the toolbar's profile image: chat rows have images with the same label, the toolbar is at y >= 750 in the one-hand UI
open_user_picker() {
  tap_match '^Image "Account" .* at [0-9]+,(7[5-9][0-9]|8[0-9][0-9]) ' || fail "no profile image in the toolbar"
  "$ui" wait Settings 15 || fail "the user picker did not open"
  sleep 1
}

dismiss_profiles_notice() {
  if wait_match '"Make profile private!"' 5; then
    "$ui" tap Ok 5 || "$ui" tap OK 5 || true
  fi
}

put_file() {
  local group dir meta
  group=$(xcrun simctl get_app_container "$SIM_UDID" com.apple.DocumentsApp groups 2> /dev/null | awk '$1 == "group.com.apple.FileProvider.LocalStorage" { print $2 }') || true
  if [ -z "$group" ]; then
    for meta in "$HOME/Library/Developer/CoreSimulator/Devices/$SIM_UDID/data/Containers/Shared/AppGroup"/*/.com.apple.mobile_container_manager.metadata.plist; do
      if [ "$(plutil -extract MCMMetadataIdentifier raw "$meta" 2> /dev/null)" = group.com.apple.FileProvider.LocalStorage ]; then
        group=$(dirname "$meta")
      fi
    done
  fi
  [ -n "$group" ] || fail "no app group group.com.apple.FileProvider.LocalStorage"
  dir="$group/File Provider Storage"
  mkdir -p "$dir"
  printf 'Holiday notes\nBook the ferry for Friday.\nPack sunscreen and the blue umbrella.\n' > "$dir/$file_name"
  echo "file for the document picker: $dir/$file_name"
  ls -la "$dir"
}

put_file

# a second profile, the data to lose
open_user_picker
"$ui" tap "Your chat profiles" || fail "no Your chat profiles in the user picker"
"$ui" wait "Add profile" 30 || fail "no Add profile"
tap_match "$(label "Add profile")" || fail "no Add profile row"
"$ui" wait "Create profile" 30 || fail "no profile creation page"
"$ui" tap-value "Enter your name…" 10 || echo "name field not found by its placeholder, typing into the focused field"
"$ui" type "$profile"
"$ui" find "$profile" || fail "the name field does not show \"$profile\""
"$ui" shot new-profile-name
tap_match "$(label "Create profile" Button)" || tap_match "$(label "Create profile")" || fail "no Create profile button"
dismiss_profiles_notice
"$ui" wait "Add profile" 30 || fail "the profile list did not come back after Create profile"
"$ui" find "$profile" || fail "the profile list does not show \"$profile\""
"$ui" shot profiles-before-import
"$ui" relaunch

open_user_picker
"$ui" shot user-picker-before-import
"$ui" tap Settings || fail "no Settings in the user picker"
"$ui" wait "Chat data" 30 || fail "no Chat data row in Settings"
tap_match "$(label "Chat data")" || fail "no Chat data row"
"$ui" wait "Database passphrase & export" 30 || fail "no Chat data page"
tap_match "$(label "Database passphrase & export")" || fail "no Database passphrase & export row"
"$ui" wait "Import database" 30 || fail "no Import database button"
"$ui" shot database-page-before-import
tap_match "$(label "Import database")" || fail "no Import database button"

# The document picker runs in another process: its elements are missing from the tree, so they are found by hit-testing
# points (ui point). Its tab bar has Recents, Shared and Browse; Browse is at 287,822 (run 41480991631).
# prints "x y", the centre of the first element matching the regex that a point, row by row, hits; a point lists
# the elements of its container too (run 41509337800: the probe 140,218 listed a file icon at 10..132)
find_point() {
  local regex=$1 xs=$2 x y e line ex ey w h
  for y in $(seq 130 22 790); do
    for x in $xs; do
      e=$("$ui" point "$x" "$y" 2> /dev/null) || e=""
      line=$(grep -iE -- "$regex" <<< "$e" | head -n 1) || line=""
      if [ -n "$line" ]; then
        echo "point $x,$y: $line" >&2
        read -r ex ey w h < <(sed -E 's/.* at (-?[0-9]+),(-?[0-9]+) size ([0-9]+)x([0-9]+).*/\1 \2 \3 \4/' <<< "$line")
        echo "$((ex + w / 2)) $((ey + h / 2))"
        return 0
      fi
    done
  done
  return 1
}

picker_tap() {
  local p
  p=$(find_point "$1" "$2") || return 1
  # shellcheck disable=SC2086
  "$ui" tap-xy $p
  sleep 2
}

sleep 3
"$ui" shot document-picker
echo "::group::document picker elements at sample points"
for y in 166 300 500 822; do "$ui" point 201 "$y" || true; done
"$ui" point 287 822 || true
echo "::endgroup::"
"$ui" tap-xy 287 822
sleep 2
"$ui" shot document-picker-browse
picker_tap 'On My iPhone' "100 200" || fail "the document picker shows no On My iPhone location"
"$ui" shot document-picker-on-my-iphone
if ! picker_tap 'holiday' "70 140 200 260 330"; then
  "$ui" tap-xy 201 166
  "$ui" type holiday
  "$ui" key return
  sleep 2
  "$ui" shot document-picker-search
  picker_tap 'holiday' "70 140 200 260 330" || fail "the document picker did not show $file_name"
fi
if ! wait_match '"Import chat database\?"' 15; then
  "$ui" tap Open 5 || true
fi
wait_match '"Import chat database\?"' 30 || fail "no Import chat database? alert"
"$ui" shot import-confirm
"$ui" tap Import || fail "no Import button in the alert"

wait_match 'Error importing chat database|Error deleting chat database|Chat database imported|Error stopping chat' 180 || fail "no alert after the import"
"$ui" shot import-alert
alert=$("$ui" tree | grep -E 'Error|exception|archive|Restart' || true)
echo "::group::import alert"
echo "$alert"
echo "::endgroup::"
"$ui" tap Ok 10 || "$ui" tap OK 5 || echo "no Ok in the import alert, the restart closes it"
sleep 2
"$ui" shot after-import-ok

# restart the app: a kept database opens with the profile, a deleted one leaves the app without profiles
xcrun simctl terminate "$SIM_UDID" chat.simplex.app 2> /dev/null || true
xcrun simctl launch "$SIM_UDID" chat.simplex.app > /dev/null
# a database with an active user opens with the chat stopped and the "Start chat?" alert (initializeChat), which hides
# the chat list from the tree (run 41532724611)
deadline=$((SECONDS + 120))
while [ "$SECONDS" -lt "$deadline" ]; do
  t=$("$ui" tree 2> /dev/null) || t=""
  if grep -qF '"Compose"' <<< "$t"; then
    break
  fi
  if grep -qF '"Start chat?"' <<< "$t"; then
    echo "after the restart: Start chat? alert (the database has an active user)"
    "$ui" shot start-chat-alert
    "$ui" tap Ok 5 || true
  fi
  sleep 3
done
sleep 3
"$ui" shot after-restart-chats
after=$("$ui" tree || true)
if grep -qF '"Compose"' <<< "$after"; then
  open_user_picker
  "$ui" shot after-restart-profiles
  after=$after$'\n'$("$ui" tree || true)
fi

echo "import alert: $(grep -oE '"(Error[^"]*|Chat database imported)"' <<< "$alert" | head -n 1)"
if grep -qiF "$profile" <<< "$after"; then
  echo "after the restart the profile \"$profile\" is shown"
  echo "SCENARIO: BUG ABSENT"
else
  echo "after the restart the profile \"$profile\" is not shown"
  echo "SCENARIO: BUG PRESENT"
fi
