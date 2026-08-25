# Vehicle Care — Session Context Export

> Snapshot taken 2026-08-25. Paste into a fresh thread to resume without context
> loss. Supersedes `HANDOVER_CURSOR.md` where the two disagree.

---

## 0. Repo state

- **Path:** `E:\FlutterProjects\CarMaintenance` · package `vehicle_care` (branded
  "Vehicle Care"; `CarHub` in `.cursorrules` is an alias only)
- **Last commit:** `160ddc4 Adding Octan 80, Gas to Fuel type` · **40 files uncommitted**
- `flutter analyze` → **0 issues**. `dart format lib/` clean.
- **NEVER BUILT.** Gradle fails: `java.io.IOException: Unable to establish loopback
  connection`. Nothing below is runtime-verified — analyzer + targeted
  `flutter test` probes + source reading only.
- `flutter test` works **only** via PowerShell
  (`Set-Location E:\FlutterProjects\CarMaintenance; flutter test ...`); bash returns
  exit 137.
- Arabic is the default locale; RTL is primary. Digits are pinned Latin via
  `Fmt._digits()` → never wrap a mixed Arabic+digit string in
  `AppTypography.numeric`.

---

## 1. Work completed this session

### 1.1 Animation lifecycle — "once on mount, never on scroll"

- **`lib/core/widgets/entrance_animation.dart`** — rewritten as a `HookWidget`.
  It had been gutted to an identity `StatelessWidget` returning `child`, with a
  constructor that accepted and discarded `delay`/`duration`/`slide` — so all 19
  call sites were passing arguments into a no-op. Now:
  - `useAnimationController` (built once per element)
  - `forward()` from `useEffect(..., const [])`
  - `_KeepAlive` (`AutomaticKeepAliveClientMixin`, `wantKeepAlive => true`) so a
    lazy `SliverList` cannot dispose a row and replay its fade on re-entry
  - settled → returns the child bare (no ticker, no `Opacity`, no transform)
  - exports `indexOfChildKey()` for `findChildIndexCallback`
- **`lib/core/widgets/animated_counter.dart`** (new)
  - `AnimatedCounter` — counts 0→value on mount; a later change tweens from the
    previous figure, not from zero
  - `CountingStatValue` — `AnimatedCounter` + `StatValue`, with `emptyLabel` so a
    tile with no data prints `—` instead of ticking to `0.00`
  - caller supplies `format`, so `Fmt.money` / `Fmt.dec2` keeps currency and
    Latin digits correct in Arabic
- **`lib/core/widgets/animated_progress_bar.dart`** — `AnimatedProgressBar` and
  `AnimatedRingGauge` are both `HookWidget`s now: fill/sweep once on mount,
  from→to tween on change, `RepaintBoundary` wrapped.
- All of the above respect `MediaQuery.disableAnimationsOf(context)`.

### 1.2 Dashboard entrance ladder

`lib/features/dashboard/presentation/screens/home_dashboard_screen.dart`

- **Every card used to self-wrap in `EntranceAnimation`** with its own hardcoded
  delay. That is precisely what made the consumables sheet animate twice: the
  sheet slides up, then the card inside fades and slides again.
- Self-wrapping removed from `NextServiceCard`, `SpendSummaryCard`,
  `FuelEfficiencyCard`, `DocumentsCard`, `VehicleHeroCard`, `_QuickActions`,
  `PartsHealthCard`.
- Single `_DashboardCard(order:, step:, child:)` ladder, declared in reading
  order, keyed `ValueKey('dashboard-card-$order')`.
- **Timing:** `step = 55ms`, `duration = 300ms` → last card lands ~385 ms
  (was ~580 ms). Shortened because every card is a blurred `GlassCard`
  (`BackdropFilter` = `saveLayer`), so an overlapping stagger drops frames.
- `PartsHealthCard` gained a `stagger` flag; `AllPartsSheet` passes
  `stagger: false`. Rows keyed `ValueKey(parts[i].part)`.

### 1.3 Keyboard performance — `MediaQuery.of` subscribes to `viewInsets`

Four full-subtree rebuilds per keyboard frame (~60 per open) found and isolated
into leaf widgets whose `child` is passed through unchanged, so `Element.update`
short-circuits the subtree:

