// Account: the sign-in screen, its client-side validation, the register toggle
// and the reset-password form. Locators from lib/screens/login_screen.dart and
// lib/l10n/app_en.arb.
import { describe, expect } from 'e2e';
import type { Screen } from 'e2e';
import { firstRunTest, t } from './support/app';

const openSignIn = async (screen: Screen) => {
  for (const _ of [0, 1]) await screen.getByRole('button', t.onboarding.continueWithoutCta).tap();
  await screen.getByRole('button', /^Settings tab/).tap();
  await screen.getByText(t.account.loginTitle).tap();
  await expect(screen.getByText(t.account.loginSubtitle, { exact: false })).toBeVisible();
};

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('sign-in offers Google, email and the register toggle', async ({ screen }) => {
  await openSignIn(screen);
  await expect(screen.getByRole('button', t.account.loginGoogle)).toBeVisible();
  await expect(screen.getByRole('button', t.account.loginEmailCta)).toBeVisible();
  await screen.getByText(t.account.loginToggleToRegister).tap();
  await expect(screen.getByRole('button', t.account.loginRegisterCta)).toBeVisible();
  await screen.getByText(t.account.loginToggleToSignIn).tap();
  await expect(screen.getByRole('button', t.account.loginEmailCta)).toBeVisible();
});

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('email sign-in rejects a malformed address before calling the backend', async ({ screen }) => {
  await openSignIn(screen);
  await screen.getByPlaceholder(t.account.email).fill('not-an-email');
  await screen.getByPlaceholder(t.account.password).fill('short');
  await screen.getByRole('button', t.account.loginEmailCta).tap();
  await expect(screen.getByText(t.account.authInvalidEmail)).toBeVisible();
});

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('email registration rejects a weak password', async ({ screen }) => {
  await openSignIn(screen);
  await screen.getByText(t.account.loginToggleToRegister).tap();
  await screen.getByPlaceholder(t.account.email).fill('reader@example.com');
  await screen.getByPlaceholder(t.account.password).fill('123');
  await screen.getByRole('button', t.account.loginRegisterCta).tap();
  await expect(screen.getByText(t.account.authWeakPassword)).toBeVisible();
});

describe('android suite', { platforms: ['android'] }, () => {
firstRunTest('the reset-password form sends a link', async ({ screen }) => {
  await openSignIn(screen);
  await screen.getByText(t.account.forgotPassword).tap();
  await expect(screen.getByText(t.account.resetPassword)).toBeVisible();
  await screen.getByPlaceholder(t.account.email).fill('reader@example.com');
  await screen.getByRole('button', t.account.resetPasswordCta).tap();
  await expect(screen.getByText(t.account.resetPasswordSent)).toBeVisible();
});
});

});

});

});
