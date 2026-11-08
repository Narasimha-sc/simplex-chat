#!/bin/bash

# PR #8 (fork): the migration upload limit (5 GiB) and the free-space warnings of migration and Export database.
# Checks, in this order, each printed as "CHECK <name> expected=<token> observed=<token>(<details>) MATCH|MISMATCH|INVALID":
#   E1-export-low-storage-cancel     Documents on a 64 MB disk image, 48 MB of zeros in app_files; Export database, Cancel
#                                    base: BUG (no warning, the archive is written and shared)
#                                    PR: OK (warning, no archive, the chat still running); INVALID when the chat was not running
#   E2-export-low-storage-continue   the same, Continue                                    base: BUG  PR: OK (warning, archive)
#   L1-migrate-low-storage-cancel    the same data; Migrate to another device, Archive and upload, Cancel
#                                    base: BUG (no warning, archiving and upload start)    PR: OK (warning, back on Archive and upload)
#   L2-migrate-low-storage-continue  Archive and upload again, Continue                    base: BUG  PR: OK (warning, upload starts)
#   M1-migrate-data-over-limit       disk image detached; 5 GiB + 64 MiB of random bytes in app_files; Archive and upload
#                                    base: BUG ("Error uploading the archive" after the whole export)
#                                    PR: OK ("Database is too large" before archiving)
#                                    INVALID when the runner has under 18 GiB free (data, its copy and the archive)
# The profile is the smoke test's "citester"; the database passphrase is set on the migration screen at the start.
# Exits 0 whatever the checks show; non-zero only when the scenario could not run.

set -euo pipefail

ui=$(dirname "$0")/ui
: "${SIM_UDID:?}" "${UI_OUT:?}"
bundle_id=chat.simplex.app
passphrase=move-test-pass
limit=5368709120
mib=1048576

case "${GITHUB_REF_NAME:-}" in
  *-before) build=base ;;
  *) build="pr" ;;
esac
echo "scenario build: $build (${GITHUB_REF_NAME:-no branch})"

group=$(xcrun simctl get_app_container "$SIM_UDID" "$bundle_id" group.chat.simplex.app)
docs=$(xcrun simctl get_app_container "$SIM_UDID" "$bundle_id" data)/Documents
files=$group/app_files
image=$RUNNER_TEMP/pr8-small-documents.dmg
mounted=""
moved=""
results=""
bugs=0
free_docs=0
echo "app group: $group"
echo "documents: $docs"

fail() {
  echo "SCENARIO ERROR: $1"
  "$ui" shot scenario-error || true
  detach_image
  exit 1
}

detach_image() {
  if [ -n "$mounted" ]; then
    hdiutil detach "$docs" -force > /dev/null 2>&1 || true
    mounted=""
  fi
  if [ -n "$moved" ]; then
    rmdir "$docs" 2> /dev/null || true
    mv "$docs.orig" "$docs" || true
    moved=""
  fi
}

tree() { "$ui" tree 2> /dev/null || true; }

# the first tree line matching the extended regex, tapped at its centre
tap_match() {
  local t line x y w h
  t=$(tree)
  line=$(grep -E -- "$1" <<< "$t" | head -n 1) || true
  if [ -z "$line" ]; then
    return 1
  fi
  read -r x y w h < <(sed -E 's/.* at (-?[0-9]+),(-?[0-9]+) size ([0-9]+)x([0-9]+).*/\1 \2 \3 \4/' <<< "$line")
  "$ui" tap-xy $((x + w / 2)) $((y + h / 2))
}

label() {
  printf '^%s "([^"]*, )?%s(,[^"]*)?" ' "${2:-[A-Za-z]+}" "$1"
}

has() { grep -qiE -- "$1" <<< "$(tree)"; }

wait_match() {
  local want=$1 secs=$2 deadline
  deadline=$((SECONDS + secs))
  while [ "$SECONDS" -lt "$deadline" ]; do
    if has "$want"; then
      return 0
    fi
    sleep 3
  done
  return 1
}

check() {
  local name=$1 expected=$2 observed=$3 result=MISMATCH
  if [ "${observed%%(*}" = INVALID ]; then
    result=INVALID
  elif [ "${observed%%(*}" = "$expected" ]; then
    result=MATCH
  fi
  echo "CHECK $name expected=$expected observed=$observed $result"
  results="$results $name:$result"
  if [ "${observed%%(*}" = BUG ]; then
    bugs=$((bugs + 1))
  fi
  "$ui" shot "$name-result"
}

expected() {
  if [ "$build" = base ]; then echo BUG; else echo OK; fi
}

