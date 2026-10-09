# Vehicle Care — Session Context Export

> Snapshot taken **2026-09-29**. Read this fully before doing anything in a new
> session. Supersedes the 2026-08-28 export (`git show 4cca491:SESSION_CONTEXT.md`),
> `HANDOVER.md` and `HANDOVER_CURSOR.md` wherever they disagree.
>
> The Claude Code auto-memory for this project (`MEMORY.md` and its files) is
> loaded automatically and complements this file. If the two disagree, check the
> code — both are point-in-time.

---

## 0. How to work with Medhat — read first

These are standing instructions, most given explicitly and more than once.

| Rule | Detail |
|---|---|
| **Language** | Talk to Medhat in **Egyptian Arabic**. Code, comments, commit messages and this kind of doc stay in **English**. |
| **Git** | **Never commit unless asked.** When asked: commits on `master` (no branches), **one commit per task** — split a file by hunk if two tasks touched it. **No `Co-Authored-By` / no Claude signature, ever.** **Never push** — Medhat pushes. |
| **Commit style** | Imperative subject ("Report a sync stream that fails instead of swallowing it"). Prose body explaining **why**, in the repo's voice. Version bumps are their own commit: `Bump the version to X+Y`. |
| **No test files** | Medhat tests by hand. Never add `test/*_test.dart`. Throwaway probes must be deleted. |
| **After every change** | `dart format lib`, then `flutter analyze` → must be **0 issues**. |
| **Strings** | Every user-facing string in **both** `lib/core/localization/strings_en.dart` and `strings_ar.dart`. Arabic is the default locale. Notification bodies in Arabic are MSA; hints in the app lean light Egyptian. Digits stay Latin everywhere. |
| **"مناقشة" / discussion** | When he says discussion only, **change nothing** — analyse, propose, ask. |
| **"غير المطلوب بس، متعملش build"** | Change only what's required; **he** runs the build. Give him the exact command. |
| **Backlog** | Don't start backlog items unprompted (§7). He picks. |
| **His phone** | Don't assume the make/model of his test device. He'll say when it matters. |
| **Security / trust settings** | Anything that changes cert trust, OEM security settings, or publishes (deploy, store upload): **give him the commands, don't run them.** |
| **Release notes** | Short, emoji per line, **EN + AR**, Play "What's new" friendly. |
| **Comment density** | The codebase explains *why* in long, specific doc comments. Match it. |

### Environment limits (Claude's side)

