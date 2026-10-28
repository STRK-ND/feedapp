// First run: splash, the three onboarding rooms, reading tuning, and the
// bottom navigation that follows. Locators come from lib/screens/*.dart and
// the strings in lib/l10n/app_en.arb.
import { describe, expect } from 'e2e';
import { firstRunTest, t } from './support/app';

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('splash announces the reading room and hands over to onboarding', async ({ screen }) => {
  await expect(screen.getByText(t.splashTagline)).toBeVisible();
  await expect(screen.getByText(t.onboarding.step1Eyebrow)).toBeVisible();
});

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('onboarding step one offers the three rooms with their descriptions', async ({ screen }) => {
  await expect(screen.getByText(t.onboarding.step1Eyebrow)).toBeVisible();
  await expect(screen.getByText('Three rooms.', { exact: false })).toBeVisible();
  await expect(screen.getByText(t.onboarding.paper)).toBeVisible();
  await expect(screen.getByText(t.onboarding.paperDesc)).toBeVisible();
  await expect(screen.getByText(t.onboarding.lamplight)).toBeVisible();
  await expect(screen.getByText(t.onboarding.lamplightDesc)).toBeVisible();
  await expect(screen.getByText(t.onboarding.followPhone)).toBeVisible();
  await expect(screen.getByText(t.onboarding.followPhoneDesc)).toBeVisible();
});

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('onboarding advances to reading tuning with its controls', async ({ screen }) => {
  await expect(screen.getByText(t.onboarding.step2Eyebrow)).toBeHidden();
  await screen.getByRole('button', t.onboarding.continueWithoutCta).tap();
  await expect(screen.getByText(t.onboarding.step2Eyebrow)).toBeVisible();
  await expect(screen.getByText(t.onboarding.fontSizeLabel)).toBeVisible();
  await expect(screen.getByText(t.onboarding.lineHeightLabel)).toBeVisible();
  await expect(screen.getByRole('switch', t.onboarding.typewriterDatelines)).toBeVisible();
});

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('onboarding finishes at source picking and lands on the feed', async ({ screen }) => {
  await screen.getByRole('button', t.onboarding.continueWithoutCta).tap();
  await screen.getByRole('button', t.onboarding.continueWithoutCta).tap();
  await expect(screen.getByText(t.onboarding.step3Eyebrow)).toBeVisible();
  await expect(screen.getByText('Start with one', { exact: false })).toBeVisible();
  await expect(screen.getByText(t.onboarding.continueWithoutCta)).toBeVisible();
  await screen.getByRole('button', t.onboarding.continueWithoutCta).tap();
  await expect(screen.getByRole('button', /^Feed tab/)).toBeVisible();
});

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('the bottom navigation exposes Feed, Saved and Settings tabs', async ({ screen }) => {
  await screen.getByRole('button', t.onboarding.continueWithoutCta).tap();
  await screen.getByRole('button', t.onboarding.continueWithoutCta).tap();
  await screen.getByRole('button', t.onboarding.continueWithoutCta).tap();
  await expect(screen.getByRole('button', /^Feed tab/)).toBeVisible();
  await screen.getByRole('button', /^Saved tab/).tap();
  await expect(screen.getByRole('button', /^Saved tab/)).toBeVisible();
  await screen.getByRole('button', /^Settings tab/).tap();
  await expect(screen.getByText(t.settings.title)).toBeVisible();
});
});

});

});

});

});
