// Windows 也可以生成 EAS 上传前必需的原生工程；不编译 Swift。
import { readdirSync, readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve, relative, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const config = JSON.parse(readFileSync(resolve(root, 'app.json'), 'utf8')).expo;
const target = 'CampusSchedule';
const minimumIOS = config.extra.nativePreview.minimumIOSVersion;
const bundleID = config.ios.bundleIdentifier;
const appGroup = config.extra.nativeAppGroup;
if (!/^group\.[a-zA-Z0-9.-]+$/.test(appGroup)) throw new Error('Invalid app group');
if (!/^[0-9]+\.[0-9]+$/.test(minimumIOS) || !/^[a-zA-Z0-9.-]+$/.test(bundleID)) {
  throw new Error('Invalid native project configuration');
}
const id = key => createHash('sha256').update(key).digest('hex').slice(0, 24).toUpperCase();
const quote = value => JSON.stringify(value);
const files = [];
function collect(directory) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = resolve(directory, entry.name);
    if (entry.isDirectory()) collect(path);
    else if (entry.name.endsWith('.swift')) files.push(relative(root, path).replaceAll('\\', '/'));
  }
}
collect(resolve(root, target));
collect(resolve(root, "Shared"));
files.sort();
const resources = [
  ['CampusSchedule/Resources/CampusArtwork.xcassets', 'folder.assetcatalog'],
  ['CampusSchedule/Resources/Fonts/CampusHand.ttf', 'file'],
  ['CampusSchedule/Resources/Fonts/OFL.txt', 'text'],
  ['CampusSchedule/Resources/PrivacyInfo.xcprivacy', 'text.xml'],
];
for (const [file] of resources) readFileSync(resolve(root, file.endsWith('.xcassets') ? file + '/Contents.json' : file));
if (files.length === 0) throw new Error('No Swift sources found');

const objects = [];
const add = (key, body) => objects.push({ type: body.match(/isa = (\w+);/)[1], text: `${id(key)} /* ${key} */ = { ${body} };` });
const list = keys => `(${keys.map(key => `${id(key)} /* ${key} */,`).join(' ')})`;
for (const file of files) {
  add(`ref:${file}`, `isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${quote('../' + file)}; sourceTree = SOURCE_ROOT;`);
  add(`build:${file}`, `isa = PBXBuildFile; fileRef = ${id(`ref:${file}`)};`);
}
for (const [file, type] of resources) {
  add(`ref:${file}`, `isa = PBXFileReference; lastKnownFileType = ${type}; path = ${quote('../' + file)}; sourceTree = SOURCE_ROOT;`);
  add(`build:${file}`, `isa = PBXBuildFile; fileRef = ${id(`ref:${file}`)};`);
}
add('product', `isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = ${target}.app; sourceTree = BUILT_PRODUCTS_DIR;`);
add('products', `isa = PBXGroup; children = ${list(['product'])}; name = Products; sourceTree = "<group>";`);
add('main', `isa = PBXGroup; children = ${list([...files.map(file => `ref:${file}`), ...resources.map(([file]) => `ref:${file}`), 'products'])}; sourceTree = "<group>";`);
add('sources', `isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ${list(files.map(file => `build:${file}`))}; runOnlyForDeploymentPostprocessing = 0;`);
add('frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;');
add('resources', `isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ${list(resources.map(([file]) => `build:${file}`))}; runOnlyForDeploymentPostprocessing = 0;`);

