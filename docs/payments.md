# Payments: disabled by design until integration

`PaymentService` defines hosted checkout, store purchase and restore operations. The default implementation throws a configuration error. No checkout session, price, subscription benefit or credit purchase is simulated.

`record_verified_purchase` accepts only server-verified events through service_role. It uses provider/event uniqueness and a transaction advisory lock; payload conflicts fail. `apply_credit_delta` locks wallets and writes a unique audit event in the same transaction. Entitlement reads require an unexpired timestamp. These are primitives, not an operational billing system.

Remaining: select store adapter (for example a reviewed in-app purchase service), create App Store Connect/Google Play products, implement receipt verification and account binding, authenticated restore, webhook signature validation, refund/revocation/renewal/grace-period handling and out-of-order event resolution. Build a hosted web checkout adapter only for supported countries/use cases. Do not activate proposed plans until benefits actually exist.

Store and regional payment policies change. Check current official Apple/Google rules with legal/provider advice at integration time; this repository makes no claim of store-policy compliance. Use provider sandbox and idempotency tests before live credentials.

Keep provider secrets and service-role keys in server secret storage. Never put them in dart-define, web builds or .env files consumed by Flutter. Revenue reports and net-fee/tax accounting are not implemented.

## 0.3 catalog and entitlement boundaries

membership_offers defines Free, Plus and Premium with currency, illustrative total price, duration, trial proposal and implemented feature metadata. Monthly/3/6/12-month selection calculates equivalent monthly cost from the returned data. Free allows profile/photos, discovery, capped likes, mutual matches/chat, favorites, basic filters, safety and in-app notifications/referrals. Plus grants server-owned advanced filters and higher daily allowance; Premium also grants authorized liker identities. No boost, unlimited likes, paid customization or store entitlement is falsely advertised as working.

Seven-day trial eligibility is computed server-side; activate_verified_trial is server-only, approved-flag gated, identity-history guarded and audited. Production flags remain OFF. Purchase buttons request information through a real support ticket; they never simulate success. Restore reports the missing provider and refreshes server state. Cancellation/refund/renewal/receipt verification still require a real provider implementation. No payment data or live billing keys were collected.
