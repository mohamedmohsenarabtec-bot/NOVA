# Architecture and implemented scope

Flutter 3.47.7 / Dart 3.13.5, pinned cached Supabase Flutter 2.18.3 and GoRouter 18.1.0. Package APIs were inspected locally. Flutter's StatefulWidget owns local presentation state; repository injection separates network calls. Riverpod is not required for this MVP. Replace map DTOs with generated typed models before expanding the product.

`lib/app` owns theme, locale, session gate, responsive shell and routes. Feature modules own UI. `shared/repository.dart` is the single Supabase boundary. `core` owns configuration, translations and validation. Arabic is the initial language. Material delegates supply RTL/LTR and translated system dialogs; application strings use paired Arabic/English values.

Routes use GoRouter hash URLs on web, including `/#/admin` and `/#/chat/:id`, so static hosting refreshes work without rewrites. Admin is a protected staff route in the same web bundle, not yet a separate deployment/application. The database independently enforces every staff operation. No privileged client keys.

No data is fabricated. Missing configuration produces a setup state, unavailable paid features explain why. Profile photography, media upload, voice, advanced chat and push are deliberately unavailable pending real implementations.

Flow: verified email session → persisted onboarding → server-filtered discovery → transactional reciprocal like → private conversation → text messages via RPC → Realtime invalidation under message RLS. RLS controls reads; narrowly granted security-definer RPCs control sensitive writes. Blocking immediately denies subsequent reads and writes. Data already received on another device cannot be recalled; UI should clear cached conversation data on safety events in a subsequent release.

Supabase Flutter provides session persistence; its default shared-preference storage is not an encrypted native credential vault. Add a reviewed Keychain/Keystore adapter before production. Browser storage remains exposed to origin scripts: enforce HTTPS, a tested CSP and dependency review.

Current pagination is bounded offset discovery and time-cursor chat. Discovery pages can shift as actions remove profiles. Move discovery to stable keyset cursors for launch-scale traffic. Realtime reconnect/delivery acknowledgements and missed-event reconciliation need further testing.
