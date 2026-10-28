// Sources: the subscribed/discover split, adding a custom feed URL, the
// unsubscribe confirmation, and OPML import/export. Locators come from
// lib/screens/sources_screen.dart and lib/l10n/app_en.arb.
import { describe, expect } from 'e2e';
import type { Screen } from 'e2e';
import { firstRunTest, t } from './support/app';

const openSources = async (screen: Screen) => {
  for (const _ of [0, 1]) await screen.getByRole('button', t.onboarding.continueWithoutCta).tap();
  await screen.getByRole('button', /^Settings tab/).tap();
  await screen.getByText(t.settings.manageSources).tap();
  await expect(screen.getByText(t.sources.title)).toBeVisible();
};

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('the sources screen splits subscribed from discover', async ({ screen }) => {
  await openSources(screen);
  await expect(screen.getByText(t.sources.subscribedLabel)).toBeVisible();
  await expect(screen.getByText(t.sources.discoverLabel)).toBeVisible();
  await expect(screen.getByText(t.sources.emptyHint, { exact: false })).toBeVisible();
});

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('adding a custom feed validates the URL before accepting it', async ({ screen }) => {
  await openSources(screen);
  await screen.getByRole('button', t.sources.addCustomSemantic).tap();
  await expect(screen.getByText(t.sources.addSheetTitle)).toBeVisible();
  await expect(screen.getByPlaceholder(t.sources.feedUrlHint)).toBeVisible();
  await screen.getByPlaceholder(t.sources.feedUrlHint).fill('not-a-url');
  await screen.getByRole('button', t.sources.addSourceCta).tap();
  await expect(screen.getByText(t.sources.invalidUrlError)).toBeVisible();
});

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('OPML export reports that nothing is subscribed yet', async ({ screen }) => {
  await openSources(screen);
  await screen.getByRole('button', t.sources.exportOpmlSemantic).tap();
  await expect(screen.getByText(t.sources.opmlNothingToExport)).toBeVisible();
});
});

});

});
