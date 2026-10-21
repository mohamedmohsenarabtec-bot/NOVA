# Notifications

Match and message events persist in `notifications` inside their transactions. They contain a category/reference ID only; no private text preview. No push is currently delivered, and no FCM integration is claimed.

To finish: create a Firebase project for each environment, register matching Android/iOS/web identifiers, install/configure Firebase Messaging, APNs and web VAPID settings, request permission only on user opt-in, securely register and rotate device tokens. Build a server worker using Firebase Admin credentials from secret storage, with recipient/block checks, muted conversations, category preferences, quiet hours, grouping, deduplication and token cleanup. Never send private message bodies by default. Add delivery/retry and device tests before enabling the `push` flag.
