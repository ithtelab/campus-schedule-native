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

# XCTest opens the actual URL, accepts the system confirmation, and asserts the visible UI.
simulator_id=$(node -p 'Object.values(JSON.parse(require("fs").readFileSync("screenshots/simulator.json","utf8")).devices).flat().find(d=>d.state==="Booted").udid')
export_results() {
  if [[ -d build/course-links.xcresult ]]; then
    xcrun xcresulttool export attachments --path build/course-links.xcresult --output-path screenshots/course-link-attachments || true
    xcrun xcresulttool get test-results summary --path build/course-links.xcresult > screenshots/course-links-test-summary.json || true
  fi
}
trap export_results EXIT
xcodebuild -project ios/CampusSchedule.xcodeproj -scheme CampusCourseLinks -configuration Release \
  -destination "platform=iOS Simulator,id=$simulator_id" -derivedDataPath ios/build \
  -resultBundlePath build/course-links.xcresult -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
