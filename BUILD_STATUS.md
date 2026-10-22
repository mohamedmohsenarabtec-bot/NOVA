# NOVA 0.3 — verified development preview

Current iteration: 22 October 2026. This is a development preview, not a commercially approved release. Historical evidence remains under docs/verification; this file supersedes older status claims.

## Implemented

- Flutter renders before network initialization. Preferences, Supabase initialization and server capability checks have bounded waits; disconnected startup shows a real Retry screen. The older APK also failed before runApp while reading preferences. Release mapping and emulator diagnosis identified shared_preferences_android 2.5.1 JNI lookups broken by R8 renaming Kotlin interop classes. Six narrow upstream keep rules preserve these types; minification remains enabled. Physical Xiaomi verification remains unavailable.
- Persistent public profile editor: private DOB/server age validation, display name, username, city, biography, languages, interests, gender/audience, intention, optional education/occupation/lifestyle/partner details, individual field visibility, completion progress and unsaved-change confirmation.
- Six private-bucket profile photos: gallery selection, real preview/consent, JPEG conversion, orientation, resizing and EXIF removal, upload/finalize, ordering, deletion and public/matched/private visibility. Owner-only direct storage download; cross-user bytes pass through an authenticated Edge function checking RLS on each request. Blocking was verified to deny subsequent retrieval. Already-received bytes cannot be recalled.
- Real server-filtered discovery with pagination, retry and honest empty states; saved ages/region/gender/intention and entitlement-gated advanced filters. Manual broad region, no GPS/radius tracking. Fictional development users are isolated from ordinary users.
- Private favorites; idempotent 48-hour pending likes; transactional reciprocal matching; established conversations do not expire. In-app liked-you screen exposes a genuine count to Free and permitted identities only to actual Premium entitlements. Mutual-match text chat remains free, with authenticated Realtime and unread acknowledgement.
- Persistent in-app notifications: unread/read/all, pagination, generic previews, deduplication and permitted navigation. No FCM/APNs push.
- Configurable illustrative membership offers and duration totals/monthly equivalents. Free/Plus/Premium entitlement gates are server-enforced. Payments, auto-renewal and trial activation remain disabled. No checkout or fake purchase success. Restore explains the missing provider.
- Referral code/link/copy/native share/progress and server-side claim, uniqueness, self-referral prevention, private identity fingerprints and controlled qualification/reward procedures. Rewards default OFF; no benefit for opening a link. No contacts uploaded.
- Own account details and own-data export; staff entry only for authorized roles; direct admin operations independently reject ordinary users. Seven-day account-deletion request/cancellation workflow.

## Database and actual verification

Migrations 005–012 were applied additively to the existing project after isolated CI; no production reset. Legacy client_readiness remains 4 for installed clients; new client_capabilities is 10. Existing owner and two ordinary development users were preserved. These development users are labelled and isolated; no additional real eligible public profiles currently exist.

- Isolated GitHub PostgreSQL/pgTAP: 104 assertions, PASS, run 39738313424 (schema commit 6d22724).
- Live acceptance: real signup, persisted profiles, public/private projection/RLS, regional filters, favorites, real photo storage/privacy/order, 48-hour pending state, reciprocal match, two-way persistent Realtime chat, notifications, disabled billing, referral claims and block/photo denial: PASS on 22 October. Only newly-created QA identities/photos were removed afterward.
- Final local dart format ., flutter analyze (zero issues), flutter test (34 PASS), web release (/NOVA/) and APK release: PASS. Published-browser acceptance: 13 PASS including QA cleanup, 2026-10-22 07:37 UTC.
- Current app-source CI 39741045339: Flutter and database PASS. Safe evidence: docs/verification/iteration-0.3.json.

## Verified release validation

Application source: 1c8648d43a4e315b1a9946150ec057daec69858a (later documentation/tooling-only commits do not change the tested application).

- Repository: https://github.com/mohamedmohsenarabtec-bot/NOVA
- Live application: https://mohamedmohsenarabtec-bot.github.io/NOVA/
- Pages run 39740709517 PASS; build-info.json matched the app-source SHA. Actual Chrome verified login, preferences persistence, RTL/LTR, authenticated photos, account/editor/filters/favorites/liked-you/notifications/referrals/catalog and persistent chat after reload. Mobile layout screenshot reviewed at 390 px. The latest deployment revision is always /NOVA/build-info.json.
- APK: https://github.com/mohamedmohsenarabtec-bot/NOVA/releases/download/v0.3.0-preview.3/app-release.apk
- Actual local path: build/app/outputs/flutter-apk/app-release.apk, 63,120,118 bytes; version 0.3.0 (code 4), package com.nova.app.nova, minimum API 24, target 36, arm64-v8a/armeabi-v7a/x86_64.
- SHA256: 5F74949CADFBA49056D7E311FAF427445548CF0BEEE9CDFB169685D66C3C4C1C. Downloaded final release matches local SHA. APK signature verification and 16 KiB ZIP alignment passed. Existing Android Debug certificate SHA256: 4d1e7bebce9e07f404cc41ba42069b28cf547c1072883a0f218a959b96139834. Controlled testing only, not Play Store signing.
- Android 35 emulator run 39741049121 PASS: exact published APK installed, reached actual Arabic Auth while online, showed Retry offline, and returned to Auth by pressing the real Retry button after restoring connectivity. Install/launch logs and all three screenshots reviewed; no fatal/unhandled runtime exception. No accounts or passwords were placed in CI.
- Original v0.2.0-preview.2 reproduction run 39739967181: failed as expected; logcat contains NoSuchMethodError on SharedPreferencesApiRegistrar.getAll through kotlin.coroutines.Continuation before runApp. R8 had renamed Kotlin interop types. Six targeted rules from Flutter upstream fix 13311 preserve names without disabling optimization. A preliminary PID-only check was insufficient; final acceptance explicitly requires Auth and recovery.
- Local Windows emulator still crashes with 0xC0000005 before Android boots. No physical Xiaomi was connected or tested. Native image selection/authenticated feature interaction on a physical phone remains unverified.
- iOS unsigned Xcode build PASSED on macOS: run 39740709559, source 1c8648d, Runner.app 21.8 MB. Gallery permission and deployment target 15.0 inspected. No signing, iPhone installation, device QA or App Store release is claimed; Apple signing/provisioning/account remain necessary.
- Credential scan: tracked text, compiled web and all three native Dart app images contain no controlled test passwords/account identifiers or detected privileged keys. Private local config/access files and binaries are excluded from Git. Public client configuration validated.

## Remaining operational/product work

- Business approval of prices, trial/reward rules; store-compliant billing/receipts/restores/refunds before enabling payments. Boosts and extra profile customization are not advertised as working benefits.
- Referral staff qualification has server procedures/audit but no full operator dashboard. Rewards/trials intentionally OFF. Product daily allowances and bounded reward rules are server-configurable; default proposal is 25 extra daily likes for 7 days, max 3/30 days, minimum invitee age 7 days.
- Retention maintenance is operator-only, not scheduled. Deletion requests persist and hide profiles, but the reviewed seven-day purge/anonymization worker is NOT implemented. Authorized staff must handle requests under the published policy; no automatic deletion is claimed.
- Automated media content/malware moderation, phone/identity verification, push, voice/media chat, production native session vault, physical-phone QA and store release remain incomplete. Photo client decoding/metadata removal and server size/MIME checks do not constitute a malware scanner.
- Development Auth currently permits immediate signup without email confirmation. Recovery email remains disabled until SMTP/deep links are verified. Reassess before public launch.
