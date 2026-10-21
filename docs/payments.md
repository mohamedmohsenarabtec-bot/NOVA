# Payments: disabled by design until integration

`PaymentService` defines hosted checkout, store purchase and restore operations. The default implementation throws a configuration error. No checkout session, price, subscription benefit or credit purchase is simulated.

`record_verified_purchase` accepts only server-verified events through service_role. It uses provider/event uniqueness and a transaction advisory lock; payload conflicts fail. `apply_credit_delta` locks wallets and writes a unique audit event in the same transaction. Entitlement reads require an unexpired timestamp. These are primitives, not an operational billing system.

Remaining: select store adapter (for example a reviewed in-app purchase service), create App Store Connect/Google Play products, implement receipt verification and account binding, authenticated restore, webhook signature validation, refund/revocation/renewal/grace-period handling and out-of-order event resolution. Build a hosted web checkout adapter only for supported countries/use cases. Do not activate proposed plans until benefits actually exist.

Store and regional payment policies change. Check current official Apple/Google rules with legal/provider advice at integration time; this repository makes no claim of store-policy compliance. Use provider sandbox and idempotency tests before live credentials.

Keep provider secrets and service-role keys in server secret storage. Never put them in dart-define, web builds or .env files consumed by Flutter. Revenue reports and net-fee/tax accounting are not implemented.
