# Vehicle Care — Handover & Context Briefing

**Repo:** `E:\FlutterProjects\CarMaintenance` · **Package:** `vehicle_care`
**Flutter 3.41.6 / Dart 3.11.4** · 135 Dart files under `lib/`
**Status:** `flutter analyze` → **0 issues**. Never compiled or run — see §6.

---

## 0. Non-negotiable context for the next session

| Fact | Implication |
|---|---|
| **No build has ever succeeded.** Gradle fails with `java.io.IOException: Unable to establish loopback connection` on this machine. | Every claim below is verified by the analyzer + source reading only. **Do not assert runtime correctness.** |
| `flutter test` works **only** via the PowerShell tool, not Bash (Bash returns exit 137). | Use `PowerShell` tool with `Set-Location E:\FlutterProjects\CarMaintenance; flutter test ...`. |
| Bash heredocs mangle `$` and apostrophes. | Write Python patch scripts to `/tmp/x.py`, run `py /tmp/x.py`. Always `assert old in s` before replacing — several silent no-op replacements have already happened this way. |
| Arabic is the **default locale**; RTL is the primary layout. | Use `EdgeInsetsDirectional`, `PositionedDirectional`, `AlignmentDirectional` everywhere. |
| Numbers render in **Latin digits even in Arabic** (`Fmt._digits()` pins numeric patterns to `en`). | Never wrap a mixed Arabic+digit string in `AppTypography.numeric` — RobotoMono has no Arabic glyphs and the baseline breaks mid-string. This has already caused one visual bug. |

---

## 1. Architecture

Clean Architecture per feature: `domain/{entities,repositories,usecases}` → `data/{models,datasources,repositories}` → `presentation/{providers,screens,widgets}`.

### 1.1 Stack

`flutter_riverpod ^2.6.1` (hand-written Notifiers, **no codegen anywhere** — no `.g.dart`, no `build_runner`, no `riverpod_annotation`) · `go_router ^14.6.2` · `hive_ce` + `hive_ce_flutter` · `shared_preferences` · `cloud_firestore` + `firebase_core` · `fl_chart ^0.69.2` · `flutter_animate` · `google_fonts` · `image_picker` · `url_launcher` · `flutter_local_notifications` · `web ^1.1.0`

### 1.2 Persistence

Hive boxes store **JSON strings**, not TypeAdapters — one serialisation path shared with Firestore.

```
box_vehicles · box_fuel_logs · box_maintenance
box_part_replacements · box_expenses · box_dealers · box_meta
```

`JsonBox<T>` (`core/storage/json_box.dart`) is the generic CRUD wrapper: `readAll/readById/put/putAll/delete/clear/watchAll`.
Every model implements `fromJson` / `toJson` / `fromFirestore` / `toFirestore`. `JsonX` (`core/utils/json_x.dart`) does tolerant coercion (`intOr`, `doubleOrNull`, `enumByName`, Firestore `Timestamp` unwrap without importing `cloud_firestore`).

### 1.3 State management — the load-bearing rules

**All list providers are synchronous `Notifier<List<T>>`, not `StreamProvider`.** They seed from the repository in `build()` and mutate `state` directly on write, so a save is reflected in the UI on the next frame.

```dart
class XNotifier extends Notifier<List<X>> {
  @override
  List<X> build() {
    final repo = ref.watch(xRepositoryProvider);
    if (ref.watch(isRemoteBackendProvider)) {      // ← streams ONLY when remote
      bindStream<List<X>>(ref: ref, stream: repo.watchX(id),
                          assign: (items) => state = _sorted(items));
    }
    return _sorted(repo.getX(id));                 // synchronous seed
  }
  Future<void> upsert(X v) async { await repo.upsert(v); state = _sorted([...]); }
}
```

> **Do not reintroduce `.listen((x) => state = x)` inside `build()` on the local backend.** Two writers to one state caused a `_performBuild was called twice` assertion. `bindStream` (`core/providers/deferred_state.dart`) defers every emission to a microtask; streams are gated behind `isRemoteBackendProvider`.

