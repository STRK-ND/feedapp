// Settings: every section, its toggles, the clear-cache confirmation and the
// about/support rows. Locators come from lib/screens/settings_screen.dart and
// lib/l10n/app_en.arb.
import { describe, expect } from 'e2e';
import type { Screen } from 'e2e';
import { firstRunTest, t } from './support/app';

const openSettings = async (screen: Screen) => {
  for (const _ of [0, 1]) await screen.getByRole('button', t.onboarding.continueWithoutCta).tap();
  await screen.getByRole('button', /^Settings tab/).tap();
  await expect(screen.getByText(t.settings.title)).toBeVisible();
};

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('settings lists all nine sections', async ({ screen }) => {
  await openSettings(screen);
  for (const section of [t.settings.sectionAppearance, t.settings.sectionNotifications, t.settings.sectionFeedSettings,
    t.settings.sectionSources, t.settings.sectionReading, t.settings.sectionEdition, t.settings.sectionStorage,
    t.settings.sectionAbout, t.settings.sectionSupport, t.settings.sectionAccount]) {
    await expect(screen.getByText(section)).toBeVisible();
  }
});

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('appearance toggles show images and data saver', async ({ screen }) => {
  await openSettings(screen);
  await expect(screen.getByRole('switch', t.settings.showImages)).toBeVisible();
  await expect(screen.getByText(t.settings.showImagesSubtitle, { exact: false })).toBeVisible();
  await screen.getByRole('switch', t.settings.showImages).tap();
  await expect(screen.getByRole('switch', t.settings.showImages)).toBeVisible();
  await expect(screen.getByRole('switch', t.settings.dataSaver)).toBeVisible();
});

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('notification settings expose push, new-article and in-app switches', async ({ screen }) => {
  await openSettings(screen);
  await expect(screen.getByRole('switch', t.settings.pushNotifications)).toBeVisible();
  await expect(screen.getByRole('switch', t.settings.newArticles)).toBeVisible();
  await expect(screen.getByRole('switch', t.settings.inAppNotifs)).toBeVisible();
});

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('feed settings expose auto refresh and refresh interval', async ({ screen }) => {
  await openSettings(screen);
  await expect(screen.getByRole('switch', t.settings.autoRefresh)).toBeVisible();
  await expect(screen.getByText(t.settings.refreshInterval)).toBeVisible();
});

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('reading preferences reach the reader\'s typography rows', async ({ screen }) => {
  await openSettings(screen);
  await screen.getByText(t.settings.readerPrefs).tap();
  await expect(screen.getByText(t.settings.bodyFont)).toBeVisible();
  await expect(screen.getByText(t.settings.lineHeight)).toBeVisible();
  await expect(screen.getByText(t.settings.fontSize)).toBeVisible();
  await expect(screen.getByText(t.settings.maxArticles)).toBeVisible();
});

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('clear cache confirms before wiping cached articles', async ({ screen }) => {
  await openSettings(screen);
  await screen.getByText(t.settings.clearCache).tap();
  await expect(screen.getByText(t.settings.clearCacheDialog)).toBeVisible();
  await screen.getByRole('button', t.settings.dialogCancel).tap();
  await expect(screen.getByText(t.settings.clearCacheDialog)).toBeHidden();
});

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('about shows the version and the licenses row', async ({ screen }) => {
  await openSettings(screen);
  await expect(screen.getByText(t.settings.appVersion)).toBeVisible();
  await expect(screen.getByText(t.settings.openSourceLicenses)).toBeVisible();
  await expect(screen.getByText(t.settings.reportBug)).toBeVisible();
});

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('the account section invites signing in while signed out', async ({ screen }) => {
  await openSettings(screen);
  await expect(screen.getByText(t.settings.sectionAccount)).toBeVisible();
  await expect(screen.getByText(t.account.signedOutSubtitle, { exact: false })).toBeVisible();
  await expect(screen.getByText(t.account.loginTitle)).toBeVisible();
});
});

});

});

});

});

});

});

});
