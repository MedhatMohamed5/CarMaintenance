# Vehicle Care — Handover & Context for Cursor

You are continuing development on an existing, mature Flutter codebase. Read this
document fully before making changes. Do not re-architect what is already
working; extend it in the established patterns.

---

## 0. Ground truth before you start

| Fact | Why it matters to you |
|---|---|
| **Repo:** `E:\FlutterProjects\CarMaintenance` · **package:** `vehicle_care` | The product is branded **Vehicle Care** (`appTitle` = "Vehicle Care" / "العناية بالسيارة"). If you have seen it called *CarHub*, that is an alias, not the package name. Do not rename anything. |
| **152 Dart files** under `lib/`. `flutter analyze` → **0 issues**. | Keep it at zero. Run `flutter analyze` after every change. |
| **The app has never been built or run.** Gradle fails on this machine with `java.io.IOException: Unable to establish loopback connection`. | **Every behavioural claim in this document is verified by the analyzer, by targeted `flutter test` probes, and by source reading — never by running the app.** Do not assert runtime correctness you have not observed. |
| Last commit: `1808eab Complete App before Cleaning and refactoring`. Working tree clean. | You have a safe rollback point. |
| `flutter test` works only via PowerShell (`Set-Location E:\FlutterProjects\CarMaintenance; flutter test ...`); bash returns exit 137. | Use PowerShell for tests. |
| **Arabic is the default locale.** RTL is the primary layout. | Use `EdgeInsetsDirectional`, `PositionedDirectional`, `AlignmentDirectional`. Never `EdgeInsets.only(left:)`. |
| Numbers render in **Latin digits even in Arabic** (`Fmt._digits()` pins numeric patterns to `en`). | Never wrap a mixed Arabic+digit string in `AppTypography.numeric` — RobotoMono has no Arabic glyphs and the baseline breaks mid-string. Digits only. |

---

## 1. Product

A vehicle maintenance and running-cost tracker for a single driver with one or
more cars.

**Core features:** multi-vehicle switching · odometer tracking · fuel logging
with partial fill support · consumable-part wear engine · harmonic service
schedule with projections · expenses · workshop/dealer directory · emergency and
fuel guidance · analytics with PDF/CSV/JSON export · local notifications for
services, wear parts, licence and insurance.

---

## 2. Architecture

Clean Architecture per feature:
`domain/{entities,repositories,usecases}` → `data/{models,datasources,repositories}`
→ `presentation/{providers,screens,widgets}`.

```
lib/core/      bootstrap constants error firebase localization platform
               providers router services storage theme utils widgets
lib/features/  analytics dashboard dealers emergency expenses
               fuel maintenance settings vehicles
```

### 2.1 Stack

`flutter_riverpod ^2.6.1` (hand-written Notifiers, **no codegen** — no `.g.dart`,
no `build_runner`, no `riverpod_annotation`) · `go_router ^14.6.2` · `hive_ce` ·
`shared_preferences` · `cloud_firestore` + `firebase_core` (opt-in at runtime) ·
`fl_chart` · `pdf ^3.11.1` · `path_provider ^2.1.5` · `flutter_local_notifications`
· `google_fonts` · `image_picker` · `url_launcher` · `intl`.

`flutter_animate` is **no longer used anywhere** — see §4.6.

### 2.2 Persistence

Hive boxes store **JSON strings**, not TypeAdapters, so one serialisation path is
shared with Firestore. `JsonBox<T>` (`core/storage/json_box.dart`) is the generic
CRUD wrapper. Every model implements `fromJson` / `toJson` / `fromFirestore` /
`toFirestore`. `JsonX` (`core/utils/json_x.dart`) does tolerant coercion.

### 2.3 State management — load-bearing rules

**All list providers are synchronous `Notifier<List<T>>`, not `StreamProvider`.**
They seed from the repository in `build()` and mutate `state` directly on write.

```dart
class XNotifier extends Notifier<List<X>> {
  @override
  List<X> build() {
    final repo = ref.watch(xRepositoryProvider);
    if (ref.watch(isRemoteBackendProvider)) {      // streams ONLY when remote
      bindStream<List<X>>(ref: ref, stream: repo.watchX(id),
                          assign: (items) => state = _sorted(items));
    }
    return _sorted(repo.getX(id));                 // synchronous seed
  }
}
```

