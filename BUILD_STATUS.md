# NOVA 0.2 — language, appearance, branding and account iteration

Current iteration: 2026-10-21 (Africa/Cairo). This section takes precedence over the historical reports below.

- Locale selector now displays the active language, with Arabic/English menu choices and compact عربي/EN on phones. A single shared control is used in authentication, onboarding, main navigation, chat, settings, password change and moderation. Arabic RTL and English LTR come from MaterialApp localization; directional navigation and chat alignment follow it.
- Central device preferences persist locale and ThemeMode using shared_preferences. Default appearance follows System; the sun/moon button selects an explicit opposite appearance, and its menu restores System. ThemeData/ColorScheme supplies surfaces and paired foregrounds, including chat bubbles. Auth notices translate on locale changes; empty states scroll with enlarged text.
- Original vector NOVA N/connection/spark branding is implemented in lib/shared/brand.dart. Exported SVG light/dark/monochrome wordmarks and symbols are in assets/brand. Reproduction: flutter test tool/generate_brand.dart. Android legacy/adaptive/themed icons, iOS icon sizes, native launch images, web favicon/manifest icons and HTML startup branding are generated locally from that geometry.
- Two requested development accounts were really created using public Supabase Auth signup, with immediate sessions under the existing autoconfirm setting. The specified shared password stays outside tracked code, builds and documentation. Distinct persisted profiles, discovery, reciprocal match, persistent messages, logout/login, private data isolation and ordinary-user role checks passed. Both accounts are retained for owner testing, with the block test reversed so the chat remains usable.
- The initial token-restoration Realtime probe timed out. A separate fresh-login verification then passed persistent live message delivery in BOTH directions. Further verification isolated the actual race: SUBSCRIBED precedes PostgreSQL replication readiness. Tests now wait for its system readiness event; the application re-fetches on readiness/reconnect/resume and rejects stale concurrent history responses. Both directions then passed. No security policy was disabled.
- At the owner's explicit subsequent request, their permanent account was created through normal Supabase Auth signup using their supplied identity and birth date. A random password was generated in memory and delivered only in ignored .local/owner-access.json, protected by the local Windows account ACL. No owner password or personal record is committed. The profile is hidden and onboarding preferences are left for the owner to choose.
- Authorized database bootstrap assigned administrator only to the reviewed Auth UUID and wrote an audit event. Owner login, administrator role, real moderation queue access and denial of client role writes passed. Both development users retain zero staff roles. supabase/bootstrap_admin.sql is an operator-only, serialized bootstrap script, not a client endpoint. A password-change screen reauthenticates with the current password before updating Auth.
- Bundled unmodified Noto Sans Arabic with its OFL license so Arabic renders without an external font request.
- Local validation: formatting, analysis (no issues) and 26 Flutter tests passed. Release web and Android builds plus latest deployment/browser evidence are recorded when finished below. No signed iOS application was built on Windows; a macOS unsigned validation workflow was added. Android release currently uses the existing development signing identity and is for testing, not Play Store submission.
- No reset, recreated project, history rewrite, privileged client key, fake authentication or production test credentials. Commercial payments, media uploads, push notifications, complete administration and store release setup remain outside this iteration.

---

# NOVA continuation status — 2026-10-21 (Africa/Cairo)

## Current work: existing Supabase project + GitHub preview

