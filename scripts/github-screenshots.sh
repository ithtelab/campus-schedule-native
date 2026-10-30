#!/usr/bin/env bash
set -euo pipefail

# Select an installed iOS 27+ iPhone; do not silently fall back to an older SDK/runtime.
devices_file=$(mktemp)
xcrun simctl list devices available --json > "$devices_file"
simulator_id=$(node -e '
const fs = require("fs");
const devices = JSON.parse(fs.readFileSync(process.argv[1], "utf8")).devices;
const candidates = Object.entries(devices)
  .filter(([runtime]) => /iOS-(\d+)/.test(runtime) && Number(runtime.match(/iOS-(\d+)/)[1]) >= 27)
  .flatMap(([, items]) => items).filter(item => item.name.startsWith("iPhone") && item.isAvailable);
const selected = candidates.find(item => item.name === "iPhone 17") ?? candidates[0];
if (!selected) { console.error("No available iOS 27+ iPhone simulator"); process.exit(1); }
process.stdout.write(selected.udid);
' "$devices_file")
trap 'xcrun simctl shutdown "$simulator_id" >/dev/null 2>&1 || true' EXIT
xcrun simctl boot "$simulator_id"
xcrun simctl bootstatus "$simulator_id" -b
bash scripts/capture-ui.sh
