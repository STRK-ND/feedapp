// The feed: its app-bar actions, empty state, search and saved tab.
// Locators come from lib/screens/feed_screen.dart, where each action wraps its
// icon in Semantics(button: true, label: <localized string>).
import { describe, expect } from 'e2e';
import type { Screen } from 'e2e';
import { firstRunTest, t } from './support/app';

const finishOnboarding = async (screen: Screen) => {
  for (const _ of [0, 1]) await screen.getByRole('button', t.onboarding.continueWithoutCta).tap();
};

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('the feed app bar exposes search, refresh and more options', async ({ screen }) => {
  await finishOnboarding(screen);
  await expect(screen.getByRole('button', t.feed.refreshFeeds)).toBeVisible();
  await expect(screen.getByRole('button', t.feed.searchArticles)).toBeVisible();
  await expect(screen.getByRole('button', t.feed.moreOptions)).toBeVisible();
});

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('an empty feed explains how to fill it', async ({ screen }) => {
  await finishOnboarding(screen);
  await expect(screen.getByText(t.feed.emptyTitle)).toBeVisible();
  await expect(screen.getByText(t.feed.emptyHint, { exact: false })).toBeVisible();
});

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('searching filters articles and reports the result count', async ({ screen }) => {
  await finishOnboarding(screen);
  await screen.getByRole('button', t.feed.searchArticles).tap();
  const field = screen.getByPlaceholder(t.feed.searchHint);
  await expect(field).toBeVisible();
  await field.fill('zzzz-no-match');
  await expect(screen.getByText(t.feed.searchNoResults)).toBeVisible();
  await screen.getByRole('button', t.feed.closeSearch).tap();
  await expect(screen.getByText(t.feed.emptyTitle)).toBeVisible();
});

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('the saved tab starts empty and says how to fill it', async ({ screen }) => {
  await finishOnboarding(screen);
  await screen.getByRole('button', /^Saved tab/).tap();
  await expect(screen.getByText(t.feed.savedEmptyTitle)).toBeVisible();
  await expect(screen.getByText(t.feed.savedEmptyHint, { exact: false })).toBeVisible();
});

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('the more-options menu offers the update check', async ({ screen }) => {
  await finishOnboarding(screen);
  await screen.getByRole('button', t.feed.moreOptions).tap();
  await expect(screen.getByText(t.feed.checkForUpdates)).toBeVisible();
});
});

});

});

});

});
