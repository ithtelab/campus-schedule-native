#!/usr/bin/env bash
set -euo pipefail

# App Store 只接受固定的几档尺寸，模拟器默认机型的屏幕往往不达标（例如 6.3"
# 的 iPhone 17 就不能作为主截图）。这里显式挑最大屏的 Pro Max，并回读实际
# 像素尺寸做断言，避免打完包才发现尺寸不被接受。
mkdir -p appstore-screenshots
bundle_id=$(node -p "JSON.parse(require(\"fs\").readFileSync(\"app.json\",\"utf8\")).expo.ios.bundleIdentifier")

devices_file=$(mktemp)
xcrun simctl list devices available --json > "$devices_file"
simulator_id=$(node -e '
const fs = require("fs");
const devices = JSON.parse(fs.readFileSync(process.argv[1], "utf8")).devices;
const candidates = Object.entries(devices)
  .filter(([runtime]) => /iOS-(\d+)/.test(runtime) && Number(runtime.match(/iOS-(\d+)/)[1]) >= 27)
  .flatMap(([, items]) => items).filter(item => item.name.startsWith("iPhone") && item.isAvailable);
// 优先 6.9" 的 Pro Max；没有就退到 6.7" 档，两者都是 App Store 接受的主截图尺寸。
const preferred = candidates.find(item => /iPhone \d+ Pro Max/.test(item.name));
const selected = preferred ?? candidates.sort((a, b) => b.name.localeCompare(a.name))[0];
if (!selected) { console.error("No available iOS 27+ iPhone simulator"); process.exit(1); }
console.error(`Selected simulator: ${selected.name} (${selected.udid})`);
process.stdout.write(selected.udid);
' "$devices_file")
trap 'xcrun simctl shutdown "$simulator_id" >/dev/null 2>&1 || true' EXIT

xcrun simctl boot "$simulator_id"
xcrun simctl bootstatus "$simulator_id" -b
xcrun simctl ui "$simulator_id" appearance light
# 固定状态栏，避免出现"充电中""无服务"这类与产品无关的噪声。
xcrun simctl status_bar "$simulator_id" override --time '9:41' --dataNetwork wifi \
  --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100

app_path=$(find ios/build -type d -name 'CampusSchedule.app' -path '*iphonesimulator*' -print -quit)
if [[ -z "$app_path" ]]; then
  echo 'Simulator .app not found; run build-native-simulator.sh first.' >&2
  exit 1
fi

xcrun simctl install "$simulator_id" "$app_path"

shoot() {
  local name="$1"; shift
  # 环境变量必须通过 env 前缀传给 xcrun 本身：shell 函数无法被 env 执行。
  env "$@" xcrun simctl launch --terminate-running-process "$simulator_id" "$bundle_id" >/dev/null
  # 等首屏稳定：预置数据 + 手绘字体加载完成后画面才不再跳动。
  sleep 4
  xcrun simctl io "$simulator_id" screenshot "appstore-screenshots/$name.png"
}

# 五张图覆盖产品全部主张：课程安排、当天进度、纪念事件、人物主题、课程详情。
# 全部使用 App 自带的演示学期，不涉及任何真实用户数据。
shoot "01-week" SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=week
shoot "02-today" SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=today SIMCTL_CHILD_CAMPUS_PREVIEW_TIME=10:30
shoot "03-milestones" SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=settings SIMCTL_CHILD_CAMPUS_PREVIEW_SHEET=milestones
shoot "04-appearance" SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=settings SIMCTL_CHILD_CAMPUS_PREVIEW_SHEET=appearance
shoot "05-detail" SIMCTL_CHILD_CAMPUS_PREVIEW_TAB=today SIMCTL_CHILD_CAMPUS_PREVIEW_SHEET=detail

# 尺寸校验：任何一张不在 App Store 接受范围内就直接失败，不要上传后才发现。
node -e '
const { readdirSync, readFileSync } = require("fs");
const { join } = require("path");
const allowed = new Set([
  "1320x2868", // 6.9"
  "1290x2796", "1284x2778", // 6.7" / 6.5"
  "1242x2688",
]);
let failed = false;
for (const file of readdirSync("appstore-screenshots").filter(f => f.endsWith(".png"))) {
  const buffer = readFileSync(join("appstore-screenshots", file));
  const width = buffer.readUInt32BE(16), height = buffer.readUInt32BE(20);
  const key = `${width}x${height}`;
  const ok = allowed.has(key);
  if (!ok) failed = true;
  console.log(`${file} ${key} ${ok ? "OK" : "NOT AN ACCEPTED APP STORE SIZE"}`);
}
process.exit(failed ? 1 : 0);
'
