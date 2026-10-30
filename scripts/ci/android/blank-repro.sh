#!/bin/bash

# Usage: scripts/ci/android/blank-repro.sh
# Runs after smoke-test.sh onboarding, with UI_OUT set.

set -uo pipefail

package=chat.simplex.app
prefs_file=$package.SIMPLEX_APP_PREFS.xml
ui=$(dirname "$0")/ui
here=$(cd "$(dirname "$0")" && pwd)
state=${RUNNER_TEMP:-/tmp}/blank-repro
results=$UI_OUT/repro.txt
mkdir -p "$state"
: > "$results"

launch() {
  local activity
  activity=$(adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER "$package" | tail -n 1)
  adb shell am start -W -n "$activity"
}

set_prefs() {
  adb shell am force-stop "$package"
  adb shell "run-as $package cat shared_prefs/$prefs_file 2> /dev/null" > "$state/prefs.xml" || true
  python3 "$here/prefs.py" "$state/prefs.xml" "$@" > "$state/prefs-new.xml"
  adb shell "run-as $package sh -c 'cat > shared_prefs/$prefs_file'" < "$state/prefs-new.xml"
}

marker() {
  adb shell log -t REPRO "$*"
  echo "=== $*"
}

app_texts() {
  "$ui" tree 2> /dev/null | grep -c . || true
}

observe() {
  local name=$1 secs=${2:-45} focus pid
  sleep "$secs"
  "$ui" shot "$name" > /dev/null 2>&1 || true
  focus=$(adb shell dumpsys window | grep -m 1 mCurrentFocus | tr -d '\r')
  pid=$(adb shell pidof "$package" | tr -d '\r')
  echo "$name: pid=${pid:-none} focus=$focus elements=$(app_texts)" | tee -a "$results"
  "$ui" text 2> /dev/null | sed 's/^/    /' | tee -a "$results"
  adb shell dumpsys activity activities | grep -E 'topResumedActivity|ResumedActivity:' | sed 's/^/    act /' | tee -a "$results"
}

marker "S1 cold relaunch"
adb shell am force-stop "$package"
launch
observe s1-cold-relaunch

kill_app() {
  local pid
  pid=$(adb shell pidof "$package" | tr -d '\r')
  echo "killing pid ${pid:-none}"
  [ -n "$pid" ] && adb shell run-as "$package" kill -9 "$pid"
  sleep 3
  echo "pid after kill: $(adb shell pidof "$package" | tr -d '\r')"
}

unlock_device() {
  adb shell input keyevent KEYCODE_WAKEUP
  sleep 2
  adb shell wm dismiss-keyguard
  sleep 3
  adb shell input text 1111
  adb shell input keyevent KEYCODE_ENTER
  sleep 5
  adb shell dumpsys window | grep -m 1 mCurrentFocus
}

marker "S2 kill in background, relaunch from launcher"
adb shell input keyevent KEYCODE_HOME
sleep 3
kill_app
launch
observe s2-bg-kill-relaunch

marker "S3 reboot, launch"
adb reboot
adb wait-for-device
until [ "$(adb shell getprop sys.boot_completed 2> /dev/null | tr -d '\r')" = 1 ]; do sleep 2; done
sleep 10
adb shell svc power stayon true
adb shell wm dismiss-keyguard
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
setsid adb logcat -v threadtime < /dev/null >> "$UI_OUT/app-after-reboot.log" 2>&1 &
launch
observe s3-after-reboot 60

marker "S4 SimpleX Lock, system mode, device PIN set"
adb shell locksettings set-pin 1111
set_prefs PerformLA=true LocalAuthenticationMode=SYSTEM
launch
observe s4-lock-system 30
adb shell input text 1111
adb shell input keyevent KEYCODE_ENTER
observe s4-lock-system-after-pin 30

marker "S5 SimpleX Lock, home and back quickly"
adb shell input keyevent KEYCODE_HOME
sleep 1
launch
observe s5-lock-quick-return 30

marker "S6 SimpleX Lock, prompt open, home, kill, relaunch"
adb shell am force-stop "$package"
launch
sleep 15
"$ui" shot s6-prompt-before-home > /dev/null 2>&1 || true
adb shell input keyevent KEYCODE_HOME
sleep 3
kill_app
launch
observe s6-lock-bg-kill 30

marker "S7 SimpleX Lock, back on the prompt"
adb shell am force-stop "$package"
launch
sleep 15
adb shell input keyevent KEYCODE_BACK
observe s7-lock-back 20
launch
observe s7-lock-back-relaunch 30

marker "S8 SimpleX Lock, reboot, launch"
adb reboot
adb wait-for-device
until [ "$(adb shell getprop sys.boot_completed 2> /dev/null | tr -d '\r')" = 1 ]; do sleep 2; done
sleep 10
adb shell svc power stayon true
unlock_device
setsid adb logcat -v threadtime < /dev/null >> "$UI_OUT/app-after-reboot2.log" 2>&1 &
launch
observe s8-lock-after-reboot 60

marker "S9 SimpleX Lock, device PIN removed"
unlock_device
adb shell locksettings clear --old 1111
adb shell am force-stop "$package"
launch
observe s9-lock-no-credential 30

marker "done"
adb shell run-as "$package" cat "shared_prefs/$prefs_file" > "$UI_OUT/prefs-final.xml" 2> /dev/null || true
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### Blank screen repro"
    echo
    echo '```'
    grep -v '^    ' "$results"
    echo '```'
  } >> "$GITHUB_STEP_SUMMARY"
fi
exit 0