- **Never** reintroduce `.listen((x) => state = x)` inside `build()` on the local
  backend. Two writers to one state caused a `_performBuild was called twice`
  assertion. `bindStream` (`core/providers/deferred_state.dart`) defers every
  emission to a microtask.
- **Never** perform side effects inside a provider `build()`.
  `reminderSignatureProvider` is a pure `Object.hash` fingerprint; `VehicleCareApp`
  reacts via `ref.listen`.
- Prefer `notifier.reload()` over `ref.invalidate()` during a cascade.
- Every controller is an `AsyncNotifier<void>` whose methods **return
  `Future<bool>`** via a private `_run` helper. Form sheets branch on that bool.
  Do not revert to `void`.

---

## 3. The two things most likely to trip you up

### 3.1 ProviderScope and the root navigator

`main.dart` renders a splash **before** the `ProviderScope` can exist, because
`preferencesStoreProvider` is overridden with a real `PreferencesStore` instance.

```
AppBootstrapGate
├── splash branch → _SplashApp (its own MaterialApp)
└── app branch   → ProviderScope → VehicleCareApp → MaterialApp.router
```

**Each branch owns its own `MaterialApp`, deliberately.** An outer `MaterialApp`
wrapping both would own the outermost `Navigator`; every sheet and dialog opens
with `useRootNavigator: true`, so they would mount *above* the `ProviderScope` and
throw `Bad state: No ProviderScope found`. Do not hoist a shared `MaterialApp`.

**Every modal must go through the two helpers in `core/widgets/app_sheet.dart`:**

```dart
showAppSheet(context: context, builder: (_) => const SomeSheet());
showAppDialog<bool>(context: context, builder: (_) => AlertDialog(...));
```

Both capture `ProviderScope.containerOf(context, listen: false)` and re-expose it
via `UncontrolledProviderScope`. **Do not call `showModalBottomSheet` or
`showDialog` directly** — a grep for either outside `app_sheet.dart` currently
returns nothing, and it must stay that way.

### 3.2 There are two distances, and they are not interchangeable

| Field | Definition | Used for |
|---|---|---|
| `VehicleMetrics.trackedDistanceKm` | `currentOdometer − initialOdometer` | Total **cost of ownership** per km (includes services/expenses logged outside a fuel entry) |
| `VehicleMetrics.fuelDistanceKm` | first fill → current odometer (`FuelStats.liveDistanceKm`) | **All fuel figures**: L/100 km, km/L, fuel cost per km, octane comparison |

Consumption cannot claim kilometres driven on fuel the app has no record of. If
you unify these you will silently understate consumption for any used car added
mid-life. This distinction was arrived at after several wrong turns — do not
"simplify" it away.

---

## 4. What was changed, and why

### 4.1 Fuel engine — accumulative, odometer-aware

`lib/features/fuel/domain/`

- **`fuel_math.dart` is the single source of truth for every fuel and cost
  formula.** Nothing else divides litres, money or kilometres by hand.
  ```
  liters         = totalCost / pricePerLiter
  pricePerLiter  = totalCost / liters
  costPerKm      = totalCost / distanceKm
  litersPer100Km = (liters / distanceKm) * 100     ← primary metric
  kmPerLiter     = distanceKm / liters             ← secondary
  ```
  All route through `FuelMath.safeDivide`, which returns `0.0` for a non-positive
  denominator or a non-finite result. No caller needs its own guard, and no
  formula can produce `NaN` or `Infinity`.
- **Partial fills are first-class.** The full-tank precondition is gone. Every
  fill, partial or full, is a data point. Fills covering no distance roll their
  litres and cost forward into the next interval rather than being discarded.
- **Headline figures are accumulative over the whole history**, never the latest
  fill or one tank: `FuelStats.liveDistanceKm`, `liveLitersPer100Km`,
  `liveCostPerKm`.
- `CalculateFuelStats(logs, {currentOdometer})` — the live odometer widens the
  span, so consumption and cost/km settle downward as the car is driven with no
  new fuel entry.
- `OpenTank` models the stretch since the newest fill for the "current tank" card.
- **Octane comparison** (`FuelStats.byFuelType`) takes litres and spend from the
  *complete* log history and distance from closed segments plus the open stretch.

### 4.2 Unified metrics — one source, one answer

`lib/features/analytics/domain/entities/vehicle_metrics.dart` +
`presentation/providers/vehicle_metrics_provider.dart`

