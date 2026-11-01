#!/usr/bin/env bash
set -euo pipefail

mkdir -p screenshots
bundle_id=$(node -p "JSON.parse(require(\"fs\").readFileSync(\"app.json\",\"utf8\")).expo.ios.bundleIdentifier")
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
    SIMCTL_CHILD_CAMPUS_WIDGET_PREVIEW="$gallery" xcrun simctl launch --terminate-running-process booted "$bundle_id"
    sleep 3
    xcrun simctl io booted screenshot "screenshots/widget-${gallery}-${appearance}-preview.png"
  done
done

for appearance in light dark; do
  xcrun simctl ui booted appearance "$appearance"
  for tab in today week settings; do
    SIMCTL_CHILD_CAMPUS_PREVIEW_TAB="$tab" xcrun simctl launch --terminate-running-process booted "$bundle_id"
    sleep 3
    xcrun simctl io booted screenshot "screenshots/${tab}-${appearance}.png"
  done
  for screen in course academic; do
    tab=today
    if [[ "$screen" == academic ]]; then tab=settings; fi
    SIMCTL_CHILD_CAMPUS_PREVIEW_TAB="$tab" SIMCTL_CHILD_CAMPUS_PREVIEW_SHEET="$screen" xcrun simctl launch --terminate-running-process booted "$bundle_id"
    sleep 3
    xcrun simctl io booted screenshot "screenshots/${screen}-${appearance}.png"
  done
  # 新增功能页面：学期列表、导入、考试安排。
  for screen in terms import exams; do
    SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=settings SIMCTL_CHILD_CAMPUS_PREVIEW_SHEET="$screen" xcrun simctl launch --terminate-running-process booted "$bundle_id"
    sleep 3
    xcrun simctl io booted screenshot "screenshots/${screen}-${appearance}.png"
  done
  # 单双周角标与调课提示。
  SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=week SIMCTL_CHILD_CAMPUS_PREVIEW_LAYOUT=changes xcrun simctl launch --terminate-running-process booted "$bundle_id"
  sleep 3
  xcrun simctl io booted screenshot "screenshots/week-changes-${appearance}.png"
  # 课表顶部状态条：正在上课 / 下一节。
  SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=week SIMCTL_CHILD_CAMPUS_PREVIEW_TIME=10:30 xcrun simctl launch --terminate-running-process booted "$bundle_id"
  sleep 3
  xcrun simctl io booted screenshot "screenshots/week-now-class-${appearance}.png"
  SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=week SIMCTL_CHILD_CAMPUS_PREVIEW_TIME=12:00 xcrun simctl launch --terminate-running-process booted "$bundle_id"
  sleep 3
  xcrun simctl io booted screenshot "screenshots/week-now-upcoming-${appearance}.png"
  # 今日页顶部的考试倒计时条。
  SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=today SIMCTL_CHILD_CAMPUS_PREVIEW_TIME=10:30 SIMCTL_CHILD_CAMPUS_PREVIEW_EXAMS=1 xcrun simctl launch --terminate-running-process booted "$bundle_id"
  sleep 3
  xcrun simctl io booted screenshot "screenshots/today-exam-banner-${appearance}.png"
  # 今日页收尾的三种状态：有课未上完、全部上完、当天无课。
  SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=today SIMCTL_CHILD_CAMPUS_PREVIEW_TIME=10:30 SIMCTL_CHILD_CAMPUS_PREVIEW_SCROLL=1 xcrun simctl launch --terminate-running-process booted "$bundle_id"
  sleep 3
  xcrun simctl io booted screenshot "screenshots/today-ending-pending-${appearance}.png"
  SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=today SIMCTL_CHILD_CAMPUS_PREVIEW_TIME=21:00 SIMCTL_CHILD_CAMPUS_PREVIEW_SCROLL=1 xcrun simctl launch --terminate-running-process booted "$bundle_id"
  sleep 3
  xcrun simctl io booted screenshot "screenshots/today-ending-done-${appearance}.png"
  SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=today SIMCTL_CHILD_CAMPUS_PREVIEW_LAYOUT=empty SIMCTL_CHILD_CAMPUS_PREVIEW_SCROLL=1 xcrun simctl launch --terminate-running-process booted "$bundle_id"
  sleep 3
  xcrun simctl io booted screenshot "screenshots/today-ending-empty-${appearance}.png"
  if [[ "$appearance" == dark ]]; then
    SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=today SIMCTL_CHILD_CAMPUS_PREVIEW_TIME=10:30 xcrun simctl launch --terminate-running-process booted "$bundle_id"
    sleep 3
    xcrun simctl io booted screenshot screenshots/today-ongoing-dark.png
    SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=today SIMCTL_CHILD_CAMPUS_PREVIEW_TIME=21:00 xcrun simctl launch --terminate-running-process booted "$bundle_id"
    sleep 3
    xcrun simctl io booted screenshot screenshots/today-finished-dark.png
    SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=today SIMCTL_CHILD_CAMPUS_PREVIEW_SHEET=detail xcrun simctl launch --terminate-running-process booted "$bundle_id"
    sleep 3
    xcrun simctl io booted screenshot screenshots/course-detail-dark.png
  fi
