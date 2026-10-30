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
  const body = await result.json();
  if (!result.ok) throw new Error(`Apple ${result.status}: ${(body.errors ?? []).map(item => `${item.code}: ${item.detail ?? item.title}`).join('; ')}`);
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
  execFileSync(openssl, ['pkcs12', '-export', '-inkey', key, '-in', pem, '-out', p12, '-passout', 'env:CAMPUS_P12_PASSWORD'], { stdio: 'ignore', env: { ...process.env, CAMPUS_P12_PASSWORD: localConfig.p12Password } });
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
  console.log(JSON.stringify(builds.map(item => ({ id: item.id, build: item.attributes.version, processing: item.attributes.processingState, uploaded: item.attributes.uploadedDate })), null, 2));
}
try {
  switch (process.argv[2]) {
    case 'check-key': await api('/v1/bundleIds', { query: { limit: '1' } }); console.log('Apple team API key authenticated'); break;
    case 'setup': await setup(); break;
    case 'certificate': await certificate(); break;
    case 'secrets': secrets(); break;
    case 'profiles': await profiles(); break;
    case 'status': await status(); break;
    default: throw new Error('Use check-key, setup, certificate, secrets, profiles or status');
  }
} catch (error) {
  // Do not print subprocess buffers, request headers, tokens or private key content.
  console.error(error.status !== undefined ? `Signing helper command failed (exit ${error.status})` : error.message);
  process.exitCode = 1;
}
