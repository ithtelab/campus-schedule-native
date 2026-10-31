// Apple publishing helpers. Private material stays in ignored local files or CI secrets.
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { sign, randomBytes, X509Certificate } from 'node:crypto';
import { execFileSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const local = resolve(root, '.tool-cache/apple');
const configFile = resolve(local, 'config.json');
const localConfig = existsSync(configFile) ? JSON.parse(readFileSync(configFile, 'utf8')) : {};
const app = JSON.parse(readFileSync(resolve(root, 'app.json'), 'utf8')).expo;
const bundle = app.ios.bundleIdentifier;
const metadata = {
  keyID: process.env.APPLE_API_KEY_ID ?? localConfig.keyID,
  issuerID: process.env.APPLE_API_ISSUER_ID ?? localConfig.issuerID,
  teamID: process.env.APPLE_TEAM_ID ?? localConfig.teamID,
  certificateID: process.env.APPLE_CERTIFICATE_ID ?? localConfig.certificateID,
};
function need(value, label) { if (!value) throw new Error(`Missing ${label}`); return value; }
need(metadata.keyID, 'Apple API Key ID'); need(metadata.issuerID, 'Apple Issuer ID'); need(metadata.teamID, 'Apple Team ID');
if (!/^[A-Z0-9]{10}$/.test(metadata.keyID) || !/^[A-Z0-9]{10}$/.test(metadata.teamID) || !/^[a-f0-9-]{36}$/i.test(metadata.issuerID)) throw new Error('Invalid Apple identifiers');
const privateKey = process.env.APPLE_API_PRIVATE_KEY ?? readFileSync(resolve(local, `AuthKey_${metadata.keyID}.p8`), 'utf8');
function token() {
  const now = Math.floor(Date.now() / 1000);
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  const payload = `${encode({ alg: 'ES256', kid: metadata.keyID, typ: 'JWT' })}.${encode({ iss: metadata.issuerID, iat: now - 10, exp: now + 900, aud: 'appstoreconnect-v1' })}`;
  return `${payload}.${sign('sha256', Buffer.from(payload), { key: privateKey, dsaEncoding: 'ieee-p1363' }).toString('base64url')}`;
}
async function api(path, { method = 'GET', data, query } = {}) {
  if (!path.startsWith('/v1/')) throw new Error('Invalid Apple API path');
  const url = new URL(path, 'https://api.appstoreconnect.apple.com');
  if (query) url.search = new URLSearchParams(query).toString();
  const result = await fetch(url, { method, headers: { Authorization: `Bearer ${token()}`, 'Content-Type': 'application/json' }, body: data ? JSON.stringify({ data }) : undefined, signal: AbortSignal.timeout(60000) });
  if (result.status === 204) return { data: [] };
  const body = await result.json();
  if (!result.ok) {
    const error = new Error(`Apple ${result.status}: ${(body.errors ?? []).map(item => `${item.code}: ${item.detail ?? item.title}`).join('; ')}`);
    error.httpStatus = result.status;
    if (path === '/v1/betaAppReviewSubmissions' && method === 'POST') {
      const diagnostic = { timestamp: new Date().toISOString(), method, path, status: result.status, errors: body.errors };
      writeFileSync(resolve(local, 'beta-review-error.json'), JSON.stringify(diagnostic, null, 2), { mode: 0o600 });
      console.error(JSON.stringify(diagnostic));
    }
    throw error;
  }
  return body;
}
function saveConfig() {
  mkdirSync(local, { recursive: true });
  Object.assign(localConfig, metadata);
  writeFileSync(configFile, JSON.stringify(localConfig, null, 2) + '\n', { mode: 0o600 });
}
async function findBundle(identifier) {
  return (await api('/v1/bundleIds', { query: { 'filter[identifier]': identifier } })).data[0];
}
async function findApp() {
  return (await api('/v1/apps', { query: { 'filter[bundleId]': bundle, limit: '1' } })).data[0];
}
async function setup() {
  for (const [identifier, name] of [[bundle, 'CampusSchedule'], [bundle + '.widgets', 'CampusSchedule Widgets']]) {
    let record = await findBundle(identifier);
    if (!record) record = (await api('/v1/bundleIds', { method: 'POST', data: { type: 'bundleIds', attributes: { identifier, name, platform: 'IOS' } } })).data;
    const capabilities = (await api(`/v1/bundleIds/${record.id}/bundleIdCapabilities`)).data;
    if (!capabilities.some(item => item.attributes.capabilityType === 'APP_GROUPS')) {
      await api('/v1/bundleIdCapabilities', { method: 'POST', data: { type: 'bundleIdCapabilities', attributes: { capabilityType: 'APP_GROUPS' }, relationships: { bundleId: { data: { type: 'bundleIds', id: record.id } } } } });
    }
    console.log(`Registered ${identifier} with App Groups capability`);
  }
  saveConfig();
  console.log(`Website setup required: associate ${app.extra.nativeAppGroup} with BOTH identifiers, and create the App Store Connect app record for ${bundle}.`);
}
async function certificate() {
  mkdirSync(local, { recursive: true });
  const openssl = process.platform === 'win32' ? 'C:/Program Files/Git/usr/bin/openssl.exe' : 'openssl';
  const key = resolve(local, 'distribution.key');
  const csr = resolve(local, 'distribution.csr');
  const der = resolve(local, 'distribution.cer');
  const pem = resolve(local, 'distribution.pem');
  const p12 = resolve(local, 'distribution.p12');
  if (!metadata.certificateID) {
    if (!existsSync(key)) execFileSync(openssl, ['req', '-new', '-newkey', 'rsa:2048', '-nodes', '-subj', '/CN=CampusSchedule CI', '-keyout', key, '-out', csr], { stdio: 'ignore' });
    if (!existsSync(csr)) throw new Error('Missing CSR for existing local private key; refusing to replace signing key');
    const created = (await api('/v1/certificates', { method: 'POST', data: { type: 'certificates', attributes: { certificateType: 'DISTRIBUTION', csrContent: readFileSync(csr, 'utf8') } } })).data;
    metadata.certificateID = created.id;
    writeFileSync(der, Buffer.from(created.attributes.certificateContent, 'base64'), { mode: 0o600 });
    saveConfig();
  }
  need(existsSync(key), 'existing distribution private key');
  if (!existsSync(der)) {
    const record = (await api(`/v1/certificates/${metadata.certificateID}`)).data;
    writeFileSync(der, Buffer.from(record.attributes.certificateContent, 'base64'), { mode: 0o600 });
  }
  const cert = new X509Certificate(readFileSync(der));
  if (!cert.subject.split('\n').includes(`OU=${metadata.teamID}`)) throw new Error('Certificate Team ID does not match requested team');
  if (new Date(cert.validTo) <= new Date()) throw new Error('Distribution certificate expired; explicit renewal required');
  localConfig.p12Password ??= randomBytes(32).toString('hex');
  saveConfig();
  execFileSync(openssl, ['x509', '-inform', 'DER', '-in', der, '-out', pem], { stdio: 'ignore' });
  // Apple's security import requires the interoperable PKCS#12 PBE/MAC encoding.
  execFileSync(openssl, ['pkcs12', '-export', '-inkey', key, '-in', pem, '-out', p12, '-keypbe', 'PBE-SHA1-3DES', '-certpbe', 'PBE-SHA1-3DES', '-macalg', 'sha1', '-passout', 'env:CAMPUS_P12_PASSWORD'], { stdio: 'ignore', env: { ...process.env, CAMPUS_P12_PASSWORD: localConfig.p12Password } });
  console.log(`Distribution signing material prepared; existing certificates were not revoked. Expires ${cert.validTo}`);
}
function secrets() {
  const values = {
    APPLE_API_PRIVATE_KEY: privateKey,
    APPLE_API_KEY_ID: metadata.keyID,
    APPLE_API_ISSUER_ID: metadata.issuerID,
    APPLE_TEAM_ID: metadata.teamID,
    APPLE_CERTIFICATE_ID: need(metadata.certificateID, 'distribution certificate'),
    APPLE_DISTRIBUTION_P12: readFileSync(resolve(local, 'distribution.p12')).toString('base64'),
    APPLE_DISTRIBUTION_PASSWORD: need(localConfig.p12Password, 'p12 password'),
  };
  for (const [name, value] of Object.entries(values)) {
    execFileSync('gh', ['secret', 'set', name, '--repo', 'ithtelab/campus-schedule-native'], { input: value, stdio: ['pipe', 'ignore', 'pipe'] });
    console.log(`Stored GitHub secret ${name}`);
  }
}
async function profiles() {
  const appRecord = await findApp();
  if (!appRecord) throw new Error(`Create the App Store Connect app record for ${bundle} before uploading`);
  const output = resolve(need(process.env.CAMPUS_SIGNING_DIR, 'CAMPUS_SIGNING_DIR'));
  mkdirSync(output, { recursive: true });
  writeFileSync(resolve(output, `AuthKey_${metadata.keyID}.p8`), privateKey, { mode: 0o600 });
  const manifest = { appID: appRecord.id, teamID: metadata.teamID, appGroup: app.extra.nativeAppGroup, profiles: [] };
  for (const [identifier, target] of [[bundle, 'app'], [bundle + '.widgets', 'widget']]) {
    const record = await findBundle(identifier);
    if (!record) throw new Error(`Unregistered bundle ID ${identifier}`);
    const profile = (await api('/v1/profiles', { method: 'POST', data: {
      type: 'profiles', attributes: { name: `CampusSchedule-${target}-${process.env.GITHUB_RUN_ID ?? Date.now()}-${process.env.GITHUB_RUN_ATTEMPT ?? 1}`, profileType: 'IOS_APP_STORE' },
      relationships: { bundleId: { data: { type: 'bundleIds', id: record.id } }, certificates: { data: [{ type: 'certificates', id: need(metadata.certificateID, 'certificate ID') }] } },
    } })).data;
    writeFileSync(resolve(output, `${target}.mobileprovision`), Buffer.from(profile.attributes.profileContent, 'base64'), { mode: 0o600 });
    manifest.profiles.push({ target, identifier, uuid: profile.attributes.uuid });
    console.log(`Created App Store profile for ${identifier}`);
  }
  writeFileSync(resolve(output, 'manifest.json'), JSON.stringify(manifest, null, 2));
}
async function status() {
  const record = await findApp();
  if (!record) { console.log(`APP_RECORD_MISSING: ${bundle}`); return; }
  console.log(`App Store Connect: https://appstoreconnect.apple.com/apps/${record.id}/testflight/ios`);
  const builds = (await api('/v1/builds', { query: { 'filter[app]': record.id, sort: '-uploadedDate', limit: '5' } })).data;
  console.log(JSON.stringify(builds.map(item => ({ id: item.id, build: item.attributes.version, processing: item.attributes.processingState, uploaded: item.attributes.uploadedDate, expirationDate: item.attributes.expirationDate, expired: item.attributes.expired })), null, 2));
}
async function auditBuild(buildNumber) {
  const record = need(await findApp(), 'App Store Connect app');
  const builds = (await api('/v1/builds', { query: { 'filter[app]': record.id, 'filter[version]': need(buildNumber, 'build number'), limit: '10' } })).data;
  const build = need(builds.find(item => item.attributes.version === buildNumber), 'matching build');
  const detail = (await api(`/v1/builds/${build.id}/buildBetaDetail`)).data;
  let review;
  try { review = (await api(`/v1/builds/${build.id}/betaAppReviewSubmission`)).data; }
  catch (error) { if (error.httpStatus !== 404) throw error; }
  console.log(JSON.stringify({ id: build.id, ...build.attributes, beta: detail.attributes, review: review?.attributes ?? null }, null, 2));
}
async function diagnoseInstall(buildNumber) {
  const record = need(await findApp(), 'App Store Connect app');
  const builds = (await api('/v1/builds', { query: { 'filter[app]': record.id, 'filter[version]': need(buildNumber, 'build number'), limit: '10' } })).data;
  const build = need(builds.find(item => item.attributes.version === buildNumber), 'matching build');
  const optional = async (path, summarize) => {
    try { return { querySucceeded: true, ...summarize((await api(path)).data) }; }
    catch (error) { return { querySucceeded: false, httpStatus: error.httpStatus ?? null, error: error.message }; }
  };
  const [detail, owners, groups, license, availability, bundles] = await Promise.all([
    api(`/v1/builds/${build.id}/buildBetaDetail`),
    api('/v1/users', { query: { 'filter[roles]': 'ACCOUNT_HOLDER', limit: '2' } }),
    api(`/v1/apps/${record.id}/betaGroups`, { query: { limit: '200' } }),
    optional(`/v1/apps/${record.id}/betaLicenseAgreement`, data => ({ resourceExists: Boolean(data), agreementTextPresent: Boolean(data?.attributes.agreementText?.trim()) })),
    optional(`/v1/apps/${record.id}/appAvailabilityV2`, data => ({ resourceExists: Boolean(data), attributes: data?.attributes ?? null })),
    optional(`/v1/builds/${build.id}/buildBundles`, data => ({ bundles: data.map(item => ({ id: item.id, ...item.attributes })) })),
  ]);
  const owner = owners.data.length === 1 ? owners.data[0] : null;
  const internalGroups = await Promise.all(groups.data.filter(item => item.attributes.isInternalGroup).map(async group => {
    const [testersResult, assigned] = await Promise.all([
      api(`/v1/betaGroups/${group.id}/betaTesters`, { query: { limit: '200' } }),
      api(`/v1/betaGroups/${group.id}/builds`, { query: { limit: '200' } }),
    ]);
    const testers = testersResult.data;
    const tester = owner && testers.find(item => item.attributes.email?.toLowerCase() === owner.attributes.username.toLowerCase());
    const apps = tester ? await optional(`/v1/betaTesters/${tester.id}/apps`, data => ({ hasApp: data.some(item => item.id === record.id) })) : null;
    return { name: group.attributes.name, buildAssigned: assigned.data.some(item => item.id === build.id), ownerAssigned: Boolean(tester),
      tester: tester ? { email: maskedEmail(tester.attributes.email), state: tester.attributes.state, inviteType: tester.attributes.inviteType, apps } : null };
  }));
  const report = {
    observedAt: new Date().toISOString(), appID: record.id, bundleID: bundle, buildID: build.id,
    build: build.attributes.version, processingState: build.attributes.processingState, expired: build.attributes.expired,
    uploadedDate: build.attributes.uploadedDate, expirationDate: build.attributes.expirationDate,
    minimumOS: build.attributes.minOsVersion, usesNonExemptEncryption: build.attributes.usesNonExemptEncryption,
    beta: detail.data.attributes, owner: owner ? { roles: owner.attributes.roles, allAppsVisible: owner.attributes.allAppsVisible } : null,
    internalGroups, betaLicense: license, appAvailability: availability, buildBundles: bundles,
    limitation: 'Read-only API eligibility evidence does not prove device download availability. Agreement text presence does not establish account contract validation.',
  };
  mkdirSync(local, { recursive: true });
  writeFileSync(resolve(local, `install-diagnostic-${buildNumber}.json`), JSON.stringify(report, null, 2), { mode: 0o600 });
  console.log(JSON.stringify(report, null, 2));
}
async function resumeBuild(buildNumber) {
  const record = need(await findApp(), 'App Store Connect app');
  const builds = (await api('/v1/builds', { query: { 'filter[app]': record.id, 'filter[version]': need(buildNumber, 'build number'), limit: '10' } })).data;
  const build = need(builds.find(item => item.attributes.version === buildNumber), 'matching build');
  if (Date.now() - new Date(build.attributes.uploadedDate).getTime() >= 90 * 86400000) throw new Error('Build is beyond its normal TestFlight lifetime; do not attempt restoration');
  if (build.attributes.expired) await api(`/v1/builds/${build.id}`, { method: 'PATCH', data: { type: 'builds', id: build.id, attributes: { expired: false } } });
  await auditBuild(buildNumber);
}
async function diagnoseReview() {
  const record = need(await findApp(), 'App Store Connect app');
  const review = (await api(`/v1/apps/${record.id}/betaAppReviewDetail`)).data;
  const localizations = (await api(`/v1/apps/${record.id}/betaAppLocalizations`)).data;
  console.log(JSON.stringify({ primaryLocale: record.attributes.primaryLocale, reviewFields: Object.fromEntries(Object.entries(review.attributes).map(([key,value]) => [key, typeof value === 'boolean' ? value : Boolean(value)])), localizations: localizations.map(item => ({ locale: item.attributes.locale, descriptionLength: item.attributes.description?.length ?? 0, feedbackEmailSet: Boolean(item.attributes.feedbackEmail) })) }));
  const builds = (await api('/v1/builds', { query: { 'filter[app]': record.id, limit: '10' } })).data;
  for (const build of builds) {
    const notes = (await api(`/v1/builds/${build.id}/betaBuildLocalizations`)).data;
    console.log(JSON.stringify({ build: build.attributes.version, notes: notes.map(item => ({ locale: item.attributes.locale, length: item.attributes.whatsNew?.length ?? 0 })) }));
    try {
      const submission = (await api(`/v1/betaAppReviewSubmissions/${build.id}`)).data;
      console.log(JSON.stringify({ build: build.attributes.version, submission: submission?.attributes ?? null }));
    } catch (error) { console.log(`Build ${build.attributes.version} direct submission lookup: HTTP ${error.httpStatus ?? 'unknown'}`); }
  }
}
function maskedEmail(email) {
  const [name, domain] = email.split('@');
  return `${name.slice(0, 2)}***@${domain}`;
}
async function internalStatus() {
  const record = need(await findApp(), 'App Store Connect app');
  const owners = (await api('/v1/users', { query: { 'filter[roles]': 'ACCOUNT_HOLDER', limit: '2' } })).data;
  console.log(`Account holders: ${owners.length}`);
  if (owners.length === 1) console.log(`Owner testing account: ${maskedEmail(owners[0].attributes.username)}`);
  const groups = (await api(`/v1/apps/${record.id}/betaGroups`, { query: { limit: '200' } })).data;
  for (const group of groups.filter(item => item.attributes.isInternalGroup)) {
    const testers = (await api(`/v1/betaGroups/${group.id}/betaTesters`)).data;
    const builds = (await api(`/v1/betaGroups/${group.id}/builds`)).data;
    console.log(JSON.stringify({ group: group.attributes.name, internal: true, publicLink: group.attributes.publicLinkEnabled ?? false, testers: testers.map(item => ({ email: maskedEmail(item.attributes.email), state: item.attributes.state })), builds: builds.map(item => ({ build: item.attributes.version, processing: item.attributes.processingState })) }));
  }
}
async function uploadStatus() {
  const record = need(await findApp(), 'App Store Connect app');
  const uploads = (await api(`/v1/apps/${record.id}/buildUploads`, { query: { limit: '5' } })).data;
  console.log(JSON.stringify(uploads.map(item => ({ id: item.id, ...item.attributes })), null, 2));
}
async function enableInternal(buildNumber) {
  need(buildNumber, 'specific build number');
  const record = need(await findApp(), 'App Store Connect app');
  const builds = (await api('/v1/builds', { query: { 'filter[app]': record.id, 'filter[version]': buildNumber, limit: '10' } })).data;
  const build = builds.find(item => item.attributes.version === buildNumber && item.attributes.processingState === 'VALID' && !item.attributes.expired);
  if (!build) throw new Error(`Build ${buildNumber} has not completed Apple processing`);
  const owners = (await api('/v1/users', { query: { 'filter[roles]': 'ACCOUNT_HOLDER', limit: '2' } })).data;
  if (owners.length !== 1) throw new Error('Cannot uniquely identify the account holder; choose the testing account explicitly');
  const owner = owners[0].attributes;
  const groups = (await api(`/v1/apps/${record.id}/betaGroups`, { query: { limit: '200' } })).data;
  let group = groups.find(item => item.attributes.name === '本人真机测试' && item.attributes.isInternalGroup);
  if (!group) group = (await api('/v1/betaGroups', { method: 'POST', data: { type: 'betaGroups', attributes: { name: '本人真机测试', isInternalGroup: true }, relationships: { app: { data: { type: 'apps', id: record.id } } } } })).data;
  if (group.attributes.publicLinkEnabled) throw new Error('Refusing to use a public testing group');
  const testers = (await api(`/v1/betaGroups/${group.id}/betaTesters`, { query: { limit: '200' } })).data;
  if (!testers.some(item => item.attributes.email.toLowerCase() === owner.username.toLowerCase())) {
    const existing = (await api('/v1/betaTesters', { query: { 'filter[email]': owner.username, limit: '10' } })).data[0];
    if (existing) {
      await api(`/v1/betaGroups/${group.id}/relationships/betaTesters`, { method: 'POST', data: [{ type: 'betaTesters', id: existing.id }] });
    } else {
      await api('/v1/betaTesters', { method: 'POST', data: { type: 'betaTesters', attributes: { email: owner.username, firstName: owner.firstName, lastName: owner.lastName }, relationships: { betaGroups: { data: [{ type: 'betaGroups', id: group.id }] } } } });
    }
    console.log(`Added only the account holder to internal testing: ${maskedEmail(owner.username)}`);
  }
  const notes = (await api(`/v1/builds/${build.id}/betaBuildLocalizations`)).data;
  const note = notes.find(item => item.attributes.locale === 'zh-Hans');
  const notesFile = process.env.CAMPUS_BETA_NOTES_FILE;
  const whatsNew = notesFile ? readFileSync(resolve(root, notesFile), 'utf8').trim() : '请测试：手动添加课程、本地保存、深浅色、课表联动人物、上下课提醒、桌面与锁屏组件。学校导入未实现；灵动岛完整后台自动结束和多节自动衔接尚待完善。初次启动为空课表。';
  if (!whatsNew || whatsNew.length > 4000) throw new Error('Build testing notes must contain 1–4000 characters');
  if (!note) {
    await api('/v1/betaBuildLocalizations', { method: 'POST', data: { type: 'betaBuildLocalizations', attributes: { locale: 'zh-Hans', whatsNew }, relationships: { build: { data: { type: 'builds', id: build.id } } } } });
  } else if (!note.attributes.whatsNew?.trim() || (notesFile && note.attributes.whatsNew !== whatsNew)) {
    await api(`/v1/betaBuildLocalizations/${note.id}`, { method: 'PATCH', data: { type: 'betaBuildLocalizations', id: note.id, attributes: { whatsNew } } });
  }
  const assigned = (await api(`/v1/betaGroups/${group.id}/builds`)).data;
  if (!assigned.some(item => item.id === build.id)) await api(`/v1/betaGroups/${group.id}/relationships/builds`, { method: 'POST', data: [{ type: 'builds', id: build.id }] });
  const detail = (await api(`/v1/builds/${build.id}/buildBetaDetail`)).data;
  console.log(`Internal build state: ${detail.attributes.internalBuildState}`);
  await internalStatus();
}
async function watchInternal(buildNumber) {
  need(buildNumber, 'specific build number');
  const record = need(await findApp(), 'App Store Connect app');
  let previous;
  for (let attempt = 0; attempt < 60; attempt++) {
    const uploads = (await api(`/v1/apps/${record.id}/buildUploads`, { query: { limit: '20' } })).data;
    const upload = uploads.find(item => item.attributes.cfBundleVersion === buildNumber);
    const state = upload?.attributes.state?.state ?? 'WAITING_FOR_APPLE_RECORD';
    if (state !== previous) { console.log(`Apple build ${buildNumber}: ${state}`); previous = state; }
    if (state === 'FAILED') throw new Error(`Apple processing failed: ${JSON.stringify(upload.attributes.state.errors)}`);
    const builds = (await api('/v1/builds', { query: { 'filter[app]': record.id, 'filter[version]': buildNumber, limit: '10' } })).data;
    const build = builds.find(item => item.attributes.version === buildNumber && item.attributes.processingState === 'VALID' && !item.attributes.expired);
    if (build) {
      await enableInternal(buildNumber);
      writeFileSync(resolve(local, 'testflight-ready.json'), JSON.stringify({ appID: record.id, buildID: build.id, build: buildNumber, verifiedAt: new Date().toISOString(), status: 'INTERNAL_ACCESS_CONFIGURED', deviceInstallation: 'UNVERIFIED' }, null, 2));
      return;
    }
    await new Promise(done => setTimeout(done, 20000));
  }
  throw new Error('Apple processing still pending after this monitoring window; upload must not be repeated blindly');
}
async function externalStatus() {
  const record = need(await findApp(), 'App Store Connect app');
  const groups = (await api(`/v1/apps/${record.id}/betaGroups`, { query: { limit: '200' } })).data;
  console.log(JSON.stringify(groups.filter(item => !item.attributes.isInternalGroup).map(item => ({ id: item.id, ...item.attributes })), null, 2));
  const detail = (await api(`/v1/apps/${record.id}/betaAppReviewDetail`)).data;
  const fields = ['contactFirstName', 'contactLastName', 'contactPhone', 'contactEmail'];
  console.log(JSON.stringify({ missingReviewFields: fields.filter(key => !detail.attributes[key]), demoAccountRequired: detail.attributes.demoAccountRequired }));
  const localizations = (await api(`/v1/apps/${record.id}/betaAppLocalizations`)).data;
  console.log(JSON.stringify(localizations.map(item => ({ id: item.id, locale: item.attributes.locale, hasDescription: Boolean(item.attributes.description), hasFeedbackEmail: Boolean(item.attributes.feedbackEmail), hasPrivacyPolicy: Boolean(item.attributes.privacyPolicyUrl) }))));
  const builds = (await api('/v1/builds', { query: { 'filter[app]': record.id, limit: '10' } })).data;
  for (const build of builds) {
    const beta = (await api(`/v1/builds/${build.id}/buildBetaDetail`)).data;
    console.log(JSON.stringify({ build: build.attributes.version, audience: build.attributes.buildAudienceType, ...beta.attributes }));
  }
}
async function prepareExternal(buildNumber) {
  const record = need(await findApp(), 'App Store Connect app');
  const builds = (await api('/v1/builds', { query: { 'filter[app]': record.id, 'filter[version]': need(buildNumber, 'build number'), limit: '10' } })).data;
  const build = builds.find(item => item.attributes.version === buildNumber && item.attributes.processingState === 'VALID' && !item.attributes.expired);
  if (!build || build.attributes.buildAudienceType === 'INTERNAL_ONLY') throw new Error('This build is not eligible for external beta testing');
  const groups = (await api(`/v1/apps/${record.id}/betaGroups`, { query: { limit: '200' } })).data;
  let group = groups.find(item => item.attributes.name === '公开外部测试' && !item.attributes.isInternalGroup);
  if (!group) group = (await api('/v1/betaGroups', { method: 'POST', data: { type: 'betaGroups', attributes: { name: '公开外部测试', isInternalGroup: false, publicLinkEnabled: false }, relationships: { app: { data: { type: 'apps', id: record.id } } } } })).data;
  const assigned = (await api(`/v1/betaGroups/${group.id}/builds`)).data;
  if (!assigned.some(item => item.id === build.id)) await api(`/v1/betaGroups/${group.id}/relationships/builds`, { method: 'POST', data: [{ type: 'builds', id: build.id }] });
  console.log(`External group prepared for build ${buildNumber}; review and public-link availability still need confirmation`);
  await externalStatus();
}
async function configureExternal() {
  const settings = JSON.parse(readFileSync(resolve(local, 'external-review.json'), 'utf8'));
  if (!/^\+[0-9]{8,15}$/.test(settings.phone) || settings.feedbackEmailSource !== 'account-holder') throw new Error('Missing authorized external review contact or feedback email choice');
  const record = need(await findApp(), 'App Store Connect app');
  const owners = (await api('/v1/users', { query: { 'filter[roles]': 'ACCOUNT_HOLDER', limit: '2' } })).data;
  if (owners.length !== 1) throw new Error('Cannot uniquely identify review contact');
  const owner = owners[0].attributes;
  const review = (await api(`/v1/apps/${record.id}/betaAppReviewDetail`)).data;
  await api(`/v1/betaAppReviewDetails/${review.id}`, { method: 'PATCH', data: { type: 'betaAppReviewDetails', id: review.id, attributes: {
    contactFirstName: need(owner.firstName, 'review first name'), contactLastName: need(owner.lastName, 'review last name'), contactEmail: owner.username, contactPhone: settings.phone,
    demoAccountRequired: false,
    notes: 'Native university timetable app. No sign-in, subscription or payment is required. On first launch the timetable is empty. Tap + to add a course; configure semester dates and class periods in Settings when needed. Course data is stored on the device. Please test manual course management, local persistence, local notifications and widgets. School-system login/import is not included. Full background automatic Live Activity ending and multi-course handoff remain under development. The app does not require a demo account. Notification permission is optional and requested when enabling reminders.',
  } } });
  const localizations = (await api(`/v1/apps/${record.id}/betaAppLocalizations`)).data;
  const localized = localizations.find(item => item.attributes.locale === 'zh-Hans');
  const attributes = {
    description: '面向大学生的本地优先课表工具。支持手动添加课程、学期与作息设置、课程调停补课、上课及可选下课提醒，提供桌面和锁屏组件，以及随课表状态变化的黑白手绘校园人物。无需登录，课表保存在本机。本次为早期测试：学校教务导入尚未提供，实时活动的完整后台结束与多节衔接仍在完善。首次启动为空课表，请先手动添加课程。',
    feedbackEmail: owner.username,
  };
  if (localized) await api(`/v1/betaAppLocalizations/${localized.id}`, { method: 'PATCH', data: { type: 'betaAppLocalizations', id: localized.id, attributes } });
  else await api('/v1/betaAppLocalizations', { method: 'POST', data: { type: 'betaAppLocalizations', attributes: { locale: 'zh-Hans', ...attributes }, relationships: { app: { data: { type: 'apps', id: record.id } } } } });
  console.log('Saved authorized review contact, no-login instructions, accurate beta description and feedback email; private contact values omitted');
  await externalStatus();
}
async function submitExternal(buildNumber) {
  const record = need(await findApp(), 'App Store Connect app');
  const builds = (await api('/v1/builds', { query: { 'filter[app]': record.id, 'filter[version]': need(buildNumber, 'build number'), limit: '10' } })).data;
  const build = need(builds.find(item => item.attributes.version === buildNumber && item.attributes.processingState === 'VALID' && !item.attributes.expired), 'eligible processed build');
  if (build.attributes.buildAudienceType === 'INTERNAL_ONLY') throw new Error('Internal-only build cannot be submitted externally');
  const notes = (await api(`/v1/builds/${build.id}/betaBuildLocalizations`)).data;
  if (!notes.some(item => item.attributes.whatsNew?.trim())) throw new Error('Beta build What to Test is empty; fill it before submission');
  let submission;
  try { submission = (await api(`/v1/builds/${build.id}/betaAppReviewSubmission`)).data; }
  catch (error) { if (error.httpStatus !== 404) throw error; }
  if (!submission) submission = (await api('/v1/betaAppReviewSubmissions', { method: 'POST', data: { type: 'betaAppReviewSubmissions', relationships: { build: { data: { type: 'builds', id: build.id } } } } })).data;
  console.log(JSON.stringify({ build: buildNumber, submissionID: submission.id, reviewState: submission.attributes.betaReviewState }));
  writeFileSync(resolve(local, 'external-submission.json'), JSON.stringify({ appID: record.id, buildID: build.id, build: buildNumber, submissionID: submission.id, reviewState: submission.attributes.betaReviewState, verifiedAt: new Date().toISOString() }, null, 2));
  await externalStatus();
}
async function enableExternalLink(buildNumber) {
  const record = need(await findApp(), 'App Store Connect app');
  const groups = (await api(`/v1/apps/${record.id}/betaGroups`, { query: { limit: '200' } })).data;
  const group = need(groups.find(item => item.attributes.name === '公开外部测试' && !item.attributes.isInternalGroup), 'prepared external group');
  const builds = (await api(`/v1/betaGroups/${group.id}/builds`)).data;
  if (!builds.some(item => item.attributes.version === need(buildNumber, 'build number') && item.attributes.processingState === 'VALID' && !item.attributes.expired)) throw new Error('Specific processed build must be associated before enabling link');
  const result = (await api(`/v1/betaGroups/${group.id}`, { method: 'PATCH', data: { type: 'betaGroups', id: group.id, attributes: { publicLinkEnabled: true, publicLinkLimitEnabled: true, publicLinkLimit: 100 } } })).data;
  console.log(JSON.stringify({ group: result.attributes.name, publicLinkEnabled: result.attributes.publicLinkEnabled, publicLink: result.attributes.publicLink, limit: result.attributes.publicLinkLimit }));
  writeFileSync(resolve(local, 'external-public-link.json'), JSON.stringify({ appID: record.id, groupID: group.id, build: buildNumber, publicLink: result.attributes.publicLink, publicLinkEnabled: result.attributes.publicLinkEnabled, limit: result.attributes.publicLinkLimit, verifiedAt: new Date().toISOString() }, null, 2));
}
async function resetExternalAssignment(buildNumber) {
  const record = need(await findApp(), 'App Store Connect app');
  const groups = (await api(`/v1/apps/${record.id}/betaGroups`, { query: { limit: '200' } })).data;
  const group = need(groups.find(item => item.attributes.name === '公开外部测试' && !item.attributes.isInternalGroup), 'specific external group');
  const builds = (await api(`/v1/betaGroups/${group.id}/builds`)).data;
  const build = need(builds.find(item => item.attributes.version === need(buildNumber, 'build number') && !item.attributes.expired), 'specific active assigned build');
  const detail = (await api(`/v1/builds/${build.id}/buildBetaDetail`)).data;
  if (detail.attributes.externalBuildState !== 'READY_FOR_BETA_SUBMISSION') throw new Error('Only an unsubmitted external assignment can be reset');
  await api(`/v1/betaGroups/${group.id}/relationships/builds`, { method: 'DELETE', data: [{ type: 'builds', id: build.id }] });
  const remaining = (await api(`/v1/betaGroups/${group.id}/builds`)).data;
  if (remaining.some(item => item.id === build.id)) throw new Error('External association removal not confirmed');
  await auditBuild(buildNumber);
  console.log('Removed only the unsubmitted external group association. Re-add the same build through the Apple website Add Builds wizard to reach Submit Review.');
}
try {
  switch (process.argv[2]) {
    case 'check-key': await api('/v1/bundleIds', { query: { limit: '1' } }); console.log('Apple team API key authenticated'); break;
    case 'setup': await setup(); break;
    case 'certificate': await certificate(); break;
    case 'secrets': secrets(); break;
    case 'profiles': await profiles(); break;
    case 'status': await status(); break;
    case 'audit-build': await auditBuild(process.argv[3]); break;
    case 'diagnose-install': await diagnoseInstall(process.argv[3]); break;
    case 'resume-build': await resumeBuild(process.argv[3]); break;
    case 'diagnose-review': await diagnoseReview(); break;
    case 'internal-status': await internalStatus(); break;
    case 'upload-status': await uploadStatus(); break;
    case 'enable-internal': await enableInternal(process.argv[3]); break;
    case 'watch-internal': await watchInternal(process.argv[3]); break;
    case 'external-status': await externalStatus(); break;
    case 'prepare-external': await prepareExternal(process.argv[3]); break;
    case 'configure-external': await configureExternal(); break;
    case 'submit-external': await submitExternal(process.argv[3]); break;
    case 'external-link': await enableExternalLink(process.argv[3]); break;
    case 'reset-external-assignment': await resetExternalAssignment(process.argv[3]); break;
    default: throw new Error('Use check-key, setup, certificate, secrets, profiles, status, audit-build BUILD, diagnose-install BUILD, diagnose-review, resume-build BUILD, upload-status, internal-status, enable-internal BUILD, watch-internal BUILD, external-status, prepare-external BUILD, configure-external, submit-external BUILD or external-link BUILD');
  }
} catch (error) {
  // Do not print subprocess buffers, request headers, tokens or private key content.
  console.error(error.status !== undefined ? `Signing helper command failed (exit ${error.status})` : error.message);
  process.exitCode = 1;
}
