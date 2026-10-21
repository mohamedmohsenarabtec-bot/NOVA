# Database

Apply migrations in timestamp order with the Supabase CLI. Never paste a partial migration into a live database. Back up existing projects first. `supabase db reset` is destructive and intended ONLY for disposable local development.

`profiles` includes private DOB, preferences and interests for the MVP. Own-row SELECT prevents DOB disclosure. `discover` returns only public summary fields and calculated whole-year age. `discovery_actions` combines likes/passes with a unique actor/target pair. `matches` canonicalizes UUID order; one conversation per match. Conversation access checks matching participants, both account states and bidirectional blocks.

`reports`, `blocks`, `support_tickets`, `notifications`, `staff_roles` and immutable-through-client `admin_audit_logs` support safety. Roles are server-assigned. `products`, `purchases`, `subscriptions`, `entitlements`, `credit_wallets`, `credit_transactions` and `feature_flags` prepare billing. Media, verification and device-token tables are schema foundations only.

Every public table has RLS. Client privileges are revoked and explicitly regranted. Service-only billing functions serialize wallet changes, validate duplicate event payloads and prevent negative balances. No client function spends credits yet. No provider webhook is implemented.

Storage bucket `private-media` is private, 5 MiB maximum, JPEG/PNG/WebP allowlist. Client uploads are denied until byte inspection, re-encoding, moderation and participant access policies exist. MIME metadata alone is insufficient validation.

`supabase/tests/core_test.sql` is a transactional pgTAP suite with synthetic auth identities that rolls back. Run on local Supabase with `supabase test db`. It is not production seed data. `seed.sql` contains only inactive proposed products. No fake production users.

Deletion cascades from Auth through profiles, matches, conversations and messages. This removes both sides' conversation records when either account is deleted. Billing/audit legal retention and backup expiration need a reviewed retention design before real payments. Media uploads remain disabled, so storage orphan cleanup is not yet required; add it before enabling uploads.

Deferred normalization: separate interest catalog, multiple intentions, distance/geospatial preferences, saved profiles, reactions, boosts and moments. Their tables should be added alongside tested functionality, rather than empty schema promises.
