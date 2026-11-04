#!/usr/bin/env bash
set -euo pipefail
bundle_id="${1:?Expected app bundle identifier}"

if [[ "${CAMPUS_UI_FOCUS:-full}" == blue-stickers ]]; then
  xcrun simctl ui booted appearance light
  tests=(-only-testing:CampusCourseLinkUITests/CourseLinkUITests/testBlueStickersPreserveTodayLayout)
elif [[ "${CAMPUS_UI_FOCUS:-full}" == appearance-check ]]; then
  xcrun simctl ui booted appearance light
  tests=(-only-testing:CampusCourseLinkUITests/CourseLinkUITests/testAppearanceSwitchesAndDarkImport)
elif [[ "${CAMPUS_UI_FOCUS:-full}" == release-check ]]; then
  tests=(-only-testing:CampusCourseLinkUITests/CourseLinkUITests/testReleaseStartsEmptyAndHasPrivacyPolicy)
elif [[ "${CAMPUS_UI_FOCUS:-full}" == campus-style ]]; then
  tests=(
    -only-testing:CampusCourseLinkUITests/CourseLinkUITests/testAppearanceRehearsalAndStaticMode
    -only-testing:CampusCourseLinkUITests/CourseLinkUITests/testMilestonePreviewAndPin
  )
else
  tests=(-only-testing:CampusCourseLinkUITests/CourseLinkUITests/testSystemCourseLinksShowReadOnlySession)
  SIMCTL_CHILD_CAMPUS_SMOKE_TEST=data-reliability xcrun simctl launch --terminate-running-process booted "$bundle_id"
  sleep 3
  data_path=$(xcrun simctl get_app_container booted "$bundle_id" data)
  cp "$data_path/Documents/data-reliability-smoke.txt" screenshots/data-reliability-smoke.txt
  grep -q '^PASS' screenshots/data-reliability-smoke.txt
  xcrun simctl terminate booted "$bundle_id"
fi

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
  -resultBundlePath build/course-links.xcresult -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO "${tests[@]}" test

if [[ "${CAMPUS_UI_FOCUS:-full}" == appearance-check ]]; then
  xcrun simctl launch --terminate-running-process "$simulator_id" "$bundle_id"
  for appearance in dark light; do
    xcrun simctl ui "$simulator_id" appearance "$appearance"
    sleep 3
    xcrun simctl io "$simulator_id" screenshot "screenshots/appearance-system-$appearance.png"
  done
elif [[ "${CAMPUS_UI_FOCUS:-full}" == blue-stickers ]]; then
  for theme in paper blueStickers; do
    for density in off light rich; do
      SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=today SIMCTL_CHILD_CAMPUS_PREVIEW_THEME="$theme" SIMCTL_CHILD_CAMPUS_PREVIEW_DENSITY="$density" \
        xcrun simctl launch --terminate-running-process "$simulator_id" "$bundle_id"
      sleep 2
      xcrun simctl io "$simulator_id" screenshot "screenshots/decoration-$theme-$density.png"
    done
  done
  for gallery in desktop lock; do
    SIMCTL_CHILD_CAMPUS_WIDGET_PREVIEW="$gallery" SIMCTL_CHILD_CAMPUS_PREVIEW_THEME=blueStickers SIMCTL_CHILD_CAMPUS_PREVIEW_DENSITY=rich \
      xcrun simctl launch --terminate-running-process "$simulator_id" "$bundle_id"
    sleep 3
    xcrun simctl io "$simulator_id" screenshot "screenshots/blue-stickers-widget-$gallery.png"
  done
  SIMCTL_CHILD_CAMPUS_LIVE_PREVIEW=1 SIMCTL_CHILD_CAMPUS_PREVIEW_THEME=blueStickers SIMCTL_CHILD_CAMPUS_PREVIEW_DENSITY=rich \
    xcrun simctl launch --terminate-running-process "$simulator_id" "$bundle_id"
  sleep 3
  xcrun simctl io "$simulator_id" screenshot screenshots/blue-stickers-live-activity.png
fi
