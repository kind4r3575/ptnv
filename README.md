<p align="center">
  <img src="assets/screenshots/home.png" width="160" alt="Home — active pod countdown">
  <img src="assets/screenshots/addpod.png" width="160" alt="Starting a new pod">
  <img src="assets/screenshots/stock.png" width="160" alt="Stock management">
  <img src="assets/screenshots/history.png" width="160" alt="Session history">
  <img src="assets/screenshots/settings.png" width="160" alt="Settings">
</p>

<h1 align="center">Pod Tracker</h1>

<p align="center">
  A free, fully offline Flutter app that tracks pod wear time, stock, and history<br>
  for people on insulin pump therapy — one less thing to remember.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.12-0175C2?logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/platforms-Android%20%7C%20iOS-informational" alt="Platforms">
  <img src="https://img.shields.io/badge/price-free-brightgreen" alt="Free">
  <img src="https://img.shields.io/badge/backend-none%20%E2%80%94%20fully%20offline-success" alt="No backend">
</p>

---

## Contents

[About](#about) · [Features](#features) · [Privacy](#privacy) · [Roadmap](#roadmap) · [Tech stack](#tech-stack) · [Under the hood](#under-the-hood) · [Getting started](#getting-started) · [Status](#status)

## About

Living with a patch pump means keeping two numbers in your head at all times: when the current pod needs to change, and how many you have left before you run out. Forgetting either one is a small thing that turns into a real, recurring hassle.

Pod Tracker exists to take both off your plate. It shows, at a glance, whether the pod you're wearing is on track, in its grace window, or overdue; it tracks stock automatically as you use it; and it keeps a history of every session so nothing has to be remembered by hand.

It's built to be free for anyone who needs it — no account, no ads, no paywall — for the same reason it exists in the first place: this should be one less thing to manage, not another one.

## Features

**Pod session tracking**
- Live countdown from pod start to rated wear time (default 72h), with a clear visual state for on-track / grace period / overdue
- Configurable pod duration and grace period per pod type
- One-tap Start/End Pod flow, including a custom start-time picker for logging a pod applied earlier
- Starting a new pod while one is active closes the old one out as "Replaced" instead of discarding it

**Stock management**
- Increment/decrement stock with debounced activity logging (rapid taps collapse into a single log entry)
- "Set exact amount" for reconciling stock by hand, plus one-tap undo of the last change
- Estimated days-of-supply and projected run-out date based on usage
- Full stock activity log — restocks, session consumption, manual corrections

**Session history**
- Every completed pod recorded with start/end time, actual wear duration, insertion site, and outcome (on time, ended early, worn too long)
- History clears independently of stock and settings

**Custom notifications**
- User-defined reminder rules: before expiry, before/after the grace window ends, low stock, daily check-in, or a recurring site-rotation reminder
- Rules can be added, edited, toggled, or removed independently — each is scheduled as a real local notification and kept in sync as the active session changes

**Settings**
- Pod type, default duration, grace period, low-stock threshold and reorder toggle
- Notification behavior: sound, vibration, critical alerts, hidden previews, quiet hours, snooze duration
- 12h/24h time and date format, applied consistently everywhere
- Reset to factory defaults without touching stock or history

## Privacy

Pod wear and stock data is sensitive, so the app is built to never let it leave the device:

- No `INTERNET` permission in the Android manifest — it's architecturally incapable of making a network call, not just configured not to.
- No accounts, no sign-in, no analytics or crash-reporting SDK, no ads.
- Everything — session history, stock, notification rules, settings — is stored locally via `shared_preferences` and is deleted if the app is uninstalled.

## Roadmap

Pod Tracker currently covers Omnipod-style patch pumps. Next up:

- **More pump/pod types**, each with its own configurable wear time and grace window instead of one fixed default
- **Beyond pods** — generalizing the same tracking, stock, and reminder system to other supplies with an expiration date (sensors, reservoirs, infusion sets, and similar), so one app can cover more than one device

## Tech stack

| Layer | Choice |
|---|---|
| Framework | Flutter (Material 3) |
| Language | Dart |
| State management | Plain `ChangeNotifier` + `ListenableBuilder` — no external state package |
| Persistence | `shared_preferences`, values JSON-encoded for lists/objects |
| Local notifications | `flutter_local_notifications` + `timezone` / `flutter_timezone` for correct scheduling across time zones |
| Fonts | Poppins, bundled locally as app assets (no runtime font fetch) |

## Under the hood

<details>
<summary><strong>Architecture, engineering decisions, and test coverage</strong> — click to expand</summary>

### Architecture

State lives in one `PodController` (a `ChangeNotifier`) that owns the active pod session, stock, activity log, session history, notification rules, and every setting. The UI reads it through `ListenableBuilder` / `ValueListenableBuilder` — deliberately no `provider`, `riverpod`, or `bloc`, since a single controller covers this app's scope and keeps the dependency footprint minimal.

```
lib/
├── main.dart                     # App entrypoint, MaterialApp + theme wiring
├── screens/                      # One file per screen (Home, Stock, History, Settings, ...)
├── widgets/                      # Reusable UI pieces (sheets, bottom bar, transitions, cards)
├── state/                        # PodController, PodSession/SessionRecord models, NotificationRule
├── services/                     # NotificationService (flutter_local_notifications wrapper)
└── theme/                        # Design tokens: colors, text styles, formatting helpers
```

### Engineering highlights

- **Per-second UI cost is isolated.** The countdown's 1-second tick lives on its own `ValueNotifier` (`PodController.secondTick`), separate from the controller's main `notifyListeners()`, so only the countdown digits rebuild each second — not the whole Home screen, and not other tabs at all (gated by the active tab via `TabListenableBuilder`).
- **Writes are debounced, not per-keystroke.** Stock +/- taps and settings changes are coalesced (400ms save debounce, 3s stock-log debounce, 600ms notification-resync debounce), so rapid interaction never spams disk writes or the notification scheduler.
- **Tabs are an `IndexedStack`, not routes.** Switching tabs never rebuilds a fresh screen or replays a transition — each tab keeps its scroll position and local state.
- **Notification rules are just data.** Each `NotificationRule` is a declarative trigger + offset/time-of-day/recurrence, decoupled from the session it fires relative to. `NotificationService.sync` recomputes concrete fire times from current rules + session state whenever either changes.
- **Reboots don't lose scheduled reminders.** The app requests `RECEIVE_BOOT_COMPLETED` on Android so pending notifications are rescheduled from persisted state after the device restarts.

### Testing

`flutter test` covers two layers, not just the generated counter-app stub:

- **Pure state-machine tests** for `PodSession` — the on-track / grace / late transitions, remaining/overdue/worn duration math, and edge cases like exactly-72h boundaries and clamping negative durations to zero.
- **Widget/integration tests** that drive the real widget tree through `pumpWidget(PodTrackerApp())` — opening the Add Pod and End Pod sheets, starting a pod and confirming the "replace active pod?" guard, adjusting stock and checking the derived days-of-supply, and navigating between Home, Stock, History, and Settings via the bottom bar.

### Design system

The color palette and type scale come from a Figma design file, centralized in `lib/theme/tokens.dart` as `AppColors` / `AppText` — no hard-coded colors or one-off `TextStyle`s scattered through the screens. Status colors (on-track green, grace amber, overdue red) are shared between the countdown card, session history badges, and stock alerts, so the same state reads the same way anywhere in the app.

</details>

## Getting started

**Prerequisites:** [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart SDK `^3.12.2`, per `pubspec.yaml`), and an Android/iOS device or emulator.

```bash
# Install dependencies
flutter pub get

# Run on a connected device or emulator
flutter run

# Run the test suite
flutter test
```

## Status

Pod Tracker is a solo project, actively developed and not yet published to an app store. When it ships, it will be free, with no ads and no paywall.

It's also the project I use to demonstrate what a complete, production-shaped Flutter app looks like end to end — see [Under the hood](#under-the-hood) for the engineering details.

Not affiliated with Insulet/Omnipod or any other pump manufacturer.