`vehicleMetricsProvider` is what **Home, the Fuel tab, the Analytics grid, the
efficiency chart and the exported report all read**. None of them recompute
anything, so a number cannot say 12.68 on one screen and 11.20 on the next. It
composes `fuelStatsProvider` and `totalCostProvider` and exposes
`litersPer100Km`, `kmPerLiter`, `fuelCostPerKm`, `totalCostPerKm`,
`byFuelType`, `initialOdometer`, `currentOdometer`.

**If you add a screen that shows a fuel or cost figure, read it from here.**

Cost of ownership has four disjoint streams — fuel, service, **parts**, other.
`partsSpendProvider` counts only `PartReplacement`s with
`maintenanceRecordId == null`; parts fitted during a service are already priced
into that service record.

### 4.3 Notifications

`lib/features/dashboard/presentation/providers/reminder_scheduler.dart`

| Category | Trigger | Repeat |
|---|---|---|
| Licence & insurance | 30 / 7 / 1 days before expiry | once each |
| Service & wear parts — by date | from 14 days before projected date | **daily** |
| Service & wear parts — by distance | remaining ≤ **1,000 km** | **every 2 days** |

- Distance **beats** date: within 1,000 km an item schedules only the 2-day
  distance run. Measured distance is real; the projected date is a guess.
- "Until completed" is bounded, not infinite. `flutter_local_notifications`
  schedules discrete instants, so the daily run arms 15 occurrences ahead and the
  2-day run 7. Every reschedule re-arms from today.
- Completion stops it naturally: a completed service leaves
  `upcomingServicesProvider`, a reset part drops to `healthy`, and the next pass
  does not re-arm.
- **`pendingBudget = 60`.** iOS caps an app at 64 pending local notifications and
  silently drops the overflow. A naive "daily until done" across 3 services and
  17 wear parts arms 300+. Plans are ranked most-urgent-first and armed within
  budget, with 6 slots reserved for documents. **Do not remove this budget.**
- `reminderSignatureProvider` hashes each item's remaining distance in 100 km
  buckets, which is what makes a new odometer reading re-arm the distance
  triggers immediately.

### 4.4 Splash & bootstrap

`lib/core/bootstrap/app_bootstrap.dart` · `lib/core/widgets/app_splash.dart`

- `main()` awaits exactly one thing: `PreferencesStore.restoreAppearance()`, a
  cached `SharedPreferences` read for locale + theme. Without it the splash
  rendered in a hardcoded Arabic and flipped on handover.
- `PreferencesStore.resolveLocale` / `resolveThemeMode` are the single resolution
  point, used by both the splash and the providers, so they cannot drift.
- Everything heavier (Hive, seed data, backend, notifications) runs inside
  `AppBootstrapGate` behind the branded splash, each step individually guarded —
  a missing notification permission is a normal state, not a reason to hang.
- `AppBootstrapGate.timeout` (20 s) bounds the whole bootstrap so a dead platform
  channel cannot spin the splash for ever.
- **Layout contract:** branding is a `Center` directly in the root `Stack`; the
  loading indicator is a separate `Positioned` at the bottom. Adding it to the
  branding column shifts the logo off centre.
- Native launch backgrounds (`android/.../drawable{,-v21}/launch_background.xml`,
  `values{,-night}/colors.xml`, iOS `LaunchScreen.storyboard`) mirror
  `AppSplash.lightStops` / `darkStops`. **`NormalTheme`** also points at
  `@color/splash_mid` — it was the real white-flash source, not `LaunchTheme`.
  Keep all of these in step if the gradient changes.

### 4.5 UI system

- **`GlassCard`** — backdrop blur, layered accent gradient, press micro-interaction.
  Animated decorations vary **alpha only**; geometry is constant (lerping a shadow
  under an overshoot curve produced a negative `blurRadius` and a `dart:ui`
  assertion). Every card is wrapped in a `RepaintBoundary`. **List rows pass
  `blur: false`** — each blurred card costs a `saveLayer` and a framebuffer read.
- **`Contrast`** (`core/theme/contrast.dart`) — `inkOn(surface)` picks ink by WCAG
  contrast **ratio**, not a luminance threshold. Silver sits at luminance 0.4999,
  so a `> 0.5` test handed it white ink on a near-white disc. Used by
  `VehiclePaint.onColor` and `AppActionButton`.
- **`AppActionButton`** (`core/widgets/app_action_button.dart`) — enabled is
  saturated, elevated and outlined; disabled is flat, muted and shadowless. The
  two states are never a matter of degree. Used by "Update odometer".