- **Gradle cannot run in Claude's environment** (`Unable to establish loopback
  connection` — even with the sandbox disabled). **Never claim an Android build
  or on-device behaviour was verified.** `flutter build web --release` *does*
  work here and is the only full-program compile available.
- `flutter test` historically only worked through the PowerShell tool.
- The Bash/PowerShell safety classifier sometimes fails transiently; ~10
  consecutive failures end the turn — stop retrying, do read-only work.

### Medhat's machine

- **Kaspersky Endpoint Security intercepts HTTPS** and re-signs it
  ("Kaspersky Endpoint Security Personal Certification Authority", thumbprint
  `A1469CD22169C17359DDB9BB9A72C027799A3AD4`). Windows tools work; **Node/Java
  tools fail** with `self-signed certificate in certificate chain`.
  - Firebase CLI / npm: `NODE_EXTRA_CA_CERTS=%USERPROFILE%\certs\kaspersky-root.pem`
    (exported PEM). This fixed `firebase deploy`.
  - Gradle, if ever `PKIX path building failed`:
    `systemProp.javax.net.ssl.trustStoreType=Windows-ROOT` in `~/.gradle/gradle.properties`.
  - **Never** suggest `NODE_TLS_REJECT_UNAUTHORIZED=0`.
- Firebase CLI is the standalone build: `E:\firebase_tools\firebase.exe`
  (prefix `$env:FIREPIT_VERSION="1"` if its first-run check breaks).
- JDK 8 is on PATH. Use Android Studio's JBR for key tools:
  `C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe`.
- `apksigner`: `%LOCALAPPDATA%\Android\Sdk\build-tools\36.1.0\apksigner.bat`
  (Play APKs are v2/v3-signed only — `keytool -printcert` won't read them).
- `adb`: `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe` (not on PATH).
- Upload keystore: `E:/FlutterProjects/jks/VehicleCare/vehicle-care-upload.jks`,
  alias `upload`, config in git-ignored `android/key.properties`.
- If a build fails with *"being used by another process"*: several Gradle
  daemons are building into the same `build/`. Stop them:
  `Get-CimInstance Win32_Process -Filter "Name='java.exe'" | ? { $_.CommandLine -match 'GradleDaemon|KotlinCompileDaemon' } | % { Stop-Process -Id $_.ProcessId -Force }`

---

## 1. Repo state

- **Path:** `E:\FlutterProjects\CarMaintenance` · package `vehicle_care` ·
  app name "Vehicle Care" / "العناية بالسيارة" · appId `com.vehiclecare.vehicle_care`
- **`master` == `origin/master` == `5172bcc`.** Working tree clean (except this
  file). 231 Dart files. `flutter analyze` 0 issues.
- **Version `1.0.7+11`** — `+10` was uploaded to Play and is consumed; `+11`
  carries the foreground-service permission removal (§5) and is **not yet
  built/uploaded**.

### Toolchain after the 2026-09-28 upgrade

| | Version |
|---|---|
| Flutter / Dart | **3.47.5** / 3.13.x |
| Gradle / AGP / Kotlin / Java | 8.14 / 8.11.1 / 2.2.20 / 17 — **Flutter warns these will be dropped** (backlog §7) |
| minSdk / compile / target | **24** (explicit — notifications 22 requires it) / 36 / 36 |
| iOS deployment target | **15.0** (FlutterFire 4 requires it) |
| Riverpod | **3.4.3** (6 `StateProvider`s via `flutter_riverpod/legacy.dart`) |
| go_router | 18.0.1 (18.0.2 exists; lock held deliberately) |
| FlutterFire | core 4.15 · auth 6.7 · firestore 6.10 · remote_config 6.7 |
| flutter_local_notifications / timezone | 22.3.1 / 0.11.1 |
| fl_chart / file_picker / flutter_lints | 1.2 / 13.1 / 6.0 |
| sentry_flutter | ^9.28.0 → 9.30.1 (caret only to forbid 8.x, which breaks Kotlin 2.2) |
| google_sign_in / android | 7.2 / 7.2.17 |
| equatable | 2.1 (3.0 blocked by fl_chart pinning ^2.0.7) |

---

## 2. What happened since 2026-08-28 (75 commits)

Read `git log 4cca491..HEAD` for detail — every commit body explains its why.
Grouped:

1. **UI polish** — `showAppSnack` with an action never auto-dismissed
   (`SnackBar.persist` defaults to `action != null` in new Flutter) → `persist:
   false`. All confirm dialogs moved to `AppConfirmDialog` (theme's
   `Size.fromHeight(52)` made AlertDialog buttons infinite-width). Service
   details became a `DraggableScrollableSheet` (`ServiceDetailsSheet`).
2. **Privacy policy** (`docs/privacy-policy/index.html`, English only) updated:
   Sentry replaced Crashlytics, invoices, workshop location (synced) vs parking
   (local), Remote Config, OpenStreetMap tiles, battery exemption.
3. **Sentry & diagnostics** — silent catches now report with tags
   (`phase:bootstrap step:<name>`, `action:pick-image`, `action:schedule-reminder`,
   `action:sync sync.source:<collection>`, `action:google-sign-in`).
   `bindStream` reports Firestore stream errors instead of `onError: (_) {}`.
   Debug builds print what they don't send. Startup line
   `CrashReporter: enabled=… sends=… environment=…`. **Long-press the Settings
   title** → sends a test event (`action:pipeline-test`) and shows its ID.
4. **Vehicle guard** — every vehicle-scoped form (fuel, service/repair, expense,
   note, parking) checks for a vehicle in its own `show()` via
   `VehicleRequired.ensure(context)`; fallback `NoVehicleFallback` inside the form.
5. **Google Sign-In on Play builds** — root cause was the **Play signing
   certificate not registered** in Firebase. Found by pulling the Play APK and
   running `apksigner`. Now registered and **confirmed working**. Also:
   `serverClientId` passed explicitly; `canceled` is now reported to Sentry as a
   warning with Google's message (Credential Manager reports a refused token as
   a cancellation — which is why it looked like "pick account, then nothing").
6. **Flutter 3.47.5 + major-dependency migration** — one commit per stage,
   each analyzes on its own. Riverpod 3 **automatic retry is disabled**
   (`ProviderScope(retry: (retryCount, error) => null)` in `main.dart`) so one broken record isn't a burst
   of Sentry events.
7. **Reminders overhaul** (§4).
8. **Play**: removed `FOREGROUND_SERVICE_LOCATION` pulled in by geolocator (§5).

---

## 3. Firebase / Play / Sentry facts

- **Firebase project** `vehicle-care-1148f`. Web client (serverClientId):
  `718762511471-cv5hkvpgq5h9jil478m3d9c2l8f1suc0.apps.googleusercontent.com`
  (hard-coded default in `firebase_auth_service.dart`, overridable with
  `--dart-define=GOOGLE_SERVER_CLIENT_ID`).
- **Android SHA-1s registered:** debug `b3916bec…`, upload `f7e48d33…`,
  **Play app signing `b44035492c58c7f9c49478ef7dce9d0c24f5980a`** (the one that
  fixed sign-in), plus two unidentified: `9dd92dd3…`, `89f96530…`.
- **Hosting:** `firebase.json` serves `build/web` with a `** → /index.html`
  rewrite. The policy pages live in `docs/` — **copy them into `build/web`
  before deploying** (`cp -r docs/privacy-policy docs/delete-account build/web/`);
  existing files win over rewrites. Deploy with `firebase deploy --only hosting`
  (**`--only` matters** — firebase.json also has Firestore rules/indexes).
  Build: `flutter build web --release --source-maps --dart-define=SENTRY_RELEASE=vehicle_care@<version>`.
- **Sentry:** DSN committed as default in `crash_reporter.dart`
  (`--dart-define=SENTRY_DSN=` to override/disable). `SENTRY_IN_DEBUG=true`
  lets debug send; `SENTRY_DEBUG=true` turns on SDK logging. Org `free-hz`,
  project `vehicle-care`. The one SIGSEGV seen came from a **Play pre-launch
  emulator** (spoofed "OnePlus8Pro", x86_64, 2 CPUs) — noise, archive it.
  Tombstones need Android 12+.
- **`CrashReporter` is the only seam** — nothing else names Sentry.
- **Play Data safety** (as discussed; Medhat hasn't confirmed he filled it in):
  Photos (incl. invoices) collected/optional; Location collected/optional
  (workshop pin — parking is local-only, not "collected"); Name/Email optional;
  User IDs (uid to Sentry); Crash logs & diagnostics collected/**required**;
  nothing processed ephemerally; encrypted in transit; deletion URL = the
  `delete-account` page.
- **Pre-launch report** runs every upload on Google's devices (many are
  emulators) — expect noise.

---

## 4. Reminders — how it works now

File: `lib/features/dashboard/presentation/providers/reminder_scheduler.dart`.

- **Plan, then arm.** Every kind contributes `_Candidate`s; `_select` drops
  switched-off kinds, caps advisory ones at **2 per day** (critical exempt:
  documents, bookings eve/day, parking), pushes "can wait" ones up to 3 days,
  then fits **60** pending (iOS limit 64), critical first, rest soonest first.
- Kinds (`ReminderCategory`, one switch each in Settings): documents, bookings
  (+ follow-up the day after an unconfirmed booking), maintenance (services &
  parts, with estimated cost in the body), routine (coolant/tyres every 14 days,
  oil every 30), seasonal (khamaseen 15 Mar, summer 1 May, winter 1 Nov),
  odometer (14 days after last reading, then weekly), fuel economy (last 3 fills
  ≥15% worse, same fuel family), monthly summary (1st), parking (per pin, 1/2/3 h).
- **Cadences are anchored** to stored start days (`pref_reminder_anchors`) —
  the old code re-based on "now" every pass, so routine checks never fired for
  active users. Day maths is calendar-based (Egypt has DST).
- Reminder hour: 9 / 13 / 19 (`ReminderPrefs`). Bookings and parking keep
  their own times.
- Rescheduled on launch, on data change (`reminderSignatureProvider`), and **on
  every return to foreground** (`didChangeAppLifecycleState` in `main.dart`).
- **Only the selected vehicle** gets reminders (open item).
- `inexactAllowWhileIdle` — no exact-alarm permission, by choice (Play policy).
- **Decided: no WorkManager.** Don't re-propose unless reminders stop after long
  periods without opening the app.
- **Never run on a real device yet.**

---

## 5. Android manifest notes

`android/app/src/main/AndroidManifest.xml` removes, with `tools:node="remove"`:
`READ_MEDIA_IMAGES/VIDEO/AUDIO` (from open_filex) and
**`FOREGROUND_SERVICE_LOCATION`** (from geolocator 5.1.1 — the app only uses
`getCurrentPosition`; the service entry is kept because the plugin binds to it).
The bundle still contains `DUMP` (androidx profileinstaller's receiver) and
`USE_BIOMETRIC`/`USE_FINGERPRINT` from a dependency — not investigated.

`proguard-rules.pro`: the Gson keep rules are **load-bearing** for
flutter_local_notifications' boot receiver. No extra rules are needed for
Google Sign-In (Credential Manager ships its own consumer rules).

---

## 6. Load-bearing rules (carried forward, still true)

- **All modals via `showAppSheet` / `showAppDialog`** — they carry the
  `ProviderScope` across the root navigator.
- `GlassCard` does not blur inside a scrollable.
- Single sources of truth: `vehicleMetricsProvider`, `FuelMath`, `Fmt`,
  `context.screenPadding()`, `CrashReporter`.
- Two distances, never unified: `trackedDistanceKm` vs `fuelDistanceKm`.
- A Firestore write's Future only completes on server ack — offline it hangs.
  Use `fireAndForget` (`core/firebase/offline_write.dart`). **If a save ever
  hangs, check this first.**
- Every write goes to local **and** cloud; local awaited, cloud not.
- Sign-in merge is additive; no `updatedAt` exists. Last-write-wins is held in
  reserve — **don't start it unless asked**.
- `lib/firebase_options.dart` is generated — never edit by hand.

---

## 7. Open backlog — to discuss before building

### New features (Medhat's requests)

1. **Service interval setting** — global default **5,000 or 10,000 km**,
   overridable **per vehicle**; all of that car's calculations follow it.
   Questions: `ServiceCatalog` phases assume 10,000 km steps and records store
   `milestonePhase` — how to treat existing history; does the months limit
   scale; relation to per-part `PartSetting.intervalKm`.
2. **Fuel calculations across fuel types** — switching grades (92↔95), petrol↔CNG
   (litres vs m³), a tank topped with another grade, dual-fuel cars with an
   unknown km split, cost per km across types.
3. **In-app update** — Play In-App Updates (flexible vs immediate) is
   Android-only and Play-installed only; a Remote Config min/latest version
   check would cover iOS and web too and allow forcing an update. Testing needs
   internal app sharing or a track install.
3b. **Digits setting** (agreed 2026-09-29, **not now**) — a Settings choice
   between Arabic-Indic (٠-٩) and Latin digits in the Arabic UI; Latin stays
   the default. The choice rides on the locale tag every `Fmt` call already
   receives, so screens watching `localeTagProvider` follow it; `l10n.fmt`
   arguments, the PDF, notifications, chart axes, the raw `toStringAsFixed`
   UI sites and literal digits in `strings_ar` follow it too. CSV stays Latin;
   car-model names and codes ("B14") are untouched; numeric inputs parse both
   digit sets.

### Bugs / in discussion

4. **Settings self-test**: the one-minute scheduled notification doesn't arrive
   once the app is closed. Waiting on Medhat's tests — A: Home, don't reopen for
   10 min; B: swipe from recents, don't reopen. Known own bug: `_selfTest` is
   in memory, so a cold start within the minute cancels it via `cancelAll()`.
   Proposed fix: cancel only scheduler-owned ids (persisted) instead of
   `cancelAll()`. Also possible: inexact delay; OEM force-stop on swipe.
5. Reminders cover the **selected vehicle only**.
5b. **Numeric input rejects Arabic-Indic digits** — ~24 raw
   `double/int.tryParse` sites with no normalisation, so a keyboard that types
   ٠-٩ fails validation. Independent of 3b.

### Deferred / blocked

6. **Android toolchain upgrade** — Gradle 9.3.1 / AGP 9.1.0 / Kotlin 2.4.0,
   drop `multiDexEnabled`. **Now unblocked** (sign-in confirmed). Keep the AGP 9
   opt-outs in `gradle.properties`; the app needs `android.enableJetifier=true`
   (disable_battery_optimization); Medhat must build to verify.
7. Fuel-price push notification — waits for FCM.
8. Six `StateProvider`s → Notifiers (Riverpod 3 `legacy.dart`).
9. equatable 3 (blocked), go_router 18.0.2 (trivial).

### Medhat's side

10. Build `1.0.7+11`, upload replacing `+10`, confirm the permission is gone.
11. Play Data safety — confirm filled in.
12. Identify the SHA-1s `9dd92dd3…` / `89f96530…`.
13. Real coordinates for the 4 default workshops (Remote Config `workshops` +
    `bundled_workshops.dart`); a coordinate-validation snippet was proposed but
    not applied.
14. Archive the pre-launch SIGSEGV in Sentry.
15. **On-device pass** over everything since the SDK upgrade: notifications
    (v22), boot persistence, charts, file attachments, all new reminders,
    parking reminder, vehicle guard.

### Still open from the 2026-08-28 export

16. iOS `GoogleService-Info.plist` not registered in `project.pbxproj` — needs a Mac.
17. PDF colours (dark banner, vehicle header) flagged for review.
18. Stale tests: `test/fuel_stats_test.dart`, `test/models_and_expenses_test.dart`
    assert a superseded contract.
19. `export_report_screen.dart` has a block commented out by Medhat (`exportSavedTo`).
20. No price-book UI; `/add-fuel` and `/dealer-details/:id` routes unused.
21. `.cursorrules` §1 (ConsumerWidget only) vs hooks in ~10 files — unresolved.