> **Never perform side effects inside a provider `build()`.** `reminderSyncProvider` used to call `scheduleSoon()` in its body; it is now the pure `reminderSignatureProvider` (an `Object.hash` fingerprint) and `VehicleCareApp` reacts via `ref.listen`.

> **Prefer `notifier.reload()` over `ref.invalidate()`** during a notification cascade. `MaintenanceRecordsNotifier.upsert` calls `partReplacementsProvider.notifier.reload()`.

### 1.4 Provider map (~80 total)

| Layer | Providers |
|---|---|
| **Core** | `preferencesStoreProvider` (overridden in `ProviderScope`), `uuidProvider`, `themeModeProvider`, `localeProvider`, `l10nProvider`, `localeTagProvider`, `notificationsEnabledProvider`, `notificationServiceProvider` → `ReminderNotifier`, `launcherServiceProvider` → `LinkLauncher` |
| **Backend** | `backendModeProvider` (`local` \| `firestore`), `isRemoteBackendProvider`, `workspaceIdProvider`, `firestorePathsProvider` |
| **Platform** | `fileSaverProvider`, `linkLauncherProvider`, `imagePickerServiceProvider` |
| **Vehicles** | `vehicleRepositoryProvider` (switches Hive↔Firestore), `vehiclesProvider`, `selectedVehicleIdProvider`, **`selectedVehicleProvider`**, `selectedVehicleIdOrFirstProvider`, `vehicleControllerProvider` |
| **Fuel** | `fuelRepositoryProvider`, `fuelLogsProvider`, `fuelStatsProvider`, `avgDailyKmProvider`, `fuelControllerProvider` |
| **Maintenance** | `maintenanceRepositoryProvider`, `maintenanceRecordsProvider`, `partReplacementsProvider`, `partsHealthProvider`, `allPartsHealthProvider`, `serviceRoadmapProvider`, `nextServiceDueProvider`, `lastServiceProvider`, `upcomingServicesProvider`, `dailyPaceProvider`, `monthlyPaceProvider`, `billableServiceRecordsProvider`, `serviceSpendProvider`, `maintenanceControllerProvider`, **`partSettingsControllerProvider`**, `priceBookProvider`, `serviceEstimateProvider` |
| **Expenses** | `expensesProvider`, `expenseSummaryProvider`, `expenseFilterProvider`, `filteredExpensesProvider`, `totalCostProvider`, `overallCostPerKmProvider`, `expenseControllerProvider` |
| **Dealers** | `dealersProvider`, `dealerQueryProvider`, `dealerKindFilterProvider`, `filteredDealersProvider`, `dealerCitiesProvider`, `dealerControllerProvider` |
| **Dashboard** | `dashboardAlertsProvider`, `hasCriticalAlertsProvider`, `reminderSignatureProvider`, `reminderSchedulerProvider` |
| **Analytics** | `analyticsRangeProvider`, `analyticsCustomSpanProvider`, `analyticsSpanProvider`, `analyticsFuelLogsProvider`, `analyticsFuelStatsProvider`, `analyticsExpensesProvider`, `analyticsServicesProvider`, `analyticsSummaryProvider`, `fuelEfficiencyTrendProvider`, `costPerKmTrendProvider`, `odometerTrendProvider`, `monthlySpendTrendProvider`, `expenseDonutProvider`, `analyticsCategorySharesProvider`, `fuelTypeBreakdownProvider`, `analyticsHasDataProvider`, `analyticsReportProvider`, `reportExporterProvider`, `exportControllerProvider` |

**Reactive spine — memorise this:**
```
vehiclesProvider → selectedVehicleProvider → { partsHealthProvider,
                                               nextServiceDueProvider,
                                               serviceRoadmapProvider,
                                               dashboardAlertsProvider }
```
Any odometer/vehicle write propagates through it automatically.

### 1.5 Controller convention