done

xcrun simctl ui booted appearance light
SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=week SIMCTL_CHILD_CAMPUS_PREVIEW_WEEKEND=1 xcrun simctl launch --terminate-running-process booted "$bundle_id"
sleep 3
xcrun simctl io booted screenshot screenshots/week-seven-days.png
SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=week SIMCTL_CHILD_CAMPUS_PREVIEW_ACCESSIBILITY=1 xcrun simctl launch --terminate-running-process booted "$bundle_id"
sleep 3
xcrun simctl io booted screenshot screenshots/week-accessibility.png
SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=today SIMCTL_CHILD_CAMPUS_PREVIEW_ACCESSIBILITY=1 xcrun simctl launch --terminate-running-process booted "$bundle_id"
sleep 3
xcrun simctl io booted screenshot screenshots/today-accessibility.png
SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=today SIMCTL_CHILD_CAMPUS_PREVIEW_TIME=10:30 xcrun simctl launch --terminate-running-process booted "$bundle_id"
sleep 3
xcrun simctl io booted screenshot screenshots/today-ongoing.png
SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=week SIMCTL_CHILD_CAMPUS_PREVIEW_WEEKEND=1 SIMCTL_CHILD_CAMPUS_PREVIEW_LAYOUT=long xcrun simctl launch --terminate-running-process booted "$bundle_id"
sleep 3
xcrun simctl io booted screenshot screenshots/week-long-text.png

# 读取原生打包资源，并通过实际滚动验证 Section 吸顶，而非只截一张静态卡片。
data_path=$(xcrun simctl get_app_container booted "$bundle_id" data)
cp "$data_path/Documents/campus-assets-smoke.txt" screenshots/campus-assets-test.txt
grep -q '^PASS' screenshots/campus-assets-test.txt
# 课程卡片不再吸顶，改为验证长列表滚动到底部的排版。
for appearance in light dark; do
  xcrun simctl ui booted appearance "$appearance"
  SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=today SIMCTL_CHILD_CAMPUS_PREVIEW_LAYOUT=dense SIMCTL_CHILD_CAMPUS_PREVIEW_SCROLL=1 xcrun simctl launch --terminate-running-process booted "$bundle_id"
  sleep 3
  xcrun simctl io booted screenshot "screenshots/today-scrolled-${appearance}.png"
done
xcrun simctl ui booted appearance light
SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=today SIMCTL_CHILD_CAMPUS_PREVIEW_LAYOUT=focus-long xcrun simctl launch --terminate-running-process booted "$bundle_id"
sleep 3
xcrun simctl io booted screenshot screenshots/today-long-text.png
SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=today SIMCTL_CHILD_CAMPUS_PREVIEW_TIME=21:00 xcrun simctl launch --terminate-running-process booted "$bundle_id"
sleep 3
xcrun simctl io booted screenshot screenshots/today-finished.png
SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=today SIMCTL_CHILD_CAMPUS_PREVIEW_LAYOUT=empty SIMCTL_CHILD_CAMPUS_PREVIEW_REDUCE_MOTION=1 xcrun simctl launch --terminate-running-process booted "$bundle_id"
sleep 3
xcrun simctl io booted screenshot screenshots/today-empty.png

# Record the real native frame player. It uses the same action entry points as avatar/course buttons.
xcrun simctl ui booted appearance dark
SIMCTL_CHILD_CAMPUS_CHARACTER_PREVIEW=smoke xcrun simctl launch --terminate-running-process booted "$bundle_id"
xcrun simctl io booted recordVideo --codec=h264 screenshots/campus-interactions.mp4 &
record_pid=$!
sleep 48
kill -INT "$record_pid"
wait "$record_pid" || true
cp "$data_path/Documents/campus-interaction-smoke.txt" screenshots/campus-interaction-test.txt
grep -q '^PASS' screenshots/campus-interaction-test.txt
if grep -q '^FAIL' screenshots/campus-interaction-test.txt; then exit 1; fi
xcrun simctl io booted screenshot screenshots/campus-interaction-finished.png
xcrun simctl ui booted appearance light