- Existing project: `zywftgogopjdqjdceqzd`; public client configuration saved in ignored `config/local.json`. No second project created.
- **VERIFIED**: actual Auth endpoint responds, email/password is enabled, signup enabled, and email autoconfirm already enabled. No remote Auth settings, CAPTCHA or rate protections were changed. Paid SMTP is unnecessary for immediate development signup under these existing settings.
- **APPLIED AND VERIFIED**: privileged preflight found zero application objects/functions/policies/triggers, zero buckets, zero Auth accounts and no migration history. After a successful dry run, all four migrations were applied to the existing NOVA project. Remote history matches local versions 202610210001–202610210004. Read-only verification confirms schema version 4, no missing/unprotected application tables, server-only billing/credit RPCs, private media bucket and message Realtime publication. No reset or deletion of preexisting user data occurred.
- Four migrations are prepared. New `202610210004_client_readiness.sql` exposes only a public schema-version integer. Startup checks it before showing registration, preventing accounts without the required application schema.
- Auth UI now handles immediate signup sessions correctly, distinguishes duplicate/invalid/rate-limited requests, catches auth-stream errors, and clearly explains disabled email recovery. No reset email is promised. Public configuration rejects secret/service-role keys and incorrect API subpaths.
- **FINAL LOCAL CHECKS PASSED**: exact whole-project formatting, static analysis with no issues, **21 Flutter tests**, configured release web build with `/NOVA/`, and configured Android debug APK. Exit codes and UTC completion times are stored in `docs/verification/results.json`. iOS and real mobile device QA remain unexecuted on this Windows environment.
- Official portable GitHub CLI 2.102.1 and Supabase CLI 2.121.0 downloaded from their official GitHub releases into ignored `.tools/`.
- Git initialized and a local checkpoint created before significant code changes. Official GitHub browser login succeeded as `mohamedmohsenarabtec-bot`.
- **PUSHED AND VERIFIED**: https://github.com/mohamedmohsenarabtec-bot/NOVA . Initial commit c6fc963 was verified against refs/heads/main. Public Actions variables `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` and `APP_NAME` are set. Credential scan and private-file exclusion checks passed before push.
- **PAGES DEPLOYED AND VERIFIED**: https://mohamedmohsenarabtec-bot.github.io/NOVA/ . Successful deployment workflow 39614616416 published application commit 690397a. The URL was retrieved from GitHub deployment status, not guessed. HTML and flutter_bootstrap.js both returned HTTP 200 and the base href is `/NOVA/`. Evidence: `docs/verification/pages.json`. Pages initially failed because the owner's plan rejected private-repository Pages (HTTP 422); the owner explicitly approved public visibility, Pages was enabled, and a new deployment succeeded. Later commits add acceptance tooling and documentation without changing that tested application code.
- **REAL BACKEND FLOWS PASSED** using the owner's authorized `+nova1`/`+nova2` Git-email aliases: immediate signup sessions without email, logout/login, duplicate and invalid-credential rejection, profile/preferences/interests persistence, discovery, private-profile and privileged-write denial, like deduplication, mutual match, persistent two-way text messages, fresh-session message reload, authenticated Realtime insert delivery, reporting, ordinary-user moderation denial, temporary authorized moderator report review, and block enforcement on both participants. Generated passwords and tokens stayed in memory. Only accounts created by the test were deleted in cleanup. Evidence: `docs/verification/backend-flows.json`.
- Initial live attempts exposed a Realtime authentication synchronization issue and a Windows relative CLI path error in the moderation test harness. Both were corrected; the complete acceptance run subsequently exited 0. The app now explicitly sets Realtime session authentication before subscribing.
- **BROWSER ACCEPTANCE PASSED**: Chrome opened the actual published site, switched the UI to English, entered the temporary real account's credentials through native Flutter input controls, signed in, opened the matched conversation and reloaded the actual browser page. It then restored the session from browser storage and re-fetched the expected persistent message. Assertions checked authorized message response content and rendered controls; before/after screenshots were visually reviewed (English LTR before, default Arabic RTL after reload). No JWT or password was injected into a build or browser-visible configuration. Local screenshots and isolated Chrome profiles remain under ignored `.local/`, not in Git.
- Complete live run: **18 PASS, zero failures, zero NOT TESTED** within this acceptance script, including test-account cleanup. Earlier harness attempts exposed Windows file/path and Flutter accessibility coordinate/text-label issues; these were corrected rather than reported as application success. Mobile devices, iOS, full admin breadth, media, notifications and payments remain outside this passing acceptance scope.
- **REMOTE CI PASSED**: Flutter checks run 39612139258 passed both Flutter and database jobs. Database job executed `supabase start` + `supabase test db`: `Files=1, Tests=31`, `All tests successful`, `Result: PASS`. It uses an isolated Supabase database and does not reset the owner's project.
- Follow-up CI run 39614616456 also passed. Independent post-test server queries confirmed zero temporary Auth accounts, profiles, staff roles and messages remained after cleanup; preexisting data was never reset or deleted.

## Remaining owner steps and limitations

Open the deployed application and create your own adult account with a password you choose. No paid SMTP or email-verification link is required under the verified development Auth settings. The temporary nova1/nova2 test accounts were deleted and no shared password exists. After the owner registers, assign their staff role using the documented trusted SQL procedure; no permanent administrator was fabricated. No further GitHub/Supabase authorization is currently required.

Account discovery can be empty until genuinely compatible people join. Photos, voice, push, paid subscriptions/payments, complete admin tooling, secure native vault integration and mobile release QA are still incomplete. Email recovery is explicitly disabled, email confirmation is a development-only configuration, and the product is not commercially production-ready.

Both official CLI authorizations are now verified. No database password, privileged key, access token or GitHub password was supplied in chat. The supplied publishable key and legacy anon key are public client keys; only the publishable key is used locally.

## Original scaffold record (historical; current status above takes precedence)

**Development MVP foundation; NOT production-ready or a complete implementation of the requested product. No external backend connection has been demonstrated.**

## Environment

Initially empty directory, no Git repository. Flutter located at `C:\src\flutter` outside PATH: stable 3.47.7 / Dart 3.13.5. Android SDK 37, Java 25, Chrome available. iOS builds unavailable on Windows. No Supabase credentials or CLI, PostgreSQL tooling or Docker found. Packages resolved from local Pub cache. Flutter cache access required approved tool execution outside the workspace.

## Phase ledger