Every controller is `AsyncNotifier<void>` whose methods **return `Future<bool>`** (`!state.hasError`) via a private `_run` helper. All five form sheets check that bool and show an error snack instead of closing on failure. Do not revert to `void` — the "Saved" toast used to fire even when nothing was written.

### 1.6 Domain entities

**`Vehicle`** — `id, make, model, year, initialOdometer, currentOdometer, createdAt, nickname?, plateNumber?, purchaseDate?, licenseExpiry?, insuranceExpiry?, tankCapacityLiters?, colorValue?, imageBase64?, imageUrl?, partLifespanOverridesKm, partSettings, odometerUpdatedAt?`
Helpers: `displayName`, `subtitle`, `trackedDistanceKm`, `hasImage`, **`settingFor(partId)`** (merges legacy `partLifespanOverridesKm` into `PartSetting.intervalKm`).
`copyWith` has explicit `clearLicenseExpiry` / `clearInsuranceExpiry` / `clearImage` flags — null-coalescing alone cannot erase a field.

**`ConsumablePart`** (enum, 17 members) — `l10nKey, defaultLifespanKm, defaultLifespanMonths, colorValue, iconKey`; `id == name`.

| Part | km | months |
|---|---|---|
| engineOil, oilFilter, drainPlugGasket | 10 000 | 12 |
| airFilter, cabinFilter, fuelFilter | 20 000 | 24 |
| brakePads | 30 000 | 36 |
| brakeFluid, coolant | 40 000 | 24 |
| sparkPlugs, powerSteeringFluid | 40 000 | 48 |
| tires | 50 000 | 48 |
| transmissionOil, transmissionFilter | 60 000 | 60 |
| battery | 60 000 | 36 |
| timingBelt, driveBelt | 100 000 | 120 |

`dashboardOrder` = tires, brakePads, engineOil, transmissionOil, powerSteeringFluid, coolant.

**`PartSetting`** — `intervalKm?, lastReplacedOdometer?, lastReplacedDate?, customWear?`. Per-vehicle, per-part, keyed by `ConsumablePart.id` in `Vehicle.partSettings`.

**`MaintenanceRecord`** (this is "ServiceLog") — `id, vehicleId, date, odometer, title, tier, replacedParts, inspectedKeys, customItems, cost, workshopName?, notes?, milestoneOdometer?`. `milestoneOdometer` is the **phase identity** used for de-duplication and completion.

**`ServiceMilestone`** — `targetOdometer, tier, replaceParts, conditionalParts, inspectKeys, recommendedMonths, isComplimentary`. **Pure Dart, never serialised, no `fromJson`, no `copyWith`.** Always produced by `ServiceCatalog`.

**`ServiceTier`** — `firstCheck` (indigo) · `minor` (green) · `important` (amber) · `major` (cyan).

**`UpcomingService`** — milestone positioned against a vehicle: `kmRemaining, isCompleted, estimatedDate?, completedRecord?` + derived `completedDate`, `completedOdometer`, `completedCost`, `isOverdue`, `isDueSoon`.

**`NextServiceDue`** — `milestone, targetOdometer, kmRemaining, dailyPace, targetDate?, dueDriver (distance|time), lastService?, monthsSinceLastService?`.

---

## 2. Consumable Parts Wear Engine

`domain/usecases/calculate_parts_health.dart` → `List<PartHealth>`.

### 2.1 Baseline resolution — priority chain

Each part resolves **independently**. Highest wins:

| # | Source | Trigger |
|---|---|---|
| 1 | `PartBaselineSource.customWear` | `PartSetting.customWear` pinned. Baseline back-derived: `current − intervalKm × customWear`. |
| 2 | `PartBaselineSource.manual` | `PartSetting.lastReplacedOdometer` set by the user. |
| 3 | `PartBaselineSource.logged` | Newest `PartReplacement` for that part (by odometer). |
| 4 | `PartBaselineSource.assumed` | `initialOdometer − (initialOdometer % intervalKm)`. |

### 2.2 Core math

