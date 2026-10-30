#!/usr/bin/env bash
set -euo pipefail

for name in APPLE_API_KEY_ID APPLE_API_ISSUER_ID APPLE_API_PRIVATE_KEY APPLE_TEAM_ID APPLE_CERTIFICATE_ID APPLE_DISTRIBUTION_P12 APPLE_DISTRIBUTION_PASSWORD; do
  if [[ -z "${!name:-}" ]]; then echo "Missing GitHub secret: $name" >&2; exit 1; fi
done

export CAMPUS_SIGNING_DIR="${RUNNER_TEMP:?}/campus-signing-${GITHUB_RUN_ID:?}-${GITHUB_RUN_ATTEMPT:?}"
mkdir -p "$CAMPUS_SIGNING_DIR" build
keychain="$CAMPUS_SIGNING_DIR/publishing.keychain-db"
keychain_password=$(openssl rand -hex 32)
echo "::add-mask::$keychain_password"
cleanup() {
  security delete-keychain "$keychain" >/dev/null 2>&1 || true
  rm -f "$CAMPUS_SIGNING_DIR/distribution.p12" "$CAMPUS_SIGNING_DIR/AuthKey_${APPLE_API_KEY_ID}.p8"
}
trap cleanup EXIT

node scripts/apple-connect.mjs profiles
node --input-type=module -e 'import fs from "node:fs"; import path from "node:path"; fs.writeFileSync(path.join(process.env.CAMPUS_SIGNING_DIR,"distribution.p12"),Buffer.from(process.env.APPLE_DISTRIBUTION_P12,"base64"),{mode:0o600});'
security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 3600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
security import "$CAMPUS_SIGNING_DIR/distribution.p12" -P "$APPLE_DISTRIBUTION_PASSWORD" -k "$keychain" -T /usr/bin/codesign -T /usr/bin/security
security list-keychains -d user -s "$keychain" "$HOME/Library/Keychains/login.keychain-db"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain" >/dev/null

for target in app widget; do
  security cms -D -i "$CAMPUS_SIGNING_DIR/$target.mobileprovision" > "$CAMPUS_SIGNING_DIR/$target.plist"
done

# Fail before archiving if either extension/app is missing its actual shared-container authorization.
python3 - <<'PY'
import json, os, pathlib, plistlib, shutil
folder = pathlib.Path(os.environ['CAMPUS_SIGNING_DIR'])
manifest = json.loads((folder / 'manifest.json').read_text())
installed = pathlib.Path.home() / 'Library/MobileDevice/Provisioning Profiles'
installed.mkdir(parents=True, exist_ok=True)
for profile in manifest['profiles']:
    payload = plistlib.loads((folder / (profile['target'] + '.plist')).read_bytes())
    ent = payload['Entitlements']
    assert payload['TeamIdentifier'] == [manifest['teamID']], 'Wrong signing team'
    assert ent['application-identifier'].endswith('.' + profile['identifier']), 'Wrong app identifier'
    assert manifest['appGroup'] in ent.get('com.apple.security.application-groups', []), 'Associate the App Group with BOTH App IDs on developer.apple.com before publishing'
    assert ent.get('get-task-allow', False) is False, 'Development profile is not valid for TestFlight'
    assert 'ProvisionedDevices' not in payload and not payload.get('ProvisionsAllDevices', False), 'Expected App Store profile'
    assert payload['UUID'] == profile['uuid'], 'Unexpected profile UUID'
    shutil.copyfile(folder / (profile['target'] + '.mobileprovision'), installed / (profile['uuid'] + '.mobileprovision'))
    print('PASS: distribution profile and App Group for ' + profile['identifier'])
options = dict(method='app-store-connect', destination='upload', signingStyle='manual', teamID=manifest['teamID'], signingCertificate='Apple Distribution', manageAppVersionAndBuildNumber=False, uploadSymbols=True, provisioningProfiles={p['identifier']:p['uuid'] for p in manifest['profiles']})
(folder / 'ExportOptions.plist').write_bytes(plistlib.dumps(options))
PY

app_profile=$(node -p 'JSON.parse(require("fs").readFileSync(process.env.CAMPUS_SIGNING_DIR+"/manifest.json","utf8")).profiles.find(p=>p.target==="app").uuid')
widget_profile=$(node -p 'JSON.parse(require("fs").readFileSync(process.env.CAMPUS_SIGNING_DIR+"/manifest.json","utf8")).profiles.find(p=>p.target==="widget").uuid')
build_number="${GITHUB_RUN_NUMBER:?}.${GITHUB_RUN_ATTEMPT:?}"
xcodebuild -project ios/CampusSchedule.xcodeproj -scheme CampusSchedule -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/CampusSchedule.xcarchive \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY='Apple Distribution' \
  CAMPUS_APP_PROFILE="$app_profile" CAMPUS_WIDGET_PROFILE="$widget_profile" \
  CURRENT_PROJECT_VERSION="$build_number" archive

codesign --verify --deep --strict build/CampusSchedule.xcarchive/Products/Applications/CampusSchedule.app
xcodebuild -exportArchive -archivePath build/CampusSchedule.xcarchive \
  -exportOptionsPlist "$CAMPUS_SIGNING_DIR/ExportOptions.plist" -exportPath build/testflight-export \
  -authenticationKeyPath "$CAMPUS_SIGNING_DIR/AuthKey_${APPLE_API_KEY_ID}.p8" \
  -authenticationKeyID "$APPLE_API_KEY_ID" -authenticationKeyIssuerID "$APPLE_API_ISSUER_ID"

export CAMPUS_PUBLISHED_BUILD="$build_number"
node --input-type=module - <<'JS'
import fs from 'node:fs';
const app = JSON.parse(fs.readFileSync('app.json','utf8')).expo;
const manifest = JSON.parse(fs.readFileSync(process.env.CAMPUS_SIGNING_DIR+'/manifest.json','utf8'));
fs.writeFileSync('build/testflight-upload.json', JSON.stringify({status:'UPLOADED_AWAITING_APPLE_PROCESSING', appID:manifest.appID, bundleID:app.ios.bundleIdentifier, version:app.version, build:process.env.CAMPUS_PUBLISHED_BUILD, commit:process.env.GITHUB_SHA, uploadedAt:new Date().toISOString()},null,2));
console.log('Upload completed. Apple processing and internal tester access still need confirmation.');
JS
node scripts/apple-connect.mjs status