| File | Leaf added | Was rebuilding |
|---|---|---|
| `lib/main.dart` | `_ClampedTextScale` | **the entire app** (call was inside `MaterialApp.builder`) |
| `lib/core/router/app_router.dart` | `_ShellInsets` | whole shell + 6-branch `IndexedStack` |
| `lib/core/widgets/app_sheet.dart` | `_KeyboardLift` | every form sheet body (`builder(context)` was called inline) |
| `lib/core/utils/screen_insets.dart` | `KeyboardAwareScrollPadding` | Settings screen and its 5 provider watches |

### 1.4 Settings keyboard black band — two nested Scaffolds both resizing

- Shell (`AppShellScaffold`, both the compact and the ≥900 px rail branch) →
  `resizeToAvoidBottomInset: false`.
- Settings `Scaffold` keeps the default resize — that is what scrolls the focused
  field into view — and now sets
  `backgroundColor: Theme.of(context).scaffoldBackgroundColor`. It was
  `Colors.transparent`, so the strip the resize vacated rendered as black.
- `context.keyboardAwareScreenPadding()` collapses the nav-bar gutter to
  `ScrollGutter.bare` while the keyboard is open.
  **Never pair it with `resizeToAvoidBottomInset: false` plus a manual bottom
  inset** — the doc comment states this.
- `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag`.

### 1.5 Navigation transitions

`lib/core/router/app_router.dart`

- `_FadeThroughPage` — 210 ms forward / 180 ms reverse, `opaque: true`,
  non-overlapping intervals (outgoing fully transparent by 0.3, incoming starts
  at 0.3) so the two are never both painted visibly.
- `_ModalPage` — 220/190 ms slide-up for `/add-fuel` and `/export-report`.
- `_RouteSurface` — paints `scaffoldBackgroundColor` under every routed page.
  Screens set `Colors.transparent`, which was the ghosting source.
- `_branchPage` — `NoTransitionPage` for tab roots.
- `_TabFadeIn` replaced `_TabTransition`/`AnimatedSwitcher` — 200 ms, opacity
  0.55→1 on **one** subtree. `AnimatedSwitcher` kept both tabs mounted, which was
  the stacking artifact.

### 1.6 FAB positioning

- **`lib/core/widgets/app_fab_location.dart`** (new) —
  `AppFabLocation extends StandardFabLocation with FabEndOffsetX`, with a custom
  `getOffsetY` that **ignores `minViewPadding`**. The default `endFloat` lifts by
  `minViewPadding.bottom`, which the shell overrides to the full nav-bar height,
  and then Flutter adds `kFloatingActionButtonMargin` on top — so the button
  floated well above the bar.
- `AppFab.of(context)` → `bottomInset = MediaQuery.paddingOf(context).bottom`
  (nav-bar height inside the shell, plain system inset outside). `gap = 12`.
- Keeps the three behaviours the default gave for free: keyboard, snackbar,
  bottom sheet.
- Applied to `fuel_screen`, `expenses_screen`, `maintenance_log_screen`,
  `workshops_screen`.
- `ScrollGutter.fab` 80 → **76** so the gutter and the button clearance stay the
  same geometry read from two directions.

### 1.7 Spend Summary consolidation

- **`lib/core/widgets/spend_composition_bar.dart`** (new) —
  `SpendCompositionBar` + `SpendSegment`. One outer `ClipRRect`, so only the far
  tips curve and inner dividers stay square. Gradient, sheen and dark-theme glow
  lifted from `AnimatedProgressBar`. Sweeps once from the leading edge.
- **`lib/features/dashboard/presentation/widgets/spend_summary_card.dart`** —
  unified `SpendSummaryCard({bool showMonthlyPace = false})`. Expenses-screen
  design is the base; the dashboard's monthly-pace stat is the optional third
  mini-stat. Dominant-stream accent. `_SpendStream` list declared once so the bar
  and legend cannot drift apart.
- **~404 lines deleted** from `expenses_screen.dart`: `_TotalsCard`,
  `_SpendComposition`, `_Segment`, `_SpendLegend`, `_TotalsStat`.
- Call sites: dashboard `SpendSummaryCard(showMonthlyPace: true)`; expenses
  `const SpendSummaryCard()`.

### 1.8 `PredictServices` deduplication

`lib/features/maintenance/domain/usecases/predict_services.dart`

- `call()` and `nextDue()` take optional `pace`, `phaseRecords`, `lastService`.
  Omit them and they are computed exactly as before, so every existing caller is
  untouched. `_recordsByPhase` became public `recordsByPhase`.
