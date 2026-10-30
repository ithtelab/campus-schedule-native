#!/usr/bin/env bash
set -euo pipefail

mkdir -p screenshots
xcrun simctl bootstatus booted -b
xcrun simctl list devices booted --json > screenshots/simulator.json
xcodebuild -version > screenshots/xcode.txt

app_path=$(find ios/build -type d -name 'CampusSchedule.app' -path '*iphonesimulator*' -print -quit)
if [[ -z "$app_path" ]]; then
  echo 'Simulator .app not found; screenshot capture cannot proceed.' >&2
  exit 1
fi

xcrun simctl install booted "$app_path"
xcrun simctl status_bar booted override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100

for appearance in light dark; do
  xcrun simctl ui booted appearance "$appearance"
  for tab in today week settings; do
    SIMCTL_CHILD_CAMPUS_PREVIEW_TAB="$tab" xcrun simctl launch --terminate-running-process booted com.example.CampusSchedule
    sleep 3
    xcrun simctl io booted screenshot "screenshots/${tab}-${appearance}.png"
  done
  for screen in course academic; do
    tab=today
    if [[ "$screen" == academic ]]; then tab=settings; fi
    SIMCTL_CHILD_CAMPUS_PREVIEW_TAB="$tab" SIMCTL_CHILD_CAMPUS_PREVIEW_SHEET="$screen" xcrun simctl launch --terminate-running-process booted com.example.CampusSchedule
    sleep 3
    xcrun simctl io booted screenshot "screenshots/${screen}-${appearance}.png"
  done
done

xcrun simctl ui booted appearance light
SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=week SIMCTL_CHILD_CAMPUS_PREVIEW_WEEKEND=1 xcrun simctl launch --terminate-running-process booted com.example.CampusSchedule
sleep 3
xcrun simctl io booted screenshot screenshots/week-seven-days.png
SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=week SIMCTL_CHILD_CAMPUS_PREVIEW_ACCESSIBILITY=1 xcrun simctl launch --terminate-running-process booted com.example.CampusSchedule
sleep 3
xcrun simctl io booted screenshot screenshots/week-accessibility.png
