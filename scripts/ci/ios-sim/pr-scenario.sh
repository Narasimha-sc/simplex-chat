#!/bin/bash

# The fullscreen image viewer and messages marked deleted (batch galdel).
# The onboarded profile creates the group "gallery" in the chat console and sends four images to it with /img
# (galdel/*.png: 1 red, 2 green "DELETED", 3 blue, 4 yellow). In the app, image 2 is marked deleted with
# "Mark deleted for everyone" (full deletion is off in a new group). Image 4 is opened in the fullscreen viewer and
# dragged to the right twice; each image on screen is told by the colour of the screenshot left and right of its text.
#   R  image 4 -> previous: image 3 (both builds)
#   D  image 3 -> previous: image 2, marked deleted (base, BUG PRESENT) or image 1 (PR, BUG ABSENT)
# Exits 0 whatever the checks show; non-zero only when the scenario could not run.

set -euo pipefail

ui=$(dirname "$0")/ui
images=$(cd "$(dirname "$0")/galdel" && pwd)
: "${SIM_UDID:?}" "${UI_OUT:?}"
bundle_id=chat.simplex.app
group=gallery

case "${GITHUB_REF_NAME:-}" in
  *-before) build=base exp_d=green ;;
  *) build=pr exp_d=red ;;
esac
echo "scenario build: $build (${GITHUB_REF_NAME:-no branch})"