- **`GuidanceCard`** (`core/widgets/guidance_card.dart`) — categorised advice
  matching the Roadside Tips architecture exactly. The **card** collapses; the
  **steps inside do not**. Each step shows title and body at once — an emergency
  instruction you have to tap to read is one you will not read. Backs the eco
  tips, fuel emergency and fuel guidelines cards.
- **`EntranceAnimation`** (`core/widgets/entrance_animation.dart`) — see §4.6.
- **`context.screenPadding()` / `splitScreenPadding()`**
  (`core/utils/screen_insets.dart`) — the single bottom-gutter rule.
  `ScrollGutter.bare = 24`, `fab = 80`. The shell injects the floating nav bar's
  height into `MediaQuery.padding.bottom`, so this is correct inside the shell
  *and* on root-navigator modals. **Never hand-roll a bottom padding.**
- All modals use `useRootNavigator: true` via the helpers in §3.1.
- Sheet titles and submit labels are context-driven: `Edit …` + `Save changes`
  when editing, `Add …` + `Save` when creating.

### 4.6 Animation & scroll performance

`flutter_animate`'s `.animate()` rebuilds its effect chain on every widget
rebuild, so rows re-faded every time a list moved. It has been removed from the
codebase and replaced by **`EntranceAnimation`**:

- `AnimationController.forward()` runs **once**, from `initState`, behind a
  `_hasAnimated` guard. `didUpdateWidget` deliberately does nothing.
- `AutomaticKeepAliveClientMixin` with `wantKeepAlive => true`, so a lazy sliver
  cannot dispose and replay the row on re-entry.
- Once settled, `build` returns the child with **no wrapper at all** — a resting
  list costs nothing per frame.
- List items use `EntranceAnimation.item(key: ValueKey('<type>-<id>'), …)` so the
  "already played" state travels with the row, not the slot.

Fuel, expenses and maintenance history are `CustomScrollView` with a header
`SliverList.list` and a lazy `SliverList.builder`, using `indexOfChildKey` as
`findChildIndexCallback`.

### 4.7 Other completed work

- **Fuel form**: cost / price / litres are one bidirectional triangle
  (`DeriveFuelAmounts`), guarded by a re-entrancy latch **and** FocusNodes so a
  value is never yanked out from under the caret.
- **Vehicle form**: two distinct odometer fields (initial + current) with
  cross-validation, both editable on edit. Previously `initialOdometer` was
  unreachable after creation, which made tracked distance permanently 0.
