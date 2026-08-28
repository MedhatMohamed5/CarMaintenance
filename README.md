# Vehicle Care

**An offline-first car maintenance tracker that works out *your* service schedule, not the manual's.**

Most maintenance apps assume you service your car exactly every 10,000 km. Nobody does. Vehicle Care anchors every future service to the odometer reading of the last one you actually completed — so being 2,300 km late once shifts the whole road ahead by 2,300 km instead of leaving you permanently out of step with a grid you never followed.

Built for Egypt: Arabic-first, RTL throughout, EGP pricing, local fuel grades.

> 🤖 **This is the first project I built using [Claude](https://claude.ai).**
> 212 Dart files and ~34,000 lines, written over a week of paired sessions.
> The engineering notes near the bottom are the parts that were genuinely
> hard — most of them were bugs that looked like something else entirely.

---

## Features

**Maintenance**
- Service schedule that re-anchors to your real history, not a fixed grid
- 17 wear parts (oil, filters, brakes, belts…) with health derived from your actual driving pace
- Reminders before you're due — daily from 14 days out, or every 2 days once within 1,000 km
- Full service log with cost tracking

**Running costs**
- Fuel logging with real consumption figures (L/100 km or km/L)
- Expense tracking by category
- Insurance and licensing amortised across the year rather than landing as one spike

**Insight**
- Cost and date forecasts projected from how you actually drive
- Charts for spend composition, consumption trends and part wear
- Export to PDF, Excel-compatible CSV, or JSON

**Everyday**
- Multi-vehicle garage
- Workshop directory with call and directions
- Emergency contacts
- Parking location pin — save where you left the car
- Document expiry tracking (licence, insurance) with 30/7/1-day reminders

**Platform**
- Works fully offline; no account required
- Sign in (email or Google) only if you want data synced across devices
- Arabic and English, with Arabic as the default
- Light and dark themes

---

## Screenshots

> _To add: dashboard, service schedule, forecast, and export screens._

---

## Architecture

Clean architecture, one folder per feature:

```
lib/
├── core/                    # cross-cutting: theme, router, storage, auth,
│                            # localization, shared widgets, constants
└── features/
    ├── analytics/           # forecasts, charts, report export
    ├── auth/                # sign-in, account
    ├── dashboard/           # home, alerts, reminder scheduling
    ├── dealers/             # workshops
    ├── emergency/           # emergency contacts
    ├── expenses/            # expense log
    ├── fuel/                # fuel log, consumption maths
    ├── maintenance/         # service schedule, parts health
    ├── notes/               # vehicle notes
    ├── parking/             # parking pin
    ├── settings/            # preferences
    └── vehicles/            # garage, vehicle profiles
```

Each feature splits into `data/` (repositories, mappers), `domain/`
(entities, use cases — pure Dart, no Flutter import) and `presentation/`
(screens, widgets, providers). Repositories are abstract in `domain` and
implemented twice in `data`: once against local storage, once against
Firestore.

### Tech stack

| Concern | Choice |
|---|---|
| Framework | Flutter, Dart SDK ^3.11 |
| State | Riverpod 2 (`Notifier` / `AsyncNotifier`) + flutter_hooks |
| Routing | go_router with `StatefulShellRoute.indexedStack` |
| Local storage | Hive CE + SharedPreferences |
| Cloud | Firebase — Auth, Firestore (offline persistence), Crashlytics |
| Charts | fl_chart |
| Reports | `pdf` package, hand-built RTL-aware layout |
| Notifications | flutter_local_notifications + timezone |

---

## Getting started

```bash
git clone https://github.com/MedhatMohamed5/CarMaintenance.git
cd CarMaintenance
flutter pub get
flutter run
```

The app runs fully offline with no configuration — Firebase is optional.

<details>
<summary><b>Enabling cloud sync</b></summary>

Firebase is wrapped so the app degrades cleanly when it isn't configured
(`lib/core/firebase/firebase_config.dart` catches the `UnsupportedError`
the generated options file throws on unconfigured platforms).

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Then deploy the Firestore rules and indexes:

```bash
firebase deploy --only "firestore:rules,firestore:indexes"
```

For Google Sign-In on Android, register your debug and release SHA-1
fingerprints in the Firebase console. If you ship through Play, the **Play
App Signing** SHA-1 must be registered too — Play re-signs your bundle, so
without it sign-in works everywhere except for the users who install from
the store.

</details>

<details>
<summary><b>Release signing</b></summary>

Create `android/key.properties` from the example, pointing at your keystore.
Use **forward slashes** in the path — the file is read with Java `Properties`
semantics, where a backslash is an escape character, so `E:\keys\app.jks`
silently becomes `E:keysapp.jks`.

</details>

---

## Engineering notes

The problems worth writing down, because each one presented as something
other than what it was.

**The reminder that went silent exactly when it mattered.** A date-driven
reminder starts 14 days before the projected date and runs 15 daily slots —
so its last slot is 9 am on the due date itself. The scheduler *skipped*
occurrences already in the past rather than shifting them, so from that
morning on every slot was behind, and the item armed nothing at all. The app
went quiet precisely when a service came due, and stayed quiet however far
past it went.

**Two rules, tested in the wrong order.** Reminders fire daily by date, or
every two days by distance. Both conditions are usually true at once — a car
700 km from its target is normally also days away from it — and distance was
tested first. The result: the app nagged *less* as the deadline got closer.

**Nothing was ever scheduled on a cold start.** `ref.listen` fires on
change, never on first read, and all the source data hydrates synchronously
from local storage. On launch the value was already complete the first time
it was read, so nothing changed and nothing fired.

**`EntranceAnimation` rebuilt its own subtree.** It returned the bare child
once settled and a wrapped one before, so Flutter replaced the subtree and
every hook beneath it — a progress bar's controller came back at zero and
filled a second time. Measured at 2,125 ms against an expected 1,225 ms.

**The nav bar's height was counted twice.** `extendBody: true` already
publishes the bar's laid-out height to the body as `padding.bottom`; a
manual inset recomputed it from a value that *was already the bar*. 76 pt of
dead space under every scroll view.

**Forcing LTR broke Arabic.** The `pdf` package runs three steps for RTL —
shape/reorder, lay out, then mirror each word's x — all conditional on the
direction being RTL. Forcing LTR on "numeric" table columns skipped all
three for columns that also held `كم` and `ج.م`, so units rendered
backwards. Direction is now decided per string, by content.

**Offline Firestore writes never complete.** A write's `Future` resolves
when the *server* acknowledges. Offline that never happens: the SDK applies
the change locally and fires its listeners, but the future stays pending
forever. Any UI awaiting it hung on a spinner while the data sat visible
behind the dialog.

**R8 stripped the generic signature Gson needs.** `flutter_local_notifications`
persists pending notifications through `new TypeToken<ArrayList<
NotificationDetails>>() {}`, and that type argument lives in the `Signature`
attribute, which R8 drops by default. The boot receiver crashed on every
reboot, losing every scheduled reminder — invisible until Crashlytics was
wired up and reported it the same day.

---

## Status

Pre-release, preparing for Play Store submission.

Known gaps: iOS is configured but the `GoogleService-Info.plist` is not yet
registered in the Xcode project; two legacy test files assert a superseded
fuel contract.

---

## Acknowledgements

Built with [Claude Code](https://claude.com/claude-code). The collaboration
worked best when Claude measured before changing anything — several of the
notes above came from small throwaway probes that proved a theory wrong
before it turned into a commit.
