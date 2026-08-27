# Vehicle Care — Session Context Export

> Snapshot taken 2026-08-28. Paste into a fresh thread to resume without
> context loss. Supersedes the 2026-08-25 export and `HANDOVER_CURSOR.md`
> wherever they disagree.

---

## 0. Repo state

- **Path:** `E:\FlutterProjects\CarMaintenance` · package `vehicle_care`
- **`master` is clean and pushed.** `origin/master` == `HEAD` == `6d25c5e`.
- `flutter analyze` → **0 issues**. `dart format lib/` clean.
- **The app builds and runs now.** This is the big change since the last
  export, which was written when Gradle could not build at all. Everything
  below has been exercised on a device unless it says otherwise.
- Arabic is the default locale; RTL is primary. Digits stay Latin via
  `Fmt._digits()`.
- `flutter test` works via PowerShell only (`Set-Location …; flutter test …`);
  bash returns exit 137.

### Toolchain gotchas, all real and all hit this session

| Thing | Problem | Answer |
|---|---|---|
| `flutterfire` | "not recognized" | Installed, but `%LOCALAPPDATA%\Pub\Cache\bin` is not on PATH. Call it by full path or add the dir. |
| `firebase` CLI | `SyntaxError: Unexpected end of JSON input` on every run | Standalone "firepit" build; its first-run check is broken. Prefix `$env:FIREPIT_VERSION="1"`. |
| `./gradlew` | "requires JVM 11, this build uses Java 8" | PATH has Java 8, `JAVA_HOME` unset; Flutter uses Android Studio's JDK 21. Set `JAVA_HOME` to `C:\Program Files\Android\Android Studio\jbr`. |
| SHA-1 for Google sign-in | Gradle needed for `signingReport` | Skip Gradle: `keytool -list -v -alias androiddebugkey -keystore %USERPROFILE%\.android\debug.keystore -storepass android`. |

---

## 1. Firebase — configured and live

**Project `vehicle-care-1148f`.** Android and web configured; rules and indexes
deployed; debug SHA-1 registered.

- `lib/firebase_options.dart` is **generated** — `flutterfire configure`
  rewrites it in full. Never put app logic in it. `core/firebase/
  firebase_config.dart` is the wrapper that owns the app's questions about
  Firebase, including catching the `UnsupportedError` the generated file throws
  for desktop.
- `firestore.rules` — a workspace is owned by the uid that names it. The
  subcollection match is spelled out because **a rule on a document does not
  cascade to its subcollections**.
- `firestore.indexes.json` — four composite indexes, one per
  `.where()` + `.orderBy()` pair. Collected by reading the repositories, not by
  following console links; the app only reports one missing index at a time.
- `firebase.json` carries a `flutter` block written by the CLI **and** a
  `firestore` block added by hand. Without the second, `firebase deploy --only
  "firestore:rules"` says it cannot find a matching target.
- Deploy: `$env:FIREPIT_VERSION="1"; & "E:\firebase_tools\firebase.exe" deploy
  --only "firestore:rules" --project vehicle-care-1148f`

### Still outstanding

- **iOS:** `GoogleService-Info.plist` is in `ios/Runner/` but **not registered
  in the Xcode project** (`grep -c GoogleService-Info.plist
  ios/Runner.xcodeproj/project.pbxproj` → 0). Firebase will not find it at
  runtime. Needs adding from Xcode on a Mac; hand-editing `project.pbxproj`
  means generating UUIDs across three linked sections and a mistake makes the
  project unopenable.
- **Release SHA-1** is not registered. Google sign-in will fail in a release
  build until it is.
- Confirm **Email/Password** and **Google** are enabled in Console →
  Authentication → Sign-in method.

---

## 2. Accounts and sync — the model

**The app is fully usable with no account.** The sign-in screen is reached from
Settings and is never a gate.

- **Signing in is the whole condition for sync.** There is no "data source"
  setting; one existed and was removed. It asked the driver a question they
  cannot reason about, and let someone create an account while still writing to
  a tree no other device could reach.
- **`workspaceId` is the signed-in uid.** It used to be a UUID minted per
  device, which is why cross-device could never have worked: each install wrote
  to its own tree. The generated id survives as the signed-out fallback.
- **Offline is Firestore's own job.** `persistenceEnabled: true` is set, so it
  serves reads from cache and queues writes. **No custom mutation queue was
  built, deliberately** — it would duplicate the SDK badly.
- **Every write goes to the local store as well as the cloud.** Local is
  awaited, cloud is not. Without the mirror, the local copy froze at sign-in
  and signing out rolled the driver back.

### The offline-write trap, and why it matters

A Firestore write's `Future` completes only when the **server** acknowledges.
Offline that never happens — the SDK applies the change locally and fires
listeners, but the future stays pending. Any UI awaiting it hangs forever while
the data sits visible behind the dialog. `core/firebase/offline_write.dart`
(`fireAndForget`) is the fix; it also attaches an error handler, because an
un-awaited future that throws takes the zone down.

**If a save ever hangs again, this is the first thing to check.**

### Merge behaviour on sign-in — an open decision

Local data merges into the account **additively, on every sign-in**: records the
account lacks are uploaded; records it has are never overwritten. Differences
are counted and reported to the user.

It stops there because **no entity has an `updatedAt`** — `date` is when the
fill-up happened, not when the row was edited, so there is no safe way to tell
which side of a conflict is newer.

**Held in reserve:** add `updatedAt` to every entity, model, Firestore mapping
and local store, migrate existing rows, then switch to last-write-wins. Medhat
chose to test the additive behaviour on real data first. **Do not start this
unless asked.**

---

## 3. Traps found this session, each the second-order kind