| Phase | Actual outcome |
|---|---|
| 1 — foundation | Flutter root initialized for Android/iOS/web; feature modules, two themes, RTL/LTR, responsive shell, GoRouter and public configuration. No Riverpod; local state and injected repository. |
| 2 — auth/profile/discovery | Email Auth UI/integration, recovery session handling, consent/DOB, onboarding saves, own preferences, public profile detail, server discovery cards/list and honest empty/error states. External execution pending. |
| 3 — backend/matching/chat | Three migrations: tables, constraints, RLS, safe public profile projection, mutual-match transaction/locks, daily limit, text chat RPC and Realtime. Database migrations and authorization suite written but NOT executed here. |
| 4 — safety/admin | Block/unblock, reports, support/appeal submission, visibility, deletion and partial export. Role-checked moderation route and suspension audit. Notifications persist; push absent. Full admin dashboard and verification incomplete. |
| 5 — monetization | Inactive catalog, payment adapter contract, service-only verified-event and credit transactions with idempotency. No receipts/webhooks/checkout/paid benefits implemented. |
| 6 — verification/docs | 15 Flutter tests pass; formatting and analysis pass; web and Android debug builds pass. CI, 30 unexecuted pgTAP checks, Arabic setup and legal drafts added. Further device, backend, security and release work required. |

## Verification evidence

- `flutter create --offline --platforms=android,ios,web`: passed.
- `flutter pub get --offline`: passed using pinned packages.
- `dart format --output=none --set-exit-if-changed lib test`: passed, 20 files checked with zero changes.
- `flutter analyze`: final check passed with **No issues found**. Nineteen brace-style findings introduced by formatting were corrected and rechecked.
- `flutter test`: **15 passed**, zero failures. Includes email/password/age, disabled payment behavior, Arabic/English direction, narrow/wide setup, nullable async result, Auth validation, onboarding save/progression, discovery empty/card/match feedback, conversation empty state, First Spark send, inactive subscriptions and denied staff UI. Widget fixtures do not prove backend authorization.
- `flutter build web --release`: passed after final Dart changes and the Cupertino icon dependency fix. Metadata-only final refresh is recorded in `docs/verification/results.json`.
- `flutter build apk --debug`: final build passed after all Dart changes. First attempt failed in Kotlin cross-drive incremental cache; disabling incremental compilation / using in-process compilation resolved it. Java native-access warnings remain non-fatal.
- iOS build: **not run**; requires macOS/Xcode.
- SQL migrations / pgTAP / live Auth / Realtime / storage: **not run**; missing local database stack and project credentials.
- CI: defined, **not run on a remote runner**.

Final command exit codes and UTC completion times are stored in `docs/verification/results.json`. Full local logs are under `docs/verification/` (ignored by Git's `*.log` rule). Android artifact: `build/app/outputs/flutter-apk/app-debug.apk`. Web artifact: `build/web`. Both are built without backend credentials and open the honest setup screen until rebuilt with public configuration.

## Known product gaps and risks

- No real photo upload/display pipeline, compression, approval or verification review. Private bucket denies upload; no fake photography or verification.
- Text chat only. Voice/images, replies, reactions, typing/read/delivery states, mute/archive UI, unread badges and robust offline/reconnect state remain incomplete. Conversation list is bounded to 50 and has generic titles; needs participant summaries/pagination before launch.
- Media, notifications, verification, subscription and device-token schema foundations are not working integrations. Moments are disabled; saved profiles, rewind, incognito, boosts, credits spending and premium filters are not implemented.
- No location, contacts or unnecessary camera/microphone permissions. Phone OTP and social OAuth absent.
- User-facing admin is a protected route in the shared web build, not a separate admin app. Only report queue/dismiss/suspend implemented; support resolution, unsuspension, revenue/retention metrics, pricing/flags editing and full audit viewer absent.
- Default Supabase Flutter session persistence uses shared preferences, not a reviewed mobile secure vault. Require native secure storage and staff MFA before release.
- Backend age validation relies on declared DOB and is not identity verification. Active discovery/chat require confirmed email.
- Export is partial. Deletion cascades both participants' conversation records. Retention/backup expiration and finance retention need legal/security review.
- Onboarding persists on Continue, not every keystroke; multiple intentions absent. Locale/theme preferences are not persisted. Error messages intentionally generic; more specific localized domain errors remain to be added.
- Discovery offset pages can shift after actions, and chat time-only cursors can skip timestamp ties. Stable keyset pagination required for scale. Blocked conversation content already loaded on another device needs active UI clearing.
- Default branding/icon/package IDs are provisional. Release Gradle currently inherits generated debug signing; configure real release signing before distribution.
- No provider policy, legal compliance, encryption audit or production security certification is claimed. Legal documents are drafts.

## Owner setup and next three launch actions

1. Create Supabase staging + SMTP; install local Supabase CLI/Docker, execute migrations and policy tests, then validate the two-user journey on real devices. Follow `docs/deployment.md`.
2. Complete media moderation, staff operations, secure storage, privacy/retention/legal review and device release QA. Confirm branding and store identities.
3. Create Apple Developer/Google Play accounts, implement real paid benefits and sandbox receipt/webhook adapters, then test renewals/refunds/restore before selling. Firebase/APNs accounts are required only when push is implemented.
