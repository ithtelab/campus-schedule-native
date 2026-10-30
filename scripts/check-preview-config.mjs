import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = path => readFileSync(resolve(root, path), 'utf8');
const app = JSON.parse(read('app.json')).expo;
const profile = JSON.parse(read('eas.json')).build.simulator;
const project = read('ios/CampusSchedule.xcodeproj/project.pbxproj');
const scheme = read('ios/CampusSchedule.xcodeproj/xcshareddata/xcschemes/CampusSchedule.xcscheme');
assert.equal(profile.ios.simulator, true, '必须使用模拟器构建');
assert.equal(profile.developmentClient, undefined, '纯 SwiftUI 不需要 Expo dev-client');
assert.equal(profile.ios.scheme, 'CampusSchedule');
assert.ok(project.includes(`PRODUCT_BUNDLE_IDENTIFIER = "${app.ios.bundleIdentifier}";`));
assert.ok(project.includes(`CAMPUS_APP_GROUP = "${app.extra.nativeAppGroup}";`));
assert.ok(read('ios/CampusSchedule-Info.plist').includes('<key>CampusAppGroup</key>'));
assert.ok(read('ios/Widgets-Info.plist').includes('<key>CampusAppGroup</key>'));
assert.ok(read('ios/CampusSchedule.entitlements').includes('$(CAMPUS_APP_GROUP)'));
assert.ok(project.includes('ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;'));
assert.ok(readFileSync(resolve(root, 'CampusSchedule/Resources/CampusArtwork.xcassets/AppIcon.appiconset/AppIcon.png')).length > 1000);
assert.ok(project.includes(`IPHONEOS_DEPLOYMENT_TARGET = "${app.extra.nativePreview.minimumIOSVersion}";`));
assert.ok(read('ios/Podfile').includes(`platform :ios, '${app.extra.nativePreview.minimumIOSVersion}'`));
assert.ok(scheme.includes('BlueprintName="CampusSchedule"'));
const fileRefs = [...new Set([...project.matchAll(/path = "(\.\.\/(?:CampusSchedule|Shared|Widgets)\/[^"\n]+\.swift)";/g)].map(match => match[1]))];
let sourceCount = 0;
function countSources(path) {
  for (const entry of readdirSync(path, { withFileTypes: true })) {
    if (entry.isDirectory()) countSources(resolve(path, entry.name));
    else if (entry.name.endsWith('.swift')) sourceCount++;
  }
}
for (const folder of ['CampusSchedule', 'Shared', 'Widgets']) countSources(resolve(root, folder));
assert.equal(fileRefs.length, sourceCount, '新增 Swift 文件后须重新生成工程');
assert.equal(new Set(fileRefs).size, sourceCount);
for (const ref of fileRefs) readFileSync(resolve(root, 'ios', ref));
for (const file of ['CampusSchedule/Resources/CampusArtwork.xcassets', 'CampusSchedule/Resources/Fonts/CampusHand.ttf']) {
  assert.ok(project.includes(`path = "../${file}"`), '插画和字体必须引用到原生工程');
}
assert.ok(readFileSync(resolve(root, 'CampusSchedule/Resources/Fonts/CampusHand.ttf')).length > 1000);
assert.ok(read('ios/CampusSchedule-Info.plist').includes('<string>CampusHand.ttf</string>'));
console.log(`配置静态检查通过：${sourceCount} 个 Swift 源文件、模拟器目标、Bundle ID 和共享 Scheme 一致。`);
console.log('这不是 Xcode 编译或运行验证。');
