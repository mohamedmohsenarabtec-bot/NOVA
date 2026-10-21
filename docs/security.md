# Security and launch gates

Implemented: backend 18+ trigger, consent version recording, email/password Auth, server-side preference filtering, reciprocal-match authorization, bidirectional block enforcement, bounded query results, action/message limits, RLS on all application tables, private storage with uploads denied, explicit staff grants, moderation audit events, server-only credit/payment recording functions, generic client error messages, no secret diagnostics.

The age check validates declared birth date; it does not establish identity. Verification is never sold and no UI claims a user is verified without a review.

Before launch:
- Execute database tests and adversarial API tests against staging, including concurrent likes/wallet changes and suspended accounts.
- Set Supabase email confirmation and 12-character password policy; configure production SMTP, CAPTCHA/Auth rate limits and leaked-password checks where available.
- Confirm the implemented verified-email database checks in staging, and never enable anonymous accounts.
- Add protected session storage on mobile, device revocation UX and reauthentication before deletion/export.
- Exercise the implemented report/support daily submission limits; add evidence handling with audited access and per-IP API limits.
- Finish media byte validation, resizing, EXIF removal, malware/content review and authenticated retrieval before allowing uploads.
- Finish admin operations, MFA, role separation tests, incident handling and audited appeal resolution. Staff cannot read private messages through the current admin API.
- Establish retention windows, backup deletion schedule, export completeness (currently profile, sent messages, purchases and submitted reports), legal basis and jurisdiction-specific review.
- Test Android/iOS deep links, browser XSS controls, accessibility, unstable networks, reconnects and account deletion end to end.
- Use a reviewed receipt verifier and signature-checked webhook adapter before enabling any real payments.

The code has not received an independent security audit. Chats are access-controlled on the server, not end-to-end encrypted. Infrastructure operators may have database access.