for (const mode of ['Debug', 'Release']) {
  add(`project:${mode}`, `isa = XCBuildConfiguration; name = ${mode}; buildSettings = {
    SDKROOT = iphoneos;
    IPHONEOS_DEPLOYMENT_TARGET = ${quote(minimumIOS)};
    CLANG_ENABLE_MODULES = YES;
    CLANG_ENABLE_OBJC_ARC = YES;
    SWIFT_VERSION = 6.0;
    DEBUG_INFORMATION_FORMAT = ${mode === 'Debug' ? 'dwarf' : '"dwarf-with-dsym"'};
    SWIFT_OPTIMIZATION_LEVEL = ${mode === 'Debug' ? '"-Onone"' : '"-O"'};
    ${mode === 'Debug' ? 'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)"; ENABLE_TESTABILITY = YES;' : ''}
  };`);
  add(`target:${mode}`, `isa = XCBuildConfiguration; name = ${mode}; buildSettings = {
    PRODUCT_NAME = "$(TARGET_NAME)";
    PRODUCT_BUNDLE_IDENTIFIER = ${quote(bundleID)};
    CAMPUS_APP_GROUP = ${quote(appGroup)};
    PROVISIONING_PROFILE_SPECIFIER = "$(CAMPUS_APP_PROFILE)";
    ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
    MARKETING_VERSION = ${quote(config.version)};
    CURRENT_PROJECT_VERSION = 1;
    GENERATE_INFOPLIST_FILE = YES;
    INFOPLIST_FILE = CampusSchedule-Info.plist;
    CODE_SIGN_ENTITLEMENTS = CampusSchedule.entitlements;
    INFOPLIST_KEY_CFBundleDisplayName = ${quote(config.name)};
    INFOPLIST_KEY_UILaunchScreen_Generation = YES;
    INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
    INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
    INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
    TARGETED_DEVICE_FAMILY = "1,2";
    SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
    CODE_SIGN_STYLE = Automatic;
    SWIFT_EMIT_LOC_STRINGS = YES;
    ENABLE_PREVIEWS = YES;
    LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
  };`);
}
for (const scope of ['project', 'target']) {
  add(`${scope}:configurations`, `isa = XCConfigurationList; buildConfigurations = ${list([`${scope}:Debug`, `${scope}:Release`])}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;`);
}
add('target', `isa = PBXNativeTarget; buildConfigurationList = ${id('target:configurations')}; buildPhases = ${list(['sources', 'frameworks', 'resources'])}; buildRules = (); dependencies = (); name = ${target}; productName = ${target}; productReference = ${id('product')}; productType = "com.apple.product-type.application";`);
add('project', `isa = PBXProject; attributes = { BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2700; }; buildConfigurationList = ${id('project:configurations')}; compatibilityVersion = "Xcode 14.0"; developmentRegion = "zh-Hans"; hasScannedForEncodings = 0; knownRegions = ("zh-Hans", en, Base,); mainGroup = ${id('main')}; productRefGroup = ${id('products')}; projectDirPath = ""; projectRoot = ""; targets = ${list(['target'])};`);