```
distanceDriven = clamp(currentOdometer − lastReplacedOdometer, 0, ∞)
distanceWear   = distanceDriven / intervalKm
timeWear       = clamp(monthsElapsed / intervalMonths, 0, 1)
rawWear        = customWear ?? max(distanceWear, timeWear)     // "whichever comes first"
wearFraction   = clamp(rawWear, 0, 1)                          // progress bars
remainingKm    = max(intervalKm − distanceDriven, 0)
overrunKm      = max(distanceDriven − intervalKm, 0)
```

`rawWearFraction` is **deliberately uncapped** so 112% surfaces as an over-limit warning; `wearFraction` is the clamped version widgets bind to. `wearPercentage` + `remainingPercentage` are always consistent (`wear + remaining == 100`) — they were not before, and that was a real bug.

### 2.3 The four edge cases

- **CASE 1 — used car added at 45 000 km.** Assumed baseline = nearest interval boundary below. Engine oil → 40 000 (50% worn), tyres → 0 (90% worn), timing belt → 0 (45%). Never 0% and never an instant 100%.
  **Calendar baseline is anchored to `createdAt`, NOT `purchaseDate`** — back-dated by `intervalMonths × (initialOdometer % intervalKm) / intervalKm`. Anchoring to a 2018 purchase date made `timeWear = 7.5` → clamped to 1.0 → every short-life part critical on day one. Do not revert this.
- **CASE 2 — single-part adjustment.** `PartSettingsController`: `setLastReplacedOdometer`, `setDistanceDriven` (km-on-part → baseline), `setInterval`, `setCustomWear`, `reset`. Writes to `Vehicle.partSettings` via `vehiclesProvider.notifier.upsert`, so it flows down the reactive spine.
- **CASE 3 — service log auto-reset.** `MaintenanceRepository.saveService` deletes stale `PartReplacement`s for that record id and re-derives one per `replacedParts` entry at the log's odometer. Editing a service that drops a part therefore removes its reset — no orphans.
- **CASE 4 — odometer update.** `VehiclesNotifier.updateOdometer` reads current **through the repository, not `state`**, rejects non-forward readings, and writes `odometerUpdatedAt`.

### 2.4 Status bands

`HealthStatus.fromWear(rawWear)` — `healthy ≤ 0.60` · `warning ≤ 0.85` · `critical` (`maxWear: infinity`, so >100% lands here).
`AppColors.health(remaining)` — green ≥ 0.40 · amber ≥ 0.15 · red below. `AppColors.wear(worn)` is the inverse.

### 2.5 Related engines

- **`ServiceCatalog`** — harmonic roadmap, brand-agnostic. `1 000 km` = free `firstCheck` (`isComplimentary: true`, oil/filter **optional only**). Then every 10k: oil + oil filter + drain plug gasket + cleaner supplies. `%20 000` adds fuel filter, air filter, spark plugs. `%40 000` adds power steering, brake fluid, coolant. `%60 000` adds transmission oil + filter. `%100 000` adds timing belt + drive belt. Horizon 120 000 km. *Known deviation: 60k also receives the fuel filter because 60 000 is a multiple of 20 000 — the spec listed it without one.*
- **`PredictServices`** — `nextDue()` anchors on the **last performed service**, resolves the next un-closed milestone, and returns whichever comes first: distance (`kmRemaining / dailyPace`) or time (last service + 6 months). `dailyPace` prefers fuel-measured `avgDailyKm`, falls back to the odometer trail, returns 0 rather than inventing a date.
- **`DistinctServiceRecords`** — collapses history to one record per `milestoneOdometer` (newest date, ties by odometer). Ad-hoc records (`milestoneOdometer == null`) are **never** collapsed. Feeds `serviceSpendProvider` → `totalCostProvider`.
- **`CalculateFuelStats`** — full-to-full method; a partial fill extends the segment rather than breaking it; average weighted by distance, not a mean of ratios.
- **`ServicePriceBook`** — `BasePriceIndex` × clamped `multiplier` (0.25–5.0) + per-key `overrides`, returns `low/midpoint/high` via `spread` (default ±15%). Persisted as JSON in prefs.