answer_start_chat() {
  if has '"Start chat\?"'; then
    "$ui" tap Ok 5 || "$ui" tap OK 5 || true
  fi
}

# the chat list with the toolbar (one-hand UI: its profile image is at y >= 750)
to_chat_list() {
  local i
  for i in 1 2 3 4 5 6; do
    answer_start_chat
    if has '^Image "Account" .* at [0-9]+,(7[5-9][0-9]|8[0-9][0-9]) '; then
      return 0
    fi
    "$ui" tap Back 2 > /dev/null 2>&1 || "$ui" tap Done 2 > /dev/null 2>&1 || "$ui" tap Close 2 > /dev/null 2>&1 || true
    sleep 2
  done
  "$ui" relaunch || true
  answer_start_chat
  has '^Image "Account" .* at [0-9]+,(7[5-9][0-9]|8[0-9][0-9]) '
}

open_settings() {
  to_chat_list || fail "no chat list"
  tap_match '^Image "Account" .* at [0-9]+,(7[5-9][0-9]|8[0-9][0-9]) ' || fail "no profile image in the toolbar"
  "$ui" tap Settings 15 || fail "no Settings in the user picker"
  "$ui" wait "Migrate to another device" 30 || fail "Settings did not open"
}

# Settings → Migrate to another device → (set or verify the passphrase) → "Archive and upload"
to_archive_and_upload() {
  if has "$(label "Archive and upload")"; then
    return 0
  fi
  open_settings
  tap_match "$(label "Migrate to another device")" || fail "no Migrate to another device row"
  wait_match 'New passphrase…|Current passphrase…|Archive and upload' 120 || fail "the migration screen shows no passphrase field"
  if has '"New passphrase…"|value="New passphrase…"'; then
    "$ui" tap-value "New passphrase…" 10 || fail "no New passphrase field"
    "$ui" type "$passphrase"
    "$ui" tap-value "Confirm new passphrase…" 10 || fail "no Confirm new passphrase field"
    "$ui" type "$passphrase"
    "$ui" shot set-passphrase
    tap_match "$(label "Set passphrase" Button)" || tap_match "$(label "Set passphrase")" || fail "no Set passphrase button"
    wait_match '"Change database passphrase\?"|"Encrypt database\?"' 20 || fail "no passphrase confirmation alert"
    "$ui" tap Update 5 || "$ui" tap Encrypt 5 || fail "no Update button"
    wait_match '"Database encrypted!"' 120 || fail "no Database encrypted! alert"
    "$ui" tap OK 5 || "$ui" tap Ok 5 || true
  elif has 'Current passphrase…'; then
    "$ui" tap-value "Current passphrase…" 10 || fail "no Current passphrase field"
    "$ui" type "$passphrase"
    tap_match "$(label "Verify passphrase")" || fail "no Verify passphrase button"
  fi
  wait_match "$(label "Archive and upload")" 60 || fail "no Archive and upload"
}

leave_migration() {
  if has "$(label "Cancel migration")"; then
    tap_match "$(label "Cancel migration")" || true
    sleep 5
  fi
  to_chat_list || fail "no chat list after the migration screen"
}

open_database_page() {
  open_settings
  tap_match "$(label "Database passphrase & export")" || {
    tap_match "$(label "Chat data")" || fail "no Chat data row"
    "$ui" wait "Database passphrase & export" 30 || fail "no Chat data page"
    tap_match "$(label "Database passphrase & export")" || fail "no Database passphrase & export row"
  }
  "$ui" wait "Export database" 30 || fail "no Export database button"
}

zips_in_documents() { find "$docs" -maxdepth 1 -name 'simplex-chat.*.zip' 2> /dev/null | wc -l | tr -d ' '; }

attach_image() {
  local avail
  rm -f "$image"
  hdiutil create -size 64m -fs HFS+ -volname SmallDocuments "$image" > /dev/null || fail "hdiutil create"
  echo "::group::Documents before the disk image"
  ls -la "$docs" || true
  echo "::endgroup::"
  if ! hdiutil attach "$image" -mountpoint "$docs" -nobrowse -owners on > /dev/null; then
    mv "$docs" "$docs.orig" || fail "Documents cannot be moved aside"
    moved=1
    mkdir -p "$docs"
    hdiutil attach "$image" -mountpoint "$docs" -nobrowse -owners on > /dev/null || fail "hdiutil attach over Documents"
  fi
  mounted=1
  avail=$(df -k "$docs" | awk 'NR == 2 { print $4 * 1024 }')
  echo "Documents on a disk image: $avail bytes free"
  free_docs=$avail
}