const projectDir = resolve(root, 'ios', `${target}.xcodeproj`);
const schemeDir = resolve(projectDir, 'xcshareddata', 'xcschemes');
mkdirSync(schemeDir, { recursive: true });
const widgetFiles = ['Widgets/ScheduleWidgets.swift', ...files.filter(file => file.startsWith('Shared/'))];
for (const file of widgetFiles) {
  add('widgetref:' + file, 'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ' + quote('../' + file) + '; sourceTree = SOURCE_ROOT;');
  add('widgetbuild:' + file, 'isa = PBXBuildFile; fileRef = ' + id('widgetref:' + file) + ';');
}
add('widgetproduct', 'isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; path = CampusWidgets.appex; sourceTree = BUILT_PRODUCTS_DIR;');
add('widgetgroup', 'isa = PBXGroup; children = ' + list(widgetFiles.map(file => 'widgetref:' + file)) + '; name = Widgets; sourceTree = "<group>";');
add('widgetsources', 'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ' + list(widgetFiles.map(file => 'widgetbuild:' + file)) + '; runOnlyForDeploymentPostprocessing = 0;');
add('widgetprivacy', 'isa = PBXBuildFile; fileRef = ' + id('ref:CampusSchedule/Resources/PrivacyInfo.xcprivacy') + ';');
add('widgetart', 'isa = PBXBuildFile; fileRef = ' + id('ref:CampusSchedule/Resources/CampusArtwork.xcassets') + ';');
add('widgetresources', 'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ' + list(['widgetprivacy', 'widgetart']) + '; runOnlyForDeploymentPostprocessing = 0;');
add('embedfile', 'isa = PBXBuildFile; fileRef = ' + id('widgetproduct') + '; settings = { ATTRIBUTES = (RemoveHeadersOnCopy,); };');
add('embed', 'isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = ""; dstSubfolderSpec = 13; files = ' + list(['embedfile']) + '; name = "Embed App Extensions"; runOnlyForDeploymentPostprocessing = 0;');
add('proxy', 'isa = PBXContainerItemProxy; containerPortal = ' + id('project') + '; proxyType = 1; remoteGlobalIDString = ' + id('widgettarget') + '; remoteInfo = CampusWidgets;');
add('dependency', 'isa = PBXTargetDependency; target = ' + id('widgettarget') + '; targetProxy = ' + id('proxy') + ';');
for (const mode of ['Debug', 'Release']) {
  add('widget:' + mode, 'isa = XCBuildConfiguration; name = ' + mode + '; buildSettings = { PRODUCT_NAME = CampusWidgets; PRODUCT_BUNDLE_IDENTIFIER = ' + quote(bundleID + '.widgets') + '; CAMPUS_APP_GROUP = ' + quote(appGroup) + '; PROVISIONING_PROFILE_SPECIFIER = "$(CAMPUS_WIDGET_PROFILE)"; CODE_SIGN_STYLE = Automatic; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_FILE = Widgets-Info.plist; CODE_SIGN_ENTITLEMENTS = CampusSchedule.entitlements; SKIP_INSTALL = YES; APPLICATION_EXTENSION_API_ONLY = YES; TARGETED_DEVICE_FAMILY = "1,2"; SWIFT_VERSION = 6.0; CURRENT_PROJECT_VERSION = 1; MARKETING_VERSION = ' + quote(config.version) + '; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks"; };');
}
add('widgetconfigs', 'isa = XCConfigurationList; buildConfigurations = ' + list(['widget:Debug', 'widget:Release']) + '; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;');
add('widgettarget', 'isa = PBXNativeTarget; buildConfigurationList = ' + id('widgetconfigs') + '; buildPhases = ' + list(['widgetsources', 'widgetresources']) + '; buildRules = (); dependencies = (); name = CampusWidgets; productName = CampusWidgets; productReference = ' + id('widgetproduct') + '; productType = "com.apple.product-type.app-extension";');
for (const object of objects) {
  if (object.text.startsWith(id('main') + ' ')) object.text = object.text.replace(id('products') + ' /* products */,', id('widgetgroup') + ' /* Widgets */, ' + id('products') + ' /* products */,');
  if (object.text.startsWith(id('products') + ' ')) object.text = object.text.replace(id('product') + ' /* product */,', id('product') + ' /* product */, ' + id('widgetproduct') + ' /* widgetproduct */,');
  if (object.text.startsWith(id('project') + ' ')) object.text = object.text.replace('targets = ' + list(['target']), 'targets = ' + list(['target', 'widgettarget']));
  if (object.text.startsWith(id('target') + ' ')) object.text = object.text.replace('dependencies = ();', 'dependencies = ' + list(['dependency']) + ';').replace('buildPhases = ' + list(['sources','frameworks','resources']), 'buildPhases = ' + list(['sources','frameworks','resources','embed']));
}
const sections = [...new Set(objects.map(object => object.type))].map(type =>
  `/* Begin ${type} section */\n${objects.filter(object => object.type === type).map(object => object.text).join('\n').replace(/[ \t]+$/gm, '')}\n/* End ${type} section */`
).join('\n');
writeFileSync(resolve(projectDir, 'project.pbxproj'), `// !$*UTF8*$!\n{\narchiveVersion = 1;\nclasses = {};\nobjectVersion = 56;\nobjects = {\n${sections}\n};\nrootObject = ${id('project')};\n}\n`);
const reference = `<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="${id('target')}" BuildableName="${target}.app" BlueprintName="${target}" ReferencedContainer="container:${target}.xcodeproj"/>`;
writeFileSync(resolve(schemeDir, `${target}.xcscheme`), `<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">${reference}</BuildActionEntry></BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables/></TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">${reference}</BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">${reference}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
`);
console.log(`Generated ios/${target}.xcodeproj with ${files.length} Swift files (not compiled).`);