---

## 3. UI status

### 3.1 Navigation

`StatefulShellRoute.indexedStack`, 6 branches: `/` · `/maintenance` · `/fuel` · `/expenses` · `/workshops` · `/emergency`. Nested: `/analytics`, `/maintenance/schedule`. Root-navigator modals: `/add-fuel`, `/dealer-details/:id`, `/export-report`.

- **`FloatingNavBar`** — glass bar (`BackdropFilter` σ22), per-tab accent. Indicator is a **content-hugging pill inside each item** (`IntrinsicWidth` + animated padding 12/6), *not* a sliding overlay — a sliding pill cannot measure its target width. Fixed slots `_iconSlot 24 / _iconLabelGap 3 / _labelSlot 13` = identical 40 px column per tab. `Positioned.fill` on the row (a non-positioned `Stack` child defaults to `topStart` and pinned everything to the top — that was the misalignment bug). Bar padding `horizontal: 6` + per-item `3` keeps end pills off the edges.
- **`SideNavRail`** ≥ 900 px, with `VehicleCareLogo`, hover states, content capped at 1040 px.
- **Bottom inset:** the shell wraps `navigationShell` in a `MediaQuery` whose `padding.bottom` **and** `viewPadding.bottom` include `FloatingNavBar.totalHeight(context)`. `StandardFabLocation` reads `minViewPadding.bottom`, so **every FAB lifts clear automatically**. Screens use `24 + MediaQuery.paddingOf(context).bottom` (80 + inset on FAB screens).
- All modals use **`useRootNavigator: true`** — branch-navigator modals rendered *under* the floating bar and swallowed taps.

### 3.2 Cards

- **Total Spend** — headline in `FittedBox(scaleDown)`; `IntrinsicHeight` + `VerticalDivider` with `EdgeInsetsDirectional` 14 on both sides (mini-stats used to sit flush against a bare 1 px `Container`); legend + labels `maxLines: 1` + ellipsis.
- **Next Service Due** — same divider fix; card padding `symmetric(16,16)`; `_NextServicePlaceholder` for the null state; **span guarded** (`rawSpan <= 0 → intervalKm`) because a back-dated service could divide by zero.
- **Documents (Insurance / Licence)** — both states emit an identical structure (icon → title → badge → caption) so heights match by construction under `IntrinsicHeight` + `stretch`; 28 px pill badge with `minWidth: 72`; countdown moved **off** `AppTypography.numeric` (RobotoMono lacks Arabic glyphs → broken baseline).
- **Parts Health** — expandable rows, wear % beside interval, colour by band.
- **Quick Actions** — `SizedBox(height: 118)` + `stretch`, icon badge + `+` affordance, title over subtitle, both `FittedBox`.
- **`GlassCard`** — backdrop blur, layered accent gradient, top hairline, press micro-interaction (scale 0.985). **Animated decorations vary alpha only**; geometry (`borderRadius`, `blurRadius`, `spreadRadius`) is constant — lerping a shadow under an overshoot curve produced a negative `blurRadius` and a `dart:ui` assertion.

### 3.3 Vehicle imagery

`VehicleImageResolver` — one resolution point: `MemoryImage` (base64) → `NetworkImage` (`http(s)://`) → file path via a conditional-import shim (`local_file_image_{stub,io,web}.dart`; web returns null). Widgets: `VehicleAvatar` / `VehicleAvatar.of(vehicle)`, `VehicleImageHeader`, `VehicleImageBackdrop`, all `BoxFit.cover` + `Clip.antiAlias` + `errorBuilder`.
Bound at: hero card (52), switcher rows (42), settings list (40), **app bar (32, opens switcher)**. Remaining `AppIcons.vehicle` uses are empty states / section headers where no vehicle exists — correct as-is.
Capture: `image_picker` at 1280 px / q78, 900 KB cap, stored as `imageBase64`.

