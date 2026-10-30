#!/usr/bin/env bash
set -euo pipefail

xcodebuild -version
swift test
sdk_version=$(xcrun --sdk iphonesimulator --show-sdk-version)
if [[ "${sdk_version%%.*}" -lt 27 ]]; then
  echo "An iOS 27 or newer SDK is required; found ${sdk_version}." >&2
  exit 1
fi

xcodebuild \
  -project ios/CampusSchedule.xcodeproj \
  -scheme CampusSchedule \
  -configuration Release \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ios/build \
  CODE_SIGNING_ALLOWED=NO \
  build

mkdir -p build
tar -czf build/CampusSchedule.tar.gz \
  -C ios/build/Build/Products/Release-iphonesimulator CampusSchedule.app