data_bytes() {
  local total=0 f s
  for f in "$files"/* "$group"/assets/wallpapers/* "$group"/simplex_v1_chat.db "$group"/simplex_v1_agent.db; do
    [ -e "$f" ] || continue
    s=$(stat -f %z "$f")
    total=$((total + s))
  done
  echo "$total"
}

# waits for one of: an alert title (first regex), a second-stage label (second regex); prints alert|stage|none
wait_alert_or() {
  local alert=$1 stage=$2 secs=$3 deadline
  deadline=$((SECONDS + secs))
  while [ "$SECONDS" -lt "$deadline" ]; do
    local t
    t=$(tree)
    if grep -qE -- "$alert" <<< "$t"; then echo alert; return; fi
    if [ -n "$stage" ] && grep -qE -- "$stage" <<< "$t"; then echo stage; return; fi
    sleep 2
  done
  echo none
}

share_sheet_open() { has '"Save to Files"|"Copy"|ActivityListView|"AirDrop"'; }

close_share_sheet() {
  local i
  for i in 1 2 3; do
    share_sheet_open || return 0
    "$ui" tap Close 3 > /dev/null 2>&1 || "$ui" swipe 201 300 201 820 || true
    sleep 2
  done
}

storage_alert='"You may not have enough storage"'

# the Run chat toggle of the Database passphrase & export page: running|stopped|unknown, read for up to 20 s
# until it shows the state given as the argument
chat_state() {
  local want=${1:-} t state=unknown deadline=$((SECONDS + 20))
  while [ "$SECONDS" -lt "$deadline" ]; do
    t=$(tree)
    if grep -qE -- "$(label "Chat is running")" <<< "$t"; then state=running
    elif grep -qE -- "$(label "Chat is stopped")" <<< "$t"; then state=stopped
    else
      state=unknown
      "$ui" swipe 201 650 201 350 > /dev/null 2>&1 || true
    fi
    if [ "$state" != unknown ] && { [ -z "$want" ] || [ "$state" = "$want" ]; }; then break; fi
    sleep 2
  done
  echo "$state"
}

export_check() {   # name answer(Cancel|Continue)
  local name=$1 answer=$2 got zips0 zips1 observed shared=0 chat0 chat1 after=stopped
  if [ "$answer" = Cancel ]; then
    after=running
  fi
  open_database_page
  zips0=$(zips_in_documents)
  chat0=$(chat_state running)
  "$ui" shot "$name-start"
  tap_match "$(label "Export database")" || fail "no Export database button"
  got=none
  local deadline=$((SECONDS + 300)) t
  while [ "$SECONDS" -lt "$deadline" ]; do
    t=$(tree)
    if grep -qE -- "$storage_alert" <<< "$t"; then got=alert; break; fi
    if grep -qE -- '"Save to Files"|"Copy"|ActivityListView|"AirDrop"|"Chat database exported"|"Error exporting chat database"' <<< "$t" \
      || [ "$(zips_in_documents)" -gt "$zips0" ]; then got=stage; break; fi
    sleep 2
  done
  "$ui" shot "$name-outcome"
  if [ "$got" = alert ]; then
    "$ui" tap "$answer" 10 || fail "no $answer in the storage alert"
    sleep 5
    share_sheet_open && shared=1
    zips1=$(zips_in_documents)
    "$ui" shot "$name-after-$answer"
    close_share_sheet
    chat1=$(chat_state "$after")
    "$ui" shot "$name-chat-$chat1"
    if [ "$answer" = Cancel ] && [ "$chat0" != running ]; then
      observed="INVALID(warning, Cancel: chat $chat0 before Export database)"
    elif [ "$answer" = Cancel ] && [ "$shared" = 0 ] && [ "$zips1" = "$zips0" ] && [ "$chat1" = running ]; then
      observed="OK(warning, Cancel: no archive, chat $chat0 -> $chat1)"
    elif [ "$answer" = Continue ] && [ "$zips1" -gt "$zips0" ]; then
      observed="OK(warning, Continue: archive written, share sheet $shared, chat $chat0 -> $chat1)"
    else
      observed="OTHER(warning, $answer: archives $zips0 -> $zips1, share sheet $shared, chat $chat0 -> $chat1)"
    fi
  elif [ "$got" = stage ]; then
    sleep 3
    zips1=$(zips_in_documents)
    share_sheet_open && shared=1
    close_share_sheet
    chat1=$(chat_state "$after")
    "$ui" shot "$name-chat-$chat1"
    observed="BUG(no warning: archives $zips0 -> $zips1, share sheet $shared, chat $chat0 -> $chat1, free $free_docs, data $(data_bytes))"
  else
    observed="OTHER(no alert and no share sheet in 300 s)"
  fi
  to_chat_list || true
  check "$name" "$(expected)" "$observed"
}

migration_check() {   # name answer(Cancel|Continue)
  local name=$1 answer=$2 got observed
  if has "$(label "Cancel migration")"; then
    leave_migration
  fi
  to_archive_and_upload
  "$ui" shot "$name-start"
  tap_match "$(label "Archive and upload")" || fail "no Archive and upload"
  got=$(wait_alert_or "$storage_alert" '"Uploading archive"|"Creating archive link"|"Cancel migration"|"Upload failed"|"Preparing upload"' 600)
  "$ui" shot "$name-outcome"
  if [ "$got" = alert ]; then
    "$ui" tap "$answer" 10 || fail "no $answer in the storage alert"
    if [ "$answer" = Cancel ]; then
      sleep 3
      if has "$(label "Archive and upload")"; then observed="OK(warning, Cancel: back on Archive and upload)"
      else observed="OTHER(warning, Cancel: Archive and upload not shown)"; fi
    else
      if wait_match '"Uploading archive"|"Creating archive link"|"Cancel migration"' 600; then observed="OK(warning, Continue: upload started)"
      else observed="OTHER(warning, Continue: no upload in 600 s)"; fi
    fi
  elif [ "$got" = stage ]; then
    observed="BUG(no warning: archiving and upload started, free $free_docs, data $(data_bytes))"
    wait_match '"Cancel migration"|"Upload failed"|"Repeat upload"' 600 || true
  else
    observed="OTHER(no alert and no upload in 600 s)"
  fi
  "$ui" shot "$name-after"
  check "$name" "$(expected)" "$observed"
}

too_large_check() {
  local name=M1-migrate-data-over-limit free size got observed t0
  free=$(df -k "$group" | awk 'NR == 2 { print $4 * 1024 }')
  size=$((limit + 64 * mib))
  echo "runner free space: $free bytes"
  if [ "$free" -lt $((18 * 1024 * mib)) ]; then
    check "$name" "$(expected)" "INVALID(only $free bytes free, under 18 GiB)"
    return
  fi
  head -c "$size" /dev/urandom > "$files/holiday-video-archive.bin"
  echo "data: $(data_bytes) bytes (limit $limit)"
  to_archive_and_upload
  "$ui" shot "$name-start"
  t0=$SECONDS
  tap_match "$(label "Archive and upload")" || fail "no Archive and upload"
  got=$(wait_alert_or '"Database is too large"|"Error uploading the archive"|"Upload failed"|"Error exporting chat database"' '' 2400)
  "$ui" shot "$name-alert"
  local t
  t=$(tree)
  if grep -qF '"Database is too large"' <<< "$t"; then
    observed="OK(Database is too large after $((SECONDS - t0)) s)"
  elif grep -qE '"Error uploading the archive"|"Upload failed"' <<< "$t"; then
    observed="BUG(upload error after $((SECONDS - t0)) s: $(grep -oE '"(Error uploading the archive|Upload failed)"' <<< "$t" | head -n 1))"
  else
    observed="OTHER($got after $((SECONDS - t0)) s)"
  fi
  "$ui" tap OK 5 || "$ui" tap Ok 5 || true
  sleep 2
  "$ui" shot "$name-after"
  rm -f "$files/holiday-video-archive.bin"
  check "$name" "$(expected)" "$observed"
}

xcrun simctl spawn "$SIM_UDID" defaults write "$(xcrun simctl get_app_container "$SIM_UDID" "$bundle_id" data)/Library/Preferences/$bundle_id" localAuthenticationNoticeShown -bool true || true
"$ui" relaunch
answer_start_chat

mkdir -p "$files"
to_archive_and_upload
"$ui" shot passphrase-set
leave_migration

head -c $((48 * mib)) /dev/zero > "$files/trip-notes-backup.txt"
attach_image
echo "data: $(data_bytes) bytes, twice: $((2 * $(data_bytes))), free in Documents: $free_docs"
if [ "$free_docs" -ge $((2 * $(data_bytes))) ]; then
  fail "the disk image has room for twice the data"
fi

export_check E1-export-low-storage-cancel Cancel
export_check E2-export-low-storage-continue Continue
migration_check L1-migrate-low-storage-cancel Cancel
migration_check L2-migrate-low-storage-continue Continue
leave_migration

detach_image
rm -f "$files/trip-notes-backup.txt"
too_large_check
leave_migration

echo "results:$results"
if [ "$bugs" -gt 0 ]; then
  echo "SCENARIO: BUG PRESENT ($bugs checks observed BUG)"
else
  echo "SCENARIO: BUG ABSENT"
fi