### 3.4 Branding

`AppBrandTitle` — `VehicleCareLogo` badge + dual-tone wordmark that **splits `l10n.appTitle` on its first space** (so EN → **Vehicle** + *Care*, AR → **العناية** + *بالسيارة*). `Flexible` + `FittedBox` + ellipsis.
`VehicleCareLogoPainter` — charcoal squircle, cyan-outlined shield, 180° gauge (64% fill, white needle) **above** a car silhouette. Paint order is **badge → shield → gauge → car**; drawing the shield last hid the gauge.
Icons generated: `flutter test tool/generate_app_icon.dart` renders the painter → `assets/icon/*.png`, then `dart run flutter_launcher_icons`. Android mipmaps + adaptive + `colors.xml`, iOS appiconset (22), web icons + favicon.

### 3.5 Theme / l10n

Dark-first, `AppTokens` `ThemeExtension` (`surfaceHigh`, `border`, `textSecondary`, `cardRadius`, `gutter`, `glowOpacity`). Accessors: `context.colors / .text / .tokens / .isDark / .l10n`.
Typography: Cairo, explicit size/height/weight/letter-spacing per tier. `AppTypography.numeric` = RobotoMono — **digits only**.
l10n: hand-rolled maps `strings_ar.dart` / `strings_en.dart`, `AppLocalizations.raw(key)` / `.fmt(key, args)`, named getters for common keys. Missing key → English → the key itself.
Form fields reserve the error line via `helperText: ' '` so a validation message can't shift a side-by-side sibling; all such rows use `CrossAxisAlignment.start`.

---

## 4. Resolved bugs

| # | Bug | Root cause | Fix |
|---|---|---|---|
| 1 | Saves showed "Saved" but lists never updated | Controllers wrote to Hive only; UI depended on `box.watch()` reaching a lazily-resumed `async*` generator | Synchronous in-memory `Notifier` caches, write-through on mutation |
| 2 | "Saved" toast on failed save | Controllers returned `void`, sheets closed unconditionally | Controllers return `Future<bool>`; sheets branch on it |
| 3 | Wrong dealer data (6 invented branches) | Fabricated seed data | Exactly 4 verified entries; `syncSeedData()` purges non-user seeds not in the current set, preserving ratings |
| 4 | Odometer chart axis assertion | `minY = values.first`, `maxY = values.last` assumed monotonic | `reduce` min/max |
| 5 | Donut sections painted outside their box | `centerSpace 0.28 + radius 0.26 > 0.50` | `0.24 + 0.24` |
| 6 | `Text shadow blur radius should be non-negative` | `BoxShadow.lerp` under `easeOutBack` (t > 1) drove `blurRadius` negative; `Icon` shadows go through the *text* shadow encoder | Constant `blurRadius`, animate alpha only; `easeOutCubic` on that container |
| 7 | Parts at 100% health on a used car | Baseline was `initialOdometer` | Nearest interval boundary below |
| 8 | **Every part critical the moment an older car was added** | Calendar baseline anchored to `purchaseDate` → `timeWear ≫ 1` | Anchor to `createdAt`, back-dated by the odometer-implied fraction; `timeWear` clamped at source |
| 9 | `wear + remaining ≠ 100%` | `wearFraction` distance-only, `fractionRemaining` used `min(time, distance)` | Single authoritative `rawWearFraction`; everything derived |
| 10 | Nav icons/labels off-centre | Item `Row` was a non-positioned `Stack` child (`topStart`); `FittedBox` + animated `fontSize` gave each tab a different height | `Positioned.fill`; fixed slots; constant font size |
| 11 | Floating bar covered sheets/dialogs and blocked taps | Modals pushed on the **branch** navigator, inside the shell body under `extendBody` | `useRootNavigator: true` everywhere; snackbar bottom margin |
| 12 | FABs hidden behind the bar | Inner scaffolds had no bottom inset | Shell injects `padding`/`viewPadding` bottom |
| 13 | Gauge invisible in the app icon | `_paintShield` ran **after** `_paintGauge` | Reordered; gauge moved inside the shield |
| 14 | Duplicate milestone logs double-counted spend | `logService` always minted a new `uuid.v4()` | `findByMilestone` → reuse existing id (upsert); `DistinctServiceRecords` de-dupes reads |
| 15 | `_performBuild was called twice` **(see §6)** | Multiple: stream `.listen` writing state in `build()`; `ref.invalidate` mid-cascade; `reminderSyncProvider` side effect in build | `bindStream` + remote-only gating; `reload()`; pure `reminderSignatureProvider` + `ref.listen`. **Reported still reproducing.** |
| 16 | Insurance/Licence cards misaligned | Differing child counts → unequal heights; `Row` centred the shorter one; mono font on mixed AR+digit string | Identical structure both states; `IntrinsicHeight` + `stretch`; theme font |
| 17 | Excess whitespace, oversized emergency tiles | `AppEmptyState` `vertical: 40` + a `vertical: 36` wrapper; `childAspectRatio` scaled tile height with viewport width | Compact empty state + `dense`; `SliverGridDelegateWithMaxCrossAxisExtent(mainAxisExtent: 68)` |
| 18 | Emergency tab content under the nav bar | `const EdgeInsets` can't read `MediaQuery` | Composed padding |
| 19 | Save button colour drifted per entity | Used the sheet accent | Always `colorScheme.primary`; explicit disabled colours |
| 20 | Historical fuel logs rejected | Validator enforced `>= currentOdometer` | Relaxed; baseline rule kept **only** in `OdometerSheet` |