- **Odometer labels** were swapped in l10n (`initialOdometer` read "Current
  odometer"). Fixed; `vehicleCurrentOdometer` added for the vehicle's own reading
  so the generic `currentOdometer` ("Odometer") still serves fuel/service/expense
  entry forms.
- **Colour picker**: default is `VehiclePaint.defaultPaint` (=
  `values.first` = black); checkmark ink via `Contrast`.
- **Service log**: inline consumable-parts expansion removed; a
  "View replaced parts (n)" button opens `ServicePartsDialog`. The parts-health
  card was also removed from the maintenance screen (it lives on Home) and
  replaced with a summary button opening `AllPartsSheet`.
- **Analytics export**: PDF added alongside CSV/JSON.
  `lib/features/analytics/data/pdf_report_builder.dart` draws **vector** charts
  via the `pdf` package — no `RepaintBoundary`, no `BuildContext`, pure and
  off-thread.
- **Public storage**: `core/platform/file_saver_io.dart` writes to public
  Downloads (Android `/storage/emulated/0/Download` → external Downloads →
  external app dir → documents; desktop `getDownloadsDirectory()`), probing each
  candidate for writability. It previously wrote to `Directory.systemTemp`.
- **Navigation**: Settings is a real `GoRoute` (`/settings`) under the dashboard
  branch. It was pushed imperatively, which made the Home tab appear dead —
  `goBranch` cannot pop a route the router has no record of. `_go` also pops the
  target branch navigator and always passes `initialLocation: true`.
- **Terminology**: `cloudUnavailable` / `sourceCloudHint` no longer name
  Firebase or Firestore. The bootstrap failure screen logs the raw error and
  shows `somethingWentWrong`. **Never surface an infrastructure name or a raw
  exception to the user.**
- **Workshops screen**: emergency/towing section removed (it lives on its own tab).

---

## 5. Code standards you must follow

1. **Riverpod only.** `ConsumerWidget` / `ConsumerStatefulWidget`, `ref.watch` in
   build, `ref.read` in callbacks. No `setState` for anything a provider owns.
   No codegen.
2. **No hardcoded user-facing text.** Add a key to **both**
   `lib/core/localization/strings_en.dart` and `strings_ar.dart`, then read it
   with `context.l10n.raw('key')` or a named getter in `app_localizations.dart`.
   Arabic must be translated, not transliterated.
3. **Directional layout everywhere.** `EdgeInsetsDirectional`,
   `PositionedDirectional`, `AlignmentDirectional`.
4. **Explicit alignment.** State `mainAxisAlignment` / `crossAxisAlignment`
   rather than relying on defaults. `FittedBox` shrink-wraps, so pin it with
   `Align(alignment: AlignmentDirectional.centerStart)` when it must sit on the
   leading edge.
5. **Guard every division.** Use `FuelMath` for anything involving litres, money
   or kilometres. Return `0.0`, never `NaN`/`Infinity`, and format with
   `Fmt.dec2` — `0.00` is a legitimate empty state; a dash reads as a failure.
6. **High contrast.** Use `Contrast.inkOn` rather than picking ink by hand.
7. **Theme accessors:** `context.colors`, `context.text`, `context.tokens`,
   `context.isDark`, `context.l10n`.
8. **Comments explain *why*, not *what*.** Match the existing density — the
   codebase documents the reasoning behind non-obvious decisions and the bugs
   that motivated them.
9. `flutter analyze` must stay at **0 issues**, and run `dart format lib/`.

---

## 6. Known state & next steps

### Blocking

1. **No successful build has ever happened.** Gradle's loopback failure is
   environmental (firewall/AV blocking Java sockets). Resolve this first —
   nothing in this app is runtime-verified, and the PDF layout, the native splash
   alignment and the notification scheduling in particular deserve a real device.

### Stale / needs attention

2. **`test/` is stale.** `fuel_stats_test.dart`, `maintenance_engine_test.dart`,
   `models_and_expenses_test.dart` compile but assert against the superseded
   full-tank fuel contract and older field names. Rewrite against `FuelMath`,
   `CalculateFuelStats` and `VehicleMetrics`, or delete them.
3. **`FirestoreExpenseRepository` is missing.** Vehicles, fuel and maintenance
   have Firestore repos; expenses do not, so on the Cloud toggle expenses stay
   device-local and Total Spend mixes synced and unsynced sources.
4. **Firebase is unconfigured.** `FirebaseBootstrap.tryInitialize()` catches
   failure and stays local. Cloud mode needs `flutterfire configure`, and on
   **web and iOS** you must pass `options: DefaultFirebaseOptions.currentPlatform`
   explicitly.
5. **Android public Downloads is best-effort.** Writing to
   `/storage/emulated/0/Download` is not guaranteed under scoped storage without
   `MANAGE_EXTERNAL_STORAGE`. The fallback chain always lands somewhere visible,
   but a MediaStore platform channel is the only way to guarantee the top-level
   folder.
6. **`/add-fuel` and `/dealer-details/:id`** are wired and URL-addressable but
   nothing navigates to them.
7. **No Vehicle Profile screen.** `VehicleImageHeader` was built for it and is
   unused.
8. **Price-book UI.** `priceBookProvider` and `serviceEstimateProvider` exist;
   no settings screen exposes the multiplier or per-part overrides.
9. **Pre-existing duplicate service records** are de-duped at read time by
   `DistinctServiceRecords` but both still appear in the Service Log list. A
   one-time merge migration is optional.
10. **`AnalyticsSummary.costPerKm` is range-scoped** by design and therefore
    differs from the lifetime figure on Home. This is intentional; do not
    "fix" it without deciding what the analytics denominator should mean.

---

## 7. Your instructions

1. Read the codebase before proposing changes. The patterns above are load-bearing
   and several encode bugs that were expensive to find.
2. Preserve the Riverpod conventions in §2.3 and the `ProviderScope` propagation
   in §3.1 exactly.
3. Read every fuel or cost figure from `vehicleMetricsProvider`; compute every
   fuel or cost formula through `FuelMath`. Never introduce a second source.
4. Keep the two distances in §3.2 distinct.
5. Add localisation keys in both locales for any new user-facing string.
6. After each change: `dart format lib/` then `flutter analyze` (must be 0).
7. When you find a real problem with a request, say so in a sentence and then
   deliver the work under a stated assumption — do not silently narrow the scope.
