# Moderation

Current staff portal supports pending-report review, dismissal and account suspension, all checked and logged in PostgreSQL. Support-role users cannot moderate. Regular users cannot self-assign roles or change verification/status fields.

Create the first administrator only in the trusted Supabase SQL editor after that person registers and verifies their account:

```sql
insert into public.staff_roles(user_id,role)
select id,'administrator' from auth.users
where email = 'REPLACE_WITH_VERIFIED_OWNER_EMAIL' and email_confirmed_at is not null
on conflict do nothing;
```

Confirm exactly one intended owner was selected. Never use a public registration route for staff. Assign `moderator` or `support` instead of administrator when sufficient. Revoke with a server-side DELETE. Enable staff MFA before launch.

The portal does not expose message contents. Reported-message evidence, photo/identity verification, verified status changes, staff support queue, appeals resolution, unsuspension UI, audit browsing, configurable questions, retention/revenue analytics and pricing administration remain unfinished. No purchased verification.

Users can submit support/appeal text; response and resolution tooling still needs implementation. Suspended users lose discovery/chat access, but retain account settings, export/deletion and support submission. Train reviewers and establish response, escalation and evidence retention policies before inviting public users.