---

## 5. Immediate next steps

**P0 — blocking**
1. **Get a successful build.** Gradle's loopback failure is environmental (firewall/AV blocking Java sockets). Nothing has been runtime-verified.
2. **`_performBuild was called twice` still reproduces on odometer update.** Three plausible causes were fixed; the culprit is unconfirmed. **Get the full stack trace** — the frames *below* `_performBuild` name the offending provider — or add a `ProviderObserver` logging `didUpdateProvider` and take the last entry before the crash.
3. **Firebase config.** `cloud_firestore` is a hard dependency. `FirebaseBootstrap.tryInitialize()` catches failure and stays local, so the app runs unconfigured, but the Cloud toggle needs `flutterfire configure`. On **web and iOS** you must pass `options: DefaultFirebaseOptions.currentPlatform` explicitly in `main.dart`.

**P1 — known gaps**
4. **`FirestoreExpenseRepository` missing.** Only vehicles/fuel/maintenance have Firestore repos. On the Cloud toggle expenses stay device-local and Total Spend mixes synced and unsynced sources.
5. **No UI for `PartSettingsController`.** The controller is complete and reachable from code; there is no sheet to edit a part's baseline, interval, or pinned wear.
6. **`/add-fuel` and `/dealer-details/:id` are unreachable** — wired and URL-addressable, but nothing navigates to them.
7. **No Vehicle Profile/Details screen.** `VehicleImageHeader` was built for it and is currently unused.
8. **`ExportReportScreen` is CSV/JSON only.** PDF needs a package; `ReportExporter` is the seam.
9. **Price-book UI.** `priceBookProvider` + `serviceEstimateProvider` exist; no settings screen exposes the multiplier or per-part overrides, and no card renders estimate ranges.

**P2 — hygiene**
10. **Part 1 tests are stale.** `test/{fuel_stats,maintenance_engine,models_and_expenses}_test.dart` compile but assert against superseded tiers, intervals and field names. Refresh or delete.
11. **Pre-existing duplicate service records** are de-duped at read time but still both appear in the Service Log list. A one-time merge migration is optional.
12. **Verify the dealer data.** The 4 entries are exactly as dictated and were **not** independently verified.
13. `tool/generate_app_icon.dart` lives under `flutter test` because that's the only headless `dart:ui` renderer. It contains no assertions.
