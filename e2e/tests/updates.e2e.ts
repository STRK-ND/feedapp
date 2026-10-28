// Update checking. The feed's overflow menu exposes "Check for updates" on
// non-Play builds only (lib/screens/feed_screen.dart returns early when
// AppConfig.isPlayStoreBuild, since the store then handles updates). Build
// the suite APK with `flutter build apk --debug` — no --flavor play.
//
// This flow needs the GitHub Releases API, so it runs with the `network` tag:
//   npx e2e run --tag network
import { describe, expect } from 'e2e';
import type { Screen } from 'e2e';
import { firstRunTest, t } from './support/app';

const finishOnboarding = async (screen: Screen) => {
  for (const _ of [0, 1]) await screen.getByRole('button', t.onboarding.continueWithoutCta).tap();
};

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('checking for updates reports the installed version is current', { tags: ['network'] }, async ({ screen }) => {
  await finishOnboarding(screen);
  await screen.getByRole('button', t.feed.moreOptions).tap();
  await screen.getByText(t.feed.checkForUpdates).tap();
  await expect(screen.getByText(t.feed.upToDate)).toBeVisible();
});
});
