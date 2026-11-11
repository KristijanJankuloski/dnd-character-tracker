# Publishing to Google Play

Step-by-step setup for publishing JJs Character Tracker (`dev.kristijanj.charactertracker`) to Google Play, ending with automatic uploads from the `Release` workflow on every push to `master`.

Legend: 👤 = only the account owner can do this (Play Console / Google account / GitHub secrets). 🤖 = already done in the repo.

> Play Console UI labels and policies change. Rules below were checked in Nov 2026; confirm against [Play Console Help](https://support.google.com/googleplay/android-developer) if something looks different.

## 0. Current state of the repo 🤖

- `applicationId` / `namespace`: `dev.kristijanj.charactertracker` (`android/app/build.gradle.kts`). **This is permanent once uploaded to Play.**
- Release signing reads `android/key.properties`, which CI writes from the `ANDROID_KEYSTORE_*` secrets.
- `release.yml` builds the APK + GitHub release, and (when secrets exist) builds an AAB and uploads it to Play.
- `versionCode` = `pubspec build number + number of existing v* tags`, always increasing. `versionName` = auto-bumped `X.Y.Z`.
- Permissions: INTERNET, CAMERA (QR scanning), multicast (LAN device sync). Audio and storage permissions are removed.

## 1. Create the app in Play Console 👤

1. Play Console → **Create app**.
2. Name: `JJs Character Tracker` (max 30 chars). Default language, **App** (not game), **Free** (can't switch free to paid later).
3. Accept the declarations (Developer Program Policies, US export laws).
4. Complete identity verification and the developer profile if the console still asks (personal accounts need ID verification and a verified phone and email; the contact address is shown publicly).

## 2. Upload keystore and Play App Signing 👤

Play re-signs your app with a key Google holds (Play App Signing, mandatory for AABs). You only sign with an **upload key**.

If you already created a keystore for the existing `ANDROID_KEYSTORE_BASE64` secret, reuse it as the upload key. Otherwise:

```bash
keytool -genkeypair -v -keystore upload-keystore.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
base64 -w0 upload-keystore.jks   # macOS: base64 -i upload-keystore.jks
```

Back the `.jks` and passwords up somewhere safe (password manager). Losing the upload key is recoverable through Play support, but painful. Never commit it.

GitHub repo → Settings → Secrets and variables → Actions → **Secrets**:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | base64 output above |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | `upload` (or your alias) |
| `ANDROID_KEY_PASSWORD` | key password (may equal keystore password) |

Heads up: once users install via Play, the Play-signed build and the GitHub APK have different signatures, so the APK cannot update over a Play install (and vice versa). Pick one channel per device.

## 3. Build an AAB locally (optional) 👤

The first upload must be manual. Either download the AAB from CI later, or build locally:

```bash
# put key.properties in android/ pointing at your keystore (see release.yml for the format)
flutter build appbundle --release --build-name=1.2.0 --build-number=100
# output: build/app/outputs/bundle/release/app-release.aab
```

Pick a small build number for the manual upload (e.g. `1`). CI's number is `pubspec build + tag count` (already above 1), so later CI uploads are always higher.

## 4. First manual upload 👤 (required before the API works)

The Play API can only manage an app after at least one release exists on a track via the console.

1. Play Console → your app → **Testing → Internal testing → Create new release**.
2. Accept Play App Signing, upload the AAB, add release notes, **Save → Review → Start rollout**.
   - If the console refuses because the store listing or declarations are incomplete, finish steps 5–7 first, then retry.
3. Add yourself under the **Testers** tab (email list) and install via the opt-in link to confirm it works.

## 5. Store listing 👤

Main store listing → fill in:

- **Short description** (80 chars) and **Full description** (4000 chars).
- **App icon**: 512×512 PNG, 32-bit, ≤1 MB. Use the icon from `app-icon/` (project files) / `assets/icon/`; export at 512×512.
- **Feature graphic**: 1024×500 PNG/JPG (required).
- **Phone screenshots**: 2–8, PNG/JPG, 16:9 or 9:16, each side 320–3840 px. Take them from the running app (e.g. character sheet, dice/roll screen, sync QR screen).
- Tablet screenshots are optional but recommended.
- **Category**: Tools or Entertainment; **Contact email** (public), optional website.

## 6. Privacy policy 👤

Required because the app uses the CAMERA permission. Host a public HTTPS page (GitHub Pages works: e.g. `docs/privacy.md` served from the repo) and paste the URL in **App content → Privacy policy**.

Suggested content: the app stores characters locally on the device; no accounts, no analytics, no servers; the camera is used only to scan sync QR codes and images are not stored or sent; LAN sync sends character data directly between the user's own devices on the local network; contact email.

## 7. App content declarations 👤

Play Console → **Policy and programs → App content**:

- **Data safety**: if the app collects nothing off-device, answer "No" to collecting/sharing data. Data sent only between the user's own devices on the local network and kept on-device is not "collected". Declare nothing for camera since frames are processed on-device only. Double-check against `pubspec.yaml` if dependencies change (e.g. adding Sentry or analytics changes the answers).
- **Content rating**: run the IARC questionnaire (email, category such as Utility/Reference). Fantasy tabletop RPG tool with no violent media should come out low.
- **Target audience**: choose 13+ or 18+ (avoid under-13 to dodge the Families policy).
- **Ads**: No ads.
- **App access**: all functionality available without login.
- **Government app / Financial features / Health**: No.
- **News app**: No. **Advertising ID**: No (unless a dependency uses it; verify the merged manifest).

## 8. Personal-account testing requirement 👤

Personal accounts created after Nov 2023 must run a **closed test with at least 12 testers opted in continuously for 14 days** before applying for production access. ([Google's rule](https://support.google.com/googleplay/android-developer/answer/14151465))

1. **Testing → Closed testing → Create track** (the default `alpha` track works).
2. Upload a release to it, add a tester list (Google Group or email list, 12+ people with Google accounts, ideally 15–20 so drop-outs don't reset the clock).
3. Share the opt-in link; testers must **join and stay opted in** for 14 days. Testers on Android should actually install it.
4. After 14 days: **Dashboard → Apply for production** and answer the questionnaire (how testing went, feedback).
5. Review typically takes up to a few days; then **Production → Create release** (promote the tested build) → roll out.

Tip: set repo variable `PLAY_TRACK=alpha` so CI feeds the closed test track while testing, then switch to `production` after approval.

## 9. Service account for CI 👤

1. Play Console → **Setup → API access** (if hidden, in newer UI: **Users and permissions → Invite new users** after step 2 below).
2. Google Cloud Console (link from API access, or any project) → **IAM & Admin → Service Accounts → Create** named e.g. `play-publisher`. No GCP roles needed. Make sure the **Google Play Android Developer API** is enabled in that project.
3. Service account → **Keys → Add key → JSON** → download.
4. Play Console → **Users and permissions → Invite new users** → paste the service account email → give app permissions for this app: **Release to production, exclude devices, and use Play App Signing** and **Release apps to testing tracks** (plus "Manage store presence" only if you later want listing updates).
5. GitHub → Secrets → **`PLAY_SERVICE_ACCOUNT_JSON`** = the full JSON contents.

Permissions can take up to ~24h to propagate; a `403`/`The caller does not have permission` shortly after is usually that.

## 10. How CI publishes (already wired) 🤖

On every push to `master`, `.github/workflows/release.yml`:

1. Computes `X.Y.Z` and `versionCode` (as above).
2. Builds the signed APK → GitHub release (unchanged).
3. If `PLAY_SERVICE_ACCOUNT_JSON` **and** `ANDROID_KEYSTORE_BASE64` exist: builds the signed AAB and uploads it with `r0adkll/upload-google-play` to the `internal` track. If the secrets are missing, the Play steps are skipped and the workflow behaves as before.

Optional repo **Variables** (Settings → Secrets and variables → Actions → Variables):

| Variable | Default | Use |
| --- | --- | --- |
| `PLAY_TRACK` | `internal` | `alpha` (closed testing), `beta`, `production` |
| `PLAY_RELEASE_STATUS` | `completed` | `draft` while the app has never been rolled out, or if you want to review in the console before releasing |

Notes: Play rejects a `versionCode` it has already seen. The job order (GitHub release first, Play second) means a failed Play upload leaves the release and the next push gets a new, higher code. Uploads to `production` are reviewed by Google before going live.

## Checklist

1. 👤 Create app (§1)
2. 👤 Keystore + 4 GitHub secrets (§2)
3. 👤 Listing, privacy policy, data safety, rating, audience (§5–7)
4. 👤 First manual internal release (§3–4)
5. 👤 Service account + `PLAY_SERVICE_ACCOUNT_JSON` secret (§9)
6. 🤖 Push to `master` → AAB lands on internal track
7. 👤 Closed test with 12+ testers for 14 days, apply for production (§8)
8. 👤 Set `PLAY_TRACK=production` when approved
