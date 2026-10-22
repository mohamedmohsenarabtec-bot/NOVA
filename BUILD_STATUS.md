# NOVA 0.3 — verified development preview

Current iteration: 22 October 2026. This is a development preview, not a commercially approved release. Historical evidence remains under docs/verification; this file supersedes older status claims.

## Implemented

- Flutter renders before network initialization. Preferences, Supabase initialization and server capability checks have bounded waits; disconnected startup shows a real Retry screen. The old code awaited network readiness before runApp, consistent with the owner's Xiaomi splash-only report. The precise failure on that physical phone remains unverified.
- Persistent public profile editor: private DOB/server age validation, display name, username, city, biography, languages, interests, gender/audience, intention, optional education/occupation/lifestyle/partner details, individual field visibility, completion progress and unsaved-change confirmation.
- Six private-bucket profile photos: gallery selection, real preview/consent, JPEG conversion, orientation, resizing and EXIF removal, upload/finalize, ordering, deletion and public/matched/private visibility. Owner-only direct storage download; cross-user bytes pass through an authenticated Edge function checking RLS on each request. Blocking was verified to deny subsequent retrieval. Already-received bytes cannot be recalled.
- Real server-filtered discovery with pagination, retry and honest empty states; saved ages/region/gender/intention and entitlement-gated advanced filters. Manual broad region, no GPS/radius tracking. Fictional development users are isolated from ordinary users.
- Private favorites; idempotent 48-hour pending likes; transactional reciprocal matching; established conversations do not expire. In-app liked-you screen exposes a genuine count to Free and permitted identities only to actual Premium entitlements. Mutual-match text chat remains free, with authenticated Realtime and unread acknowledgement.
- Persistent in-app notifications: unread/read/all, pagination, generic previews, deduplication and permitted navigation. No FCM/APNs push.
- Configurable illustrative membership offers and duration totals/monthly equivalents. Free/Plus/Premium entitlement gates are server-enforced. Payments, auto-renewal and trial activation remain disabled. No checkout or fake purchase success. Restore explains the missing provider.
- Referral code/link/copy/native share/progress and server-side claim, uniqueness, self-referral prevention, private identity fingerprints and controlled qualification/reward procedures. Rewards default OFF; no benefit for opening a link. No contacts uploaded.
- Own account details and own-data export; staff entry only for authorized roles; direct admin operations independently reject ordinary users. Seven-day account-deletion request/cancellation workflow.

## Database and actual verification

Migrations 005–010 were applied additively to the existing project after isolated CI; no production reset. Legacy client_readiness remains 4 for installed clients; new client_capabilities is 10. Existing owner and two ordinary development users were preserved. These development users are labelled and isolated; no additional real eligible public profiles currently exist.

- Isolated GitHub PostgreSQL/pgTAP: 95 assertions, PASS, run 39735697415 (schema commit 5641dd6).
- Live acceptance: real signup, persisted profiles, public/private projection/RLS, regional filters, favorites, real photo storage/privacy/order, 48-hour pending state, reciprocal match, two-way persistent Realtime chat, notifications, disabled billing, referral claims and block/photo denial: PASS on 22 October. Only newly-created QA identities/photos were removed afterward.
- Flutter format/analyze/tests and final release/deployment evidence: see docs/verification/iteration-0.3.json when completed. Do not interpret a pending workflow as success.

## Release validation still being finalized

Repository: https://github.com/mohamedmohsenarabtec-bot/NOVA
Web: https://mohamedmohsenarabtec-bot.github.io/NOVA/
The deployed source revision is published at /NOVA/build-info.json. Local APK is build/app/outputs/flutter-apk/app-release.apk; release download and SHA256 must be recorded after upload and comparison.

Local Windows Android emulator crashes with 0xC0000005 before Android boots; no physical Xiaomi device is connected. The Android CI installation workflow downloads the exact release APK, installs/launches it and captures online/offline retry evidence. Its actual result must be checked before claiming installation validation. APK uses the existing Android Debug certificate for controlled installation, not a Play Store production key.

iOS gallery permission and shared code are prepared, deployment target 15.0. Windows cannot build/sign iOS. macOS CI is configured; no successful current iOS build/device validation is asserted. Apple signing, provisioning and store setup remain necessary.

## Remaining operational/product work

- Business approval of prices, trial/reward rules; store-compliant billing/receipts/restores/refunds before enabling payments. Boosts and extra profile customization are not advertised as working benefits.
- Referral staff qualification has server procedures/audit but no full operator dashboard. Rewards/trials intentionally OFF. Current reward implementation uses the documented conservative defaults (25 extra daily likes for 7 days, max 3/30 days, minimum invitee age 7 days); changing the JSON proposal alone does not change all server limits.
- Retention maintenance is operator-only, not scheduled. Deletion requests persist and hide profiles, but the reviewed seven-day purge/anonymization worker is NOT implemented. Authorized staff must handle requests under the published policy; no automatic deletion is claimed.
- Automated media content/malware moderation, phone/identity verification, push, voice/media chat, production native session vault, physical-phone QA and store release remain incomplete. Photo client decoding/metadata removal and server size/MIME checks do not constitute a malware scanner.
- Development Auth currently permits immediate signup without email confirmation. Recovery email remains disabled until SMTP/deep links are verified. Reassess before public launch.