# Regression proofs for real decoded frames, constrained activity content and non-destructive toss.
for style in boy girl; do
  SIMCTL_CHILD_CAMPUS_CHARACTER_PREVIEW=frames SIMCTL_CHILD_CAMPUS_FRAME_STYLE="$style" xcrun simctl launch --terminate-running-process booted "$bundle_id"
  sleep 3
  xcrun simctl io booted screenshot "screenshots/frames-${style}.png"
done
SIMCTL_CHILD_CAMPUS_LIVE_PREVIEW=1 xcrun simctl launch --terminate-running-process booted "$bundle_id"
sleep 3
xcrun simctl io booted screenshot screenshots/live-layout-preview.png
cp "$data_path/Documents/live-layout-smoke.txt" screenshots/live-layout-test.txt
if grep -q '^FAIL' screenshots/live-layout-test.txt; then exit 1; fi

# 使用独立的个人数据模式检查 SwiftData 写入及进程重启后读回。
SIMCTL_CHILD_CAMPUS_SMOKE_TEST=seed xcrun simctl launch --terminate-running-process booted "$bundle_id"
sleep 3
data_path=$(xcrun simctl get_app_container booted "$bundle_id" data)
grep -q PASS "$data_path/Documents/persistence-smoke.txt"
xcrun simctl terminate booted "$bundle_id"
printf WAIT > "$data_path/Documents/persistence-smoke.txt"
SIMCTL_CHILD_CAMPUS_SMOKE_TEST=reload xcrun simctl launch booted "$bundle_id"
sleep 3
grep -q PASS "$data_path/Documents/persistence-smoke.txt"
cp "$data_path/Documents/persistence-smoke.txt" screenshots/persistence-test.txt
cp "$data_path/Documents/snapshot-smoke.txt" screenshots/shared-snapshot-test.txt
if grep -q '^FAIL' screenshots/shared-snapshot-test.txt; then
  echo 'Shared snapshot round trip failed.' >&2
  exit 1
fi

# Verify the normal demo launch independently of the fixed-time screenshot route.
SIMCTL_CHILD_CAMPUS_DEMO_SMOKE=1 xcrun simctl launch --terminate-running-process booted "$bundle_id"
sleep 3
cp "$data_path/Documents/demo-edition-smoke.txt" screenshots/demo-edition-test.txt
grep -q '^PASS' screenshots/demo-edition-test.txt
xcrun simctl io booted screenshot screenshots/demo-edition-week.png
SIMCTL_CHILD_CAMPUS_DEMO_SCREEN=today xcrun simctl launch --terminate-running-process booted "$bundle_id"
sleep 3
xcrun simctl io booted screenshot screenshots/demo-edition-today.png
SIMCTL_CHILD_CAMPUS_SMOKE_TEST=reload xcrun simctl launch --terminate-running-process booted "$bundle_id"
sleep 3
grep -q '^PASS' "$data_path/Documents/persistence-smoke.txt"
cp "$data_path/Documents/persistence-smoke.txt" screenshots/personal-data-after-demo-test.txt

# 实际向模拟器系统请求 Live Activity，而不是把普通卡片当成灵动岛截图。
SIMCTL_CHILD_CAMPUS_SMOKE_TEST=live xcrun simctl launch --terminate-running-process booted "$bundle_id"
sleep 3
cp "$data_path/Documents/activity-smoke.txt" screenshots/activity-start-test.txt
if grep -q '^PASS' screenshots/activity-start-test.txt; then
  xcrun simctl launch booted com.apple.Preferences
  sleep 3
  xcrun simctl io booted screenshot screenshots/activity-in-background.png
  sleep 22
  xcrun simctl io booted screenshot screenshots/activity-after-end-time.png
  SIMCTL_CHILD_CAMPUS_SMOKE_TEST=live-audit xcrun simctl launch --terminate-running-process booted "$bundle_id"
  sleep 3
  cp "$data_path/Documents/activity-smoke.txt" screenshots/activity-end-audit.txt
fi
SIMCTL_CHILD_CAMPUS_SMOKE_TEST=live-intent xcrun simctl launch --terminate-running-process booted "$bundle_id"
sleep 3
cp "$data_path/Documents/activity-smoke.txt" screenshots/activity-end-intent-test.txt
if grep -q '^FAIL' screenshots/activity-end-intent-test.txt; then exit 1; fi
