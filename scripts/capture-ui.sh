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
  for gallery in desktop lock; do
    SIMCTL_CHILD_CAMPUS_WIDGET_PREVIEW="$gallery" xcrun simctl launch --terminate-running-process booted com.example.CampusSchedule
    sleep 3
    xcrun simctl io booted screenshot "screenshots/widget-${gallery}-${appearance}-preview.png"
  done
done

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
SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=today SIMCTL_CHILD_CAMPUS_PREVIEW_ACCESSIBILITY=1 xcrun simctl launch --terminate-running-process booted com.example.CampusSchedule
sleep 3
xcrun simctl io booted screenshot screenshots/today-accessibility.png
SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=today SIMCTL_CHILD_CAMPUS_PREVIEW_TIME=10:30 xcrun simctl launch --terminate-running-process booted com.example.CampusSchedule
sleep 3
xcrun simctl io booted screenshot screenshots/today-ongoing.png
SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=week SIMCTL_CHILD_CAMPUS_PREVIEW_WEEKEND=1 SIMCTL_CHILD_CAMPUS_PREVIEW_LAYOUT=long xcrun simctl launch --terminate-running-process booted com.example.CampusSchedule
sleep 3
xcrun simctl io booted screenshot screenshots/week-long-text.png

# 读取原生打包资源，并通过实际滚动验证 Section 吸顶，而非只截一张静态卡片。
data_path=$(xcrun simctl get_app_container booted com.example.CampusSchedule data)
cp "$data_path/Documents/campus-assets-smoke.txt" screenshots/campus-assets-test.txt
grep -q '^PASS' screenshots/campus-assets-test.txt
for appearance in light dark; do
  xcrun simctl ui booted appearance "$appearance"
  SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=today SIMCTL_CHILD_CAMPUS_PREVIEW_LAYOUT=dense SIMCTL_CHILD_CAMPUS_PREVIEW_SCROLL=1 xcrun simctl launch --terminate-running-process booted com.example.CampusSchedule
  sleep 3
  grep -q '^PASS' "$data_path/Documents/today-sticky-smoke.txt"
  cp "$data_path/Documents/today-sticky-smoke.txt" "screenshots/today-sticky-${appearance}-test.txt"
  xcrun simctl io booted screenshot "screenshots/today-sticky-${appearance}.png"
done
xcrun simctl ui booted appearance light
SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=today SIMCTL_CHILD_CAMPUS_PREVIEW_LAYOUT=focus-long xcrun simctl launch --terminate-running-process booted com.example.CampusSchedule
sleep 3
xcrun simctl io booted screenshot screenshots/today-long-text.png
SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=today SIMCTL_CHILD_CAMPUS_PREVIEW_TIME=21:00 xcrun simctl launch --terminate-running-process booted com.example.CampusSchedule
sleep 3
xcrun simctl io booted screenshot screenshots/today-finished.png
SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=today SIMCTL_CHILD_CAMPUS_PREVIEW_LAYOUT=empty SIMCTL_CHILD_CAMPUS_PREVIEW_REDUCE_MOTION=1 xcrun simctl launch --terminate-running-process booted com.example.CampusSchedule
sleep 3
xcrun simctl io booted screenshot screenshots/today-empty.png

# 使用独立的个人数据模式检查 SwiftData 写入及进程重启后读回。
SIMCTL_CHILD_CAMPUS_SMOKE_TEST=seed xcrun simctl launch --terminate-running-process booted com.example.CampusSchedule
sleep 3
data_path=$(xcrun simctl get_app_container booted com.example.CampusSchedule data)
grep -q PASS "$data_path/Documents/persistence-smoke.txt"
xcrun simctl terminate booted com.example.CampusSchedule
printf WAIT > "$data_path/Documents/persistence-smoke.txt"
SIMCTL_CHILD_CAMPUS_SMOKE_TEST=reload xcrun simctl launch booted com.example.CampusSchedule
sleep 3
grep -q PASS "$data_path/Documents/persistence-smoke.txt"
cp "$data_path/Documents/persistence-smoke.txt" screenshots/persistence-test.txt
cp "$data_path/Documents/snapshot-smoke.txt" screenshots/shared-snapshot-test.txt
if grep -q '^FAIL' screenshots/shared-snapshot-test.txt; then
  echo 'Shared snapshot round trip failed.' >&2
  exit 1
fi

# 实际向模拟器系统请求 Live Activity，而不是把普通卡片当成灵动岛截图。
SIMCTL_CHILD_CAMPUS_SMOKE_TEST=live xcrun simctl launch --terminate-running-process booted com.example.CampusSchedule
sleep 3
cp "$data_path/Documents/activity-smoke.txt" screenshots/activity-start-test.txt
if grep -q '^PASS' screenshots/activity-start-test.txt; then
  xcrun simctl launch booted com.apple.Preferences
  sleep 3
  xcrun simctl io booted screenshot screenshots/activity-in-background.png
  sleep 22
  xcrun simctl io booted screenshot screenshots/activity-after-end-time.png
  SIMCTL_CHILD_CAMPUS_SMOKE_TEST=live-audit xcrun simctl launch --terminate-running-process booted com.example.CampusSchedule
  sleep 3
  cp "$data_path/Documents/activity-smoke.txt" screenshots/activity-end-audit.txt
fi