fail() {
  echo "SCENARIO ERROR: $1" >&2
  "$ui" shot scenario-error >&2 || true
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

# the first tree line matching the extended regex, tapped at its centre
tap_match() {
  local t line
  t=$("$ui" tree) || return 1
  line=$(grep -E -- "$1" <<< "$t" | head -n 1) || true
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

# the SimpleX Lock notice (an alert missing from the tree) is marked as shown before each start
relaunch() {
  local prefs element
  xcrun simctl terminate "$SIM_UDID" "$bundle_id" 2> /dev/null || true
  prefs=$(xcrun simctl get_app_container "$SIM_UDID" "$bundle_id" data)/Library/Preferences/$bundle_id
  xcrun simctl spawn "$SIM_UDID" defaults write "$prefs" localAuthenticationNoticeShown -bool true || echo "could not mark the SimpleX Lock notice as shown"
  "$ui" relaunch || fail "the app did not restart"
  sleep 3
  element=$("$ui" point 134 523 2> /dev/null || true)
  if grep -qF '"Cancel"' <<< "$element"; then
    echo "alert: SimpleX Lock notice, tapping Cancel"
    "$ui" tap-xy 134 523
  fi
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
  tap_match "$account_image" || fail "no profile image in the toolbar"
  "$ui" wait Settings 15 || fail "the user picker did not open"
  sleep 1
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

clear_field() {
  axe key-combo --modifiers 227 --key 4 --udid "$SIM_UDID" > /dev/null 2>&1 || true
  "$ui" key delete 1
}

# puts the text in the console's compose field by pasting it (Cmd+V, then the edit menu), typing it when pasting fails
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
  echo "pasting failed, typing \"$text\""
  "$ui" type "$text"
  if field_is "$text"; then
    return 0
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

open_group() {
  wait_match "\"$group\"" 60 || fail "no group $group in the chat list"
  tap_match "^[A-Za-z]+ \"$group\" .* at [0-9]+,(1[0-9][0-9]|[2-6][0-9][0-9]|7[0-3][0-9]) " || fail "no row of $group"
  wait_match '"Attachements"|"Arrow Up Circle"' 30 || fail "the chat of $group did not open"
  sleep 2
}

# image bubbles in the chat, top to bottom: unlabelled images 200-299 points wide and 60-199 high, on the screen
image_bubbles() {
  "$ui" tree | grep -E '^Image "" value=null at [0-9]+,[0-9]+ size 2[0-9][0-9]x([6-9][0-9]|1[0-9][0-9])$' |
    while IFS= read -r l; do
      y=$(row_y "$l")
      if [ "$y" -ge 100 ] && [ "$y" -le 790 ]; then
        echo "$y $l"
      fi
    done | sort -n | cut -d' ' -f2-
}

wait_bubbles() {
  local n=$1 deadline=$((SECONDS + 60))
  until [ "$(image_bubbles | wc -l)" -eq "$n" ]; do
    if [ "$SECONDS" -ge "$deadline" ]; then
      image_bubbles
      return 1
    fi
    sleep 3
  done
}

shot_png() {
  find "$UI_OUT" -maxdepth 1 -name "*-$1.png" | sort | tail -n 1
}

# the test image a screenshot shows in the viewer: the colour at x 20 and 380, y 440 (points), outside the image's text
colour_of() {
  local png bmp
  png=$(shot_png "$1")
  [ -n "$png" ] || return 1
  bmp="${RUNNER_TEMP:-/tmp}/galdel-$1.bmp"
  sips -s format bmp "$png" --out "$bmp" > /dev/null || return 1
  python3 -I - "$bmp" << 'EOF'
import struct, sys

data = open(sys.argv[1], "rb").read()
off = struct.unpack_from("<I", data, 10)[0]
width, height = struct.unpack_from("<ii", data, 18)
bpp, compression = struct.unpack_from("<HI", data, 28)
if compression == 3:
    masks = struct.unpack_from("<III", data, 54)
else:
    masks = (0xFF0000, 0xFF00, 0xFF)
bottom_up = height > 0
height = abs(height)
stride = ((bpp * width + 31) // 32) * 4
step = bpp // 8
scale = width / 402


def channel(v, m):
    shift = (m & -m).bit_length() - 1
    return ((v & m) >> shift) * 255 // (m >> shift)


def pixel(x, y):
    row = height - 1 - y if bottom_up else y
    i = off + row * stride + x * step
    v = int.from_bytes(data[i:i + step], "little")
    return [channel(v, m) for m in masks]


refs = {
    "red": (208, 0, 0),
    "green": (0, 160, 0),
    "blue": (0, 64, 224),
    "yellow": (240, 192, 0),
    "black": (0, 0, 0),
    "white": (255, 255, 255),
}
names = []
for px in (20, 380):
    cx, cy = int(px * scale), int(440 * scale)
    samples = [pixel(cx + dx, cy + dy) for dx in range(-4, 5, 2) for dy in range(-4, 5, 2)]
    rgb = [sum(s[k] for s in samples) // len(samples) for k in range(3)]
    name, dist = min(((n, sum((a - b) ** 2 for a, b in zip(rgb, r)) ** 0.5) for n, r in refs.items()), key=lambda t: t[1])
    if dist > 110:
        name = "other"
    print(f"x={px} rgb={rgb[0]},{rgb[1]},{rgb[2]} -> {name}", file=sys.stderr)
    names.append(name)
print(names[0] if names[0] == names[1] else "mixed")
EOF
}

# what the viewer shows: a shot, then its colour; red, green, blue, yellow are images 1-4
viewer_shot() {
  local name=$1 c
  sleep 2
  "$ui" shot "$name" >&2 || return 1
  c=$(colour_of "$name") || return 1
  echo "viewer $name: $c" >&2
  echo "$c"
}

# drag to the previous (older) image: a horizontal drag to the right across the viewer
drag_previous() {
  "$ui" swipe 40 440 360 440 >&2
}

# a drag that leaves the image on screen unchanged is repeated once, before its result counts
drag_and_shoot() {
  local name=$1 before=$2 c
  drag_previous || return 1
  c=$(viewer_shot "$name") || return 1
  if [ "$c" = "$before" ]; then
    echo "the drag left $before on screen, dragging again" >&2
    drag_previous || return 1
    c=$(viewer_shot "$name-second-drag") || return 1
  fi
  echo "$c"
}

"$ui" tap "Don’t Allow" 5 || true

app_files=$(xcrun simctl get_app_container "$SIM_UDID" "$bundle_id" group.chat.simplex.app)/app_files
mkdir -p "$app_files"
cp "$images"/1-red.png "$images"/2-green-deleted.png "$images"/3-blue.png "$images"/4-yellow.png "$app_files"/
echo "test images copied to $app_files"

open_console
"$ui" shot console-start
console_send "/g $group" 'groupCreated|newChatItems' 30 || fail "/g $group failed"
for f in 1-red.png 2-green-deleted.png 3-blue.png 4-yellow.png; do
  console_send "/img #$group $f" 'newChatItems' 60 || fail "/img $f failed"
done
"$ui" shot console-images-sent
relaunch

open_group
wait_bubbles 4 || fail "the chat does not show 4 images"
"$ui" shot chat-four-images

# image 2: long press, Delete, Mark deleted for everyone
line=$(image_bubbles | sed -n 2p)
echo "image 2 bubble: $line"
c=$(center "$line")
"$ui" long-press "${c% *}" "${c#* }"
"$ui" shot image2-menu
"$ui" tap Delete 10 || fail "no Delete in the menu of image 2"
"$ui" wait "Mark deleted for everyone" 15 || fail "no \"Mark deleted for everyone\" (full deletion on, or no broadcast delete)"
"$ui" shot image2-delete-dialog
"$ui" tap "Mark deleted for everyone" 10 || fail "could not tap \"Mark deleted for everyone\""
wait_bubbles 3 || fail "the chat does not show 3 images after image 2 was marked deleted"
sleep 2
"$ui" shot chat-image2-marked-deleted

# image 4 in the viewer
line=$(image_bubbles | sed -n 3p)
echo "image 4 bubble: $line"
tap_line "$line"
opened=$(viewer_shot viewer-opened-image4) || fail "no viewer screenshot or colour"
[ "$opened" = yellow ] || fail "the viewer does not show image 4 (yellow) but $opened"

r=$(drag_and_shoot viewer-R-dragged-from-image4 yellow) || fail "the first drag or its screenshot failed"
d=$(drag_and_shoot viewer-D-dragged-from-image3 "$r") || fail "the second drag or its screenshot failed"

check R-image4-previous blue "$r"
check D-image3-previous "$exp_d" "$d"

if [ "$r" != blue ]; then
  fail "inconclusive: the drag from image 4 showed $r, not image 3 (blue)"
fi
case "$d" in
  green) echo "SCENARIO: BUG PRESENT (the drag from image 3 showed image 2, which is marked deleted)" ;;
  red) echo "SCENARIO: BUG ABSENT (the drag from image 3 skipped image 2, marked deleted, and showed image 1)" ;;
  *) fail "inconclusive: the drag from image 3 showed $d" ;;
esac
