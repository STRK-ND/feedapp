# Firebase Setup (Accounts + Cloud Sync)

The app uses Firebase for **user accounts and per-user data sync only**.
Feeds still come from the Cloudflare Worker (see `workers/`); the canonical
source list is served by `GET /sources` on the worker, not Firebase.

## Current project state (`curatedfeeds`)

| Item | State |
| --- | --- |
| Project | `curatedfeeds` (number 482183083527) |
| Android app | `1:482183083527:android:b86b40e0780db91122dca2`, package `com.curatedfeeds` |
| SHA-1 fingerprints | debug + release registered (Firebase Management API) |
| `android/app/google-services.json` | server-current, includes `oauth_client` entries for both SHA-1s + the web client (`default_web_client_id` is generated from this at build time — required by `google_sign_in` on Android) |
| Firestore | `(default)` database created in `asia-south1` (standard edition) |
| Security rules | `firestore.rules` deployed (`firebase deploy --only firestore:rules`) |
| Auth providers | **Enabled** — Auth initialized (`subtype: FIREBASE_AUTH`), Google + Email/Password on via the Identity Toolkit API |

## Provider configuration reference

All of the above was configured via CLI/REST; only the one-time Authentication
initialization had to be clicked in the console (Google's public API gates
`initializeAuth` behind billing; the console uses a non-billing internal path).
For reference, the provider calls used (any admin credential):

```powershell
# Email/Password
PATCH https://identitytoolkit.googleapis.com/v2/projects/curatedfeeds/config?updateMask=signIn.email.enabled,signIn.email.passwordRequired
body: {"signIn":{"email":{"enabled":true,"passwordRequired":true}}}

# Google
PATCH https://identitytoolkit.googleapis.com/v2/projects/curatedfeeds/defaultSupportedIdpConfigs/google.com?updateMask=enabled
body: {"enabled":true}

# Refresh config file
GET https://firebase.googleapis.com/v1beta1/projects/curatedfeeds/androidApps/1:482183083527:android:b86b40e0780db91122dca2/config
# -> base64 in configFileContents, decode and save as android/app/google-services.json
```

## What syncs

| Data | Firestore location | Strategy |
| --- | --- | --- |
| Profile, Pro flag | `users/{uid}` | merged on sign-in |
| Articles (saved/read state) | `users/{uid}/articles/{id}` | per-row last-writer-wins |
| Deletion tombstones | `users/{uid}/sync_state/main` | 90-day retention |
| Settings | `users/{uid}/settings/main` | whole-doc LWW |
| Subscriptions + custom sources | `users/{uid}/sources/main` | whole-doc LWW |

The app is local-first: SQLite + SharedPreferences remain the offline
source of truth, and Firestore mirrors them whenever the user is signed in.
Signed-out users never touch Firestore.

## Verify

1. `flutter run` (debug build so the debug SHA-1 matches).
2. Settings → Account → **Sign in** → try Google and email.
3. Save an article, change a setting — sign out, sign in on a second
   device/emulator with the same account and confirm the data arrives.
4. Pro purchases: buy on one device, reinstall, sign in — the Pro flag
   follows the account.

## Cost notes

Firestore offline persistence queues pushes while offline, so writes are
batched on reconnect. Per-user documents mean free-tier (Spark) capacity
covers a small user base comfortably; monitor usage in the console.
