import { spawnSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const action = process.argv[2];
let args;
if (action === 'start') {
  const buildID = process.argv[3];
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(buildID ?? '')) {
    console.error('请提供已成功的 iOS 模拟器构建 ID：npm run preview:start -- <BUILD_ID>');
    process.exit(1);
  }
  args = ['simulator:start', '--platform', 'ios', '--type', 'web-preview-only',
    '--name', 'CampusSchedule-UI-preview', '--build-id', buildID,
    '--max-duration-minutes', '15', '--max-idle-time-minutes', '5', '--no-force'];
} else if (action === 'stop') {
  args = ['simulator:stop'];
} else {
  throw new Error('Unsupported action');
}

// 所有参数为常量或经 UUID 验证的构建 ID，不拼接任意用户命令。
const result = spawnSync(process.platform === 'win32' ? 'npx.cmd' : 'npx',
  ['--yes', 'eas-cli@27.2.0', ...args], {
    cwd: root,
    stdio: 'inherit',
    shell: process.platform === 'win32',
  });
if (result.error) console.error(result.error.message);
process.exit(result.status ?? 1);