These cost real time to find. Each one looked like a different bug than it was.

- **Nav bar height counted twice.** `extendBody: true` already publishes the
  bar's laid-out height to the body as `padding.bottom`; a manual
  `_ShellInsets` recomputed it from a value that *was already the bar*. 76 pt
  of dead space under every scroll view, and every FAB floating clear of the
  bar.
- **`EntranceAnimation` rebuilt its subtree on settling.** It returned the bare
  child once settled and a wrapped one before, so Flutter replaced the subtree
  and every hook under it — an `AnimatedProgressBar`'s controller came back at
  zero and filled a second time. Measured: 2125 ms vs 1225 ms.
- **`fillAndStroke` faux-bold.** Widened every glyph by half the stroke, so at
  heading sizes letters merged — "Vehicle report" printed as "Vehicle nepromt".
  The stroke also paints black, which outlined white text on the dark banner.
  **Removed entirely; there is no real bold face in the PDF.**
- **`forceLtr` broke Arabic.** The `pdf` package runs three steps for RTL —
  shape/reorder, lay out left to right, then mirror each word's x — all
  conditional on the direction being RTL. Forcing LTR on "numeric" columns
  skipped all three for columns that also held `كم`, `ج.م` and Arabic headers.
  Direction is now decided per string by content, and nothing may override it.
- **Tables wrapped in a decorated `Container` cannot span pages.** `Container`
  is not a `SpanningWidget`, so a vehicle with more history than one page would
  have produced a widget the engine cannot place — the same "won't fit into the
  page" exception that once broke export outright.
- **Excel and CSV.** Excel does not detect UTF-8 in `.csv` without a BOM; it
  uses the system codepage, so Arabic arrives as mojibake on an English
  Windows. JSON deliberately gets **no** BOM — Dart's own `jsonDecode` fails on
  it.
- **Four FABs, one Hero tag.** `indexedStack` keeps every branch alive, and a
  route pushed on the root navigator searches that whole subtree. Fixed with
  `heroTag: null` — a unique tag would fix the crash but leave a meaningless
  transition.
- **`resolveThemeMode` had no `'system'` arm.** The choice was written
  correctly and died on the next launch. Now matched against `ThemeMode.values`
  so a member cannot be written but not read.

---

## 4. Load-bearing rules

- **`GlassCard` does not blur inside a scrollable.** A `BackdropFilter`
  re-samples every scroll frame; the dashboard's nine cards were nine
  framebuffer reads per frame. Decided in `GlassCard` itself, because the rule
  is a property of *where* a card sits.
- **One entrance per element.** The dashboard ladder owns the entrance; cards
  do not wrap themselves. `AnimationKeepAlive` holds animated widgets so a lazy
  list cannot replay them on scroll.
- **Two distances, never unified** — `trackedDistanceKm` (ownership cost) vs
  `fuelDistanceKm` (consumption). See the 2026-08-25 export.
- **Single sources of truth:** `vehicleMetricsProvider`, `FuelMath`,
  `Contrast`, `context.screenPadding()`, `Fmt`.
- **All modals go through `showAppSheet` / `showAppDialog`** — they carry the
  `ProviderScope` across the root navigator.
- Every new user-facing string goes in **both** `strings_en.dart` and
  `strings_ar.dart`, Arabic translated not transliterated.
- After every change: `dart format lib/`, then `flutter analyze` (must be 0).
- **Never ship test files.** Probes are fine during work and must be deleted.

---

## 5. Native plugins added this session

Five, on a project that could not build at all a week ago. **If a build breaks,
these are the first suspects.**

`geolocator ^14.0.3` · `open_filex ^4.7.0` · `firebase_auth ^5.7.0` ·
`google_sign_in ^7.2.0` · `connectivity_plus ^7.3.1`

- `google_sign_in` **7.x changed its API**: `initialize()` is mandatory, only an
  `idToken` comes back, and the web plugin has no `authenticate()` — the
  browser uses Firebase's own popup.
- `connectivity_plus` is present but **not yet used**; Firestore handles
  reconnection itself.
- Android manifest gained location permissions and `VIEW` intents for the three
  export MIME types (Android 11 hides apps from queries unless declared).

---

## 6. Open and pending

### Needs a person

- **iOS plist registration** (§1) — needs a Mac.
- **PDF colours:** Medhat flagged the dark banner and the vehicle header title
  as needing review. Not yet addressed.
- **Verify on device:** offline save, sign-out after editing, and the
  sign-out → edit → sign-in merge message. These decide whether `updatedAt` is
  worth doing.

### Known gaps

- `test/fuel_stats_test.dart` and `test/models_and_expenses_test.dart` are
  stale — they assert the superseded full-tank contract.
- `_Metric`, `_DetailLine` and `_Row` still exist twice each. Lower value than
  the two that were extracted (`StatTile`, `ServiceStatusBadge`); `_DetailLine`
  is a name collision more than duplication.
- The `workspaces/{uid}` document has no fields — normal for a parent that only
  holds subcollections. Rules and queries are unaffected; it simply cannot be
  enumerated.
- `export_report_screen.dart` has a block commented out by Medhat
  (`exportSavedTo`). Provisional — either finish removing it or restore it.
- No Vehicle Profile screen; `VehicleImageHeader` is unused.
- No price-book UI (`priceBookProvider`, `serviceEstimateProvider` exist).
- `/add-fuel` and `/dealer-details/:id` are wired but nothing navigates to them.

### Unresolved from the previous export

- `.cursorrules` §1 says `ConsumerWidget` exclusively; the app uses hooks in
  ~10 files. Still unresolved.
- `.cursorrules` §3 vs `GuidanceCard` collapsing at card level.