- New `serviceRecordsByPhaseProvider` in `maintenance_providers.dart`.
- `serviceRoadmapProvider` and `nextServiceDueProvider` now feed in
  `dailyPaceProvider`, `serviceRecordsByPhaseProvider`, `lastServiceProvider`.
- Per dashboard build: `dailyPace` ×3→1, `recordsByPhase` ×2→1,
  `lastPerformed` ×2→1.
- **Verified equivalent by probe.** Chain for a vehicle at 20 km with services at
  9,500 / 19,800 → `[1000, 10020, 19500, 29800, …]`.

### 1.9 Counters wired in

`SpendSummaryCard` headline · `VehicleHeroCard` odometer
(`l10n.vehicleCurrentOdometer`) · 4× analytics `_SummaryTile` · 3× fuel
`_SummaryTile`. Those tiles now take `double value` +
`String Function(double) format` instead of a pre-formatted string.

---

## 2. Load-bearing architecture rules

### 2.1 ProviderScope and navigation

```
AppBootstrapGate
├── splash → _SplashApp (its own MaterialApp)
└── app    → ProviderScope → VehicleCareApp → MaterialApp.router
```

- **Each branch owns its own `MaterialApp`.** A shared outer one would own the
  root `Navigator`; every modal opens with `useRootNavigator: true` and would
  mount above the `ProviderScope` → `Bad state: No ProviderScope found`.
- **All modals go through `showAppSheet` / `showAppDialog`**
  (`lib/core/widgets/app_sheet.dart`). Both capture
  `ProviderScope.containerOf(context, listen: false)` and re-expose it via
  `UncontrolledProviderScope`. A grep for raw `showModalBottomSheet` /
  `showDialog` outside that file returns nothing — keep it that way.

### 2.2 Two distances — do not unify

| Field | Definition | Used by |
|---|---|---|
| `VehicleMetrics.trackedDistanceKm` | `currentOdometer − initialOdometer` | total cost of ownership per km |
| `VehicleMetrics.fuelDistanceKm` | first fill → current odometer (`FuelStats.liveDistanceKm`) | L/100 km, km/L, fuel cost per km, octane comparison |

Consumption cannot claim kilometres driven on fuel the app has no record of.
Unifying them silently understates consumption for any used car added mid-life.

### 2.3 Single sources of truth

- **`vehicleMetricsProvider`**
  (`features/analytics/presentation/providers/vehicle_metrics_provider.dart`) —
  every fuel and cost figure on Home, the Fuel tab, the Analytics grid, the
  efficiency chart and the exported report. Never recompute in a widget.
- **`FuelMath`** (`features/fuel/domain/fuel_math.dart`) — every litres/money/km
  formula. `safeDivide` returns `0.0`, never `NaN` or `Infinity`.
- **`Contrast`** (`core/theme/contrast.dart`) — `inkOn(surface)` by WCAG contrast
  ratio, not a luminance threshold (silver sits at 0.4999 and breaks `> 0.5`).
- **`context.screenPadding()` / `splitScreenPadding()` /
  `keyboardAwareScreenPadding()`** (`core/utils/screen_insets.dart`) — never
  hand-roll a bottom padding.

### 2.4 Riverpod conventions

- Synchronous `Notifier<List<T>>`, seeded from the repository in `build()`,
  mutating `state` on write. Streams **only** when `isRemoteBackendProvider`, via
  `bindStream` (microtask-deferred).
- No side effects in `build()`. `reminderSignatureProvider` is a pure
  `Object.hash`; `VehicleCareApp` reacts via `ref.listen`.
- Controllers are `AsyncNotifier<void>` returning `Future<bool>` via `_run`.
- No codegen anywhere — no `.g.dart`, no `build_runner`, no `riverpod_annotation`.
- **Mixed hooks/Riverpod:** 10 files use `HookWidget` / `HookConsumerWidget`
  (`flutter_hooks ^0.21.3`, `hooks_riverpod ^2.6.1`), while `.cursorrules` §1
  still says "ConsumerWidget / ConsumerStatefulWidget EXCLUSIVELY".
  **Unresolved — see §3.**

### 2.5 Notifications

`features/dashboard/presentation/providers/reminder_scheduler.dart`

| Category | Trigger | Repeat |
|---|---|---|
| Licence & insurance | 30 / 7 / 1 days before expiry | once each |
| Service & parts, by date | from 14 days before projected date | daily (15 armed) |
| Service & parts, by distance | remaining ≤ 1,000 km | every 2 days (7 armed) |

