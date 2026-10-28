// Paywall and Pro support: how the purchase sheet reports store problems,
// and the Support section that opens it. Locators from
// lib/screens/paywall_screen.dart and lib/l10n/app_en.arb.
import { describe, expect } from 'e2e';
import type { Screen } from 'e2e';
import { firstRunTest, t } from './support/app';

const openSettings = async (screen: Screen) => {
  for (const _ of [0, 1]) await screen.getByRole('button', t.onboarding.continueWithoutCta).tap();
  await screen.getByRole('button', /^Settings tab/).tap();
  await expect(screen.getByText(t.settings.title)).toBeVisible();
};

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('the support section opens the Pro paywall with its offer rows', async ({ screen }) => {
  await openSettings(screen);
  await screen.getByText(t.settings.supportApp).tap();
  await expect(screen.getByText(t.paywall.heading)).toBeVisible();
  await expect(screen.getByText(t.paywall.oneTime, { exact: false })).toBeVisible();
  // On an emulator with no Play Store account the purchase row reports a
  // store problem instead of a price; either is a valid paywall render.
  await expect(screen.getByText(t.paywall.storeUnavailable)).toBeHidden();
  await expect(screen.getByText(t.paywall.productMissing)).toBeHidden();
  await expect(screen.getByText(t.paywall.retry)).toBeHidden();
});
});
