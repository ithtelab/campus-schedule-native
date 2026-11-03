#!/usr/bin/env bash
set -euo pipefail
bundle_id="${1:?Expected app bundle identifier}"

# Real app process check; the store is in memory and never reads/writes personal data.
SIMCTL_CHILD_CAMPUS_SMOKE_TEST=data-reliability xcrun simctl launch --terminate-running-process booted "$bundle_id"
sleep 3
data_path=$(xcrun simctl get_app_container booted "$bundle_id" data)
cp "$data_path/Documents/data-reliability-smoke.txt" screenshots/data-reliability-smoke.txt
grep -q '^PASS' screenshots/data-reliability-smoke.txt
xcrun simctl terminate booted "$bundle_id"

# Cold launch via the URL entry point, without preview routing or a preselected sheet.
xcrun simctl ui booted appearance light
xcrun simctl openurl booted 'campusschedule://course?id=math-mon&term=demo-term-v1'
sleep 5
xcrun simctl io booted screenshot screenshots/course-link-cold-light.png
xcrun simctl openurl booted 'campusschedule://course?id=english-mon&term=demo-term-v1'
sleep 4
xcrun simctl io booted screenshot screenshots/course-link-second-light.png

for appearance in light dark; do
  xcrun simctl ui booted appearance "$appearance"
  SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=today SIMCTL_CHILD_CAMPUS_PREVIEW_SHEET=course SIMCTL_CHILD_CAMPUS_COURSE_LINK_SMOKE=1 \
    xcrun simctl launch --terminate-running-process booted "$bundle_id"
  sleep 4
  xcrun simctl io booted screenshot "screenshots/course-link-editor-before-${appearance}.png"
  data_path=$(xcrun simctl get_app_container booted "$bundle_id" data)
  cp "$data_path/Documents/course-link-fixture.json" screenshots/course-link-fixture.json
  course_url=$(node -p 'JSON.parse(require("fs").readFileSync("screenshots/course-link-fixture.json","utf8")).course')
  second_url=$(node -p 'JSON.parse(require("fs").readFileSync("screenshots/course-link-fixture.json","utf8")).secondCourse')
  missing_url=$(node -p 'JSON.parse(require("fs").readFileSync("screenshots/course-link-fixture.json","utf8")).missing')
  xcrun simctl openurl booted "$course_url"
  sleep 5
  xcrun simctl io booted screenshot "screenshots/course-link-from-editor-${appearance}.png"
  xcrun simctl openurl booted "$second_url"
  sleep 4
  xcrun simctl io booted screenshot "screenshots/course-link-repeated-${appearance}.png"
  xcrun simctl openurl booted "$missing_url"
  sleep 4
  xcrun simctl io booted screenshot "screenshots/course-link-unavailable-${appearance}.png"
done
