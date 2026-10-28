import type { E2EConfig } from 'e2e';
import { mobile } from '@e2e-dev/mobile';

// Curated Feeds — Android-only RSS reader.
//
// Prerequisites on the machine that runs this suite:
//   export ANDROID_HOME=~/Android/Sdk        # adb on PATH
//   flutter build apk --debug                # or: CURATED_FEEDS_APK=<path>
//   npx agent-device doctor
export default {
  tests: 'tests/**/*.e2e.ts',
  workers: 1,
  retries: 0,
  timeout: 120_000,
  assertionTimeout: 15_000,
  actionTimeout: 30_000,
  cache: 'off',
  reporters: ['list', 'junit', 'markdown'],
  trace: 'retain-on-failure',
  targets: [
    {
      name: 'android',
      engine: mobile({ platform: 'android', session: 'curated-feeds' }),
      app: {
        environment: 'test',
        bundleId: 'com.curatedfeeds',
        appPath: process.env.CURATED_FEEDS_APK ?? '../build/app/outputs/flutter-apk/app-debug.apk',
        // No OS prompt mid-test: notification flows are driven from Settings,
        // where the toggle is a UI control, not a system dialog.
        permissions: { notifications: 'grant' },
      },
    },
    {
      // The worker's HTTP contract, checked with fetch: no device, no browser,
      // so it runs wherever Node does — including this machine. Start the
      // local worker first (`node workers/dev-server.mjs`, which
      // tool/api-contract.sh also runs) or point CURATED_FEEDS_WORKER_URL at
      // a deployed worker. See docs/testing/mobile-e2e.md.
      name: 'worker-api',
      platform: 'api',
    },
  ],
} satisfies E2EConfig;