- Distance **beats** date — within 1,000 km only the distance run is scheduled.
- `pendingBudget = 60` (iOS caps at 64 and silently drops the overflow),
  `documentReserve = 6`, plans ranked most-urgent-first.
- Keyed on `milestone.id` (`'ms_p$phaseIndex'`), not `targetOdometer`, which
  drifts when an earlier phase closes off-grid.

### 2.6 Visual rules

- `GlassCard`: animated decorations vary **alpha only** — lerping `blurRadius`
  under an overshoot curve goes negative and trips a `dart:ui` assert.
  `RepaintBoundary` per card. **List rows pass `blur: false`.**
- `GuidanceCard`: the card collapses, the steps inside do **not** (static title +
  body).
- `AppActionButton`: enabled = saturated, elevated, outlined; disabled = flat,
  muted, shadowless.
- Explicit `mainAxisAlignment` / `crossAxisAlignment`. A `FittedBox` shrink-wraps,
  so it needs `Align(alignment: AlignmentDirectional.centerStart)` to sit on the
  leading edge.
- `EdgeInsetsDirectional` / `PositionedDirectional` / `AlignmentDirectional`
  everywhere.
- Sheet titles and buttons are context-driven: `Edit …` + `Save changes` when
  editing, `Add …` + `Save` when creating.
- No infrastructure names in user-facing text. `cloudUnavailable` and
  `sourceCloudHint` are sanitised; the bootstrap failure screen logs the raw
  error and shows `somethingWentWrong`.

### 2.7 Cursor-era additions — audit before extending

Not written in this session:

`/forecast` route + `insights_forecast_screen.dart` · `vehicle_catalog.dart`
(454 lines) + `vehicle_catalog_field.dart` · vehicle transfer codec / remapper /
providers · `firestore_expense_repository.dart` · `file_report_exporter.dart` ·
`file_loader.dart` · `app_fonts.dart` (bundled Cairo / NotoSansArabic / Roboto,
`AppFonts.ensureLoaded()` awaited in `main`) · `fuel_price_defaults.dart` ·
`FuelType` now has 5 members (`octane80`, `octane92`, `octane95`, `diesel`,
`naturalGas`, with `isGaseous` / `volumeUnitKey` / `priceLabelKey` /
`amountLabelKey`) · `AppBootstrapResult` (prefs + dealerRepository +
reminderNotifier) · `file_picker ^12.0.0`.

---

## 3. Pending and open

### Blocking

- **Get a build working.** The Gradle loopback failure is environmental
  (firewall/AV blocking Java sockets). The PDF layout, native splash alignment,
  notification scheduling, FAB position and keyboard behaviour all need a real
  device before anyone should call them done.

### Unresolved decisions

- **`.cursorrules` §1 vs the hooks adoption** — which is authoritative?
- **`.cursorrules` §3** says avoid ExpansionTiles for tips cards; `GuidanceCard`
  still collapses at the card level (the steps themselves are static). Confirm
  the intent.

### Known gaps

- `test/fuel_stats_test.dart` and `test/models_and_expenses_test.dart` are stale
  — they assert the superseded full-tank contract.
  (`maintenance_engine_test.dart` was already deleted.)
- **Dead surface:** `AppActionButton.outlined` and `dense` are unused;
  `EntranceAnimation.enabled` is unused.
- `AnalyticsSummary.costPerKm` is range-scoped by design, so it differs from the
  lifetime figure on Home. Intentional.
- Android public Downloads (`/storage/emulated/0/Download`) is best-effort under
  scoped storage; a MediaStore channel is the only way to guarantee it.
- Firebase is unconfigured — needs `flutterfire configure`; web and iOS need an
  explicit `options: DefaultFirebaseOptions.currentPlatform`.
- `/add-fuel` and `/dealer-details/:id` are wired and URL-addressable but nothing
  navigates to them.
- No Vehicle Profile screen (`VehicleImageHeader` was built for it and is
  unused).
- No price-book UI (`priceBookProvider`, `serviceEstimateProvider` exist).
- Duplicate service records are de-duped at read time by
  `DistinctServiceRecords`, but both still appear in the Service Log list.

---

## 4. Workflow

- After every change: `dart format lib/`, then `flutter analyze` (must be **0**).
- Any new user-facing string goes into **both** `strings_en.dart` and
  `strings_ar.dart` (Arabic translated, not transliterated), plus an optional
  named getter in `app_localizations.dart`.
- Never ship test files. Temporary probes are fine during work but must be
  deleted before finishing.
