# DidWeights: Settings and a kg/lbs Unit Preference

**A small assignment spec, same shape as `ARCHITECTURE_MIGRATION.md`, much smaller scope.**

---

## Contents

**[Part 0 — Before you start](#part-0--before-you-start)** — read this first, ground rules, scope

**[Part 1 — Background](#part-1--background)** — read before writing code
- [1.1 Why a display unit isn't a storage unit](#11-why-a-display-unit-isnt-a-storage-unit)
- [1.2 Preferences are `@AppStorage`, not a new `@Model`](#12-preferences-are-appstorage-not-a-new-model)
- [1.3 Where conversion is allowed to happen](#13-where-conversion-is-allowed-to-happen)
- [1.4 Reuse over invention](#14-reuse-over-invention)
- [1.5 Built but inert: the Profile card](#15-built-but-inert-the-profile-card)

**[Part 2 — The milestones](#part-2--the-milestones)** — one PR each, all merged

| | Milestone | Deliverable |
|---|---|---|
| M0 | The conversion utility | `WeightUnit`, tested, no callers |
| M1 | Settings screen shell | The Settings tab, all three live controls, Profile built-but-inert |
| M2 | Weekly Target takes effect | `WeeklyConsistencySection` reads the stored goal |
| M3 | Weight unit takes effect everywhere | Active workout + history read/write through `WeightUnit` |

**[Part 3 — Reference](#part-3--reference)**
- [Appendix A — The rules, condensed](#appendix-a--the-rules-condensed)
- [Appendix B — Review checklist](#appendix-b--review-checklist)

---

## Part 0 — Before you start

### What exists today

Before this feature: no Settings screen, no unit system, no preferences infrastructure at all
beyond one precedent — `RestTimerPickerSheet.swift` already owns
`@AppStorage("restTimer.preferredDuration")`. `ExerciseSet.weight` is a unit-less `Double?`, and
every place it's shown hardcodes a `"lb"` / `"LBS"` label (`ActiveWorkoutView.swift`'s
`SetHeaderView`, `HistoryDetailView.swift`'s `setSummary(_:)`). There is no `"kg"` anywhere in
the codebase — the app has only ever meant pounds, it just never stored that fact anywhere.

There's no on-device data worth preserving through this change (confirmed before starting — this
app isn't released and its only user is its developer, the same situation
`ARCHITECTURE_MIGRATION.md` M9 describes), so this is a green-field addition, not a data
migration. `ExerciseSet.weight` simply becomes canonically **kilograms** from here on, with no
`VersionedSchema` and no back-fill of existing rows.

### Ground rules

1. **The repository never learns about units.** `WorkoutRepository.updateSet` stays exactly what
   it was: `set.reps = reps; set.weight = weight`, kg in, kg out, no conditional on a preference.
   If you find yourself passing a `WeightUnit` into a repository method, stop — the conversion
   belongs one layer up, in the view that's about to call it.
2. **One PR per milestone**, same discipline as the bigger migration doc, even though this is
   four milestones instead of ten.
3. **Reuse existing state instead of inventing a parallel copy of it.** This document exists
   partly *because* two real pieces of state — the weekly-target goal and the rest-timer default
   — already existed as hardcoded/`@AppStorage` values before Settings did. Settings is the
   second place that reads/writes them, never a competing source of truth.

### Out of scope

The mockup this was built from also shows a Distance km/mi toggle, an Auto-warmup Sets toggle,
a Timer Sound toggle, and a Stats tab. None of the four exist as features in this app — there's
no distance tracking, no warmup-set concept, no audio anywhere in the codebase, and no Stats
screen. Building controls for features that don't exist is the fastest way to end up with a
Settings screen that lies to the user, so all four are left out entirely rather than added as
decorative no-ops. If any of those features gets built later, its Settings control arrives in the
same PR as the feature, not before it.

---

## Part 1 — Background

### 1.1 Why a display unit isn't a storage unit

The tempting shortcut is to add a `unit` field next to `weight` on `ExerciseSet` and store
whatever the user typed, in whatever unit they had selected that day. Don't — that makes every
future read of `weight` conditional on a second field, makes `totalVolume`
(`Workout+Derived.swift`) a mixed-unit sum the moment two sets were logged under different
preferences, and makes changing your mind about units after the fact a genuine data migration
instead of a `Picker` flip.

Instead: **the model only ever speaks kilograms.** A display unit is a lens you look through, not
a property of the weight itself. Reading converts kg → the current lens; writing converts the
lens back to kg before the value ever reaches `set.weight`. The stored number never changes
meaning depending on when it was written.

### 1.2 Preferences are `@AppStorage`, not a new `@Model`

`ARCHITECTURE_MIGRATION.md` §1.2 already drew this line: `UserDefaults` is for preferences —
"sort order, hide completed, theme choice" — not domain data. A weight-unit preference is exactly
that list's next entry. `RestTimerPickerSheet.swift` had already established the pattern
(`@AppStorage("restTimer.preferredDuration")`), so Settings doesn't introduce a new mechanism —
it's the second, general place that pattern shows up, plus two more keys.

There's no environment-injected settings object in this app, and this feature doesn't add one.
Each view that needs a preference declares its own `@AppStorage` for that key, same as
`RestTimerPickerSheet` always has. That reads as duplication the first time you see three views
each with their own `@AppStorage(WeightUnit.storageKey)` — it's duplicated *wiring*, three
lines each, not duplicated *logic*: the key string, the conversion math, and the fallback rule
all live in exactly one place (`WeightUnit`), so the three call sites can't quietly disagree about
what they mean.

### 1.3 Where conversion is allowed to happen

Exactly one place: the boundary between a `View` and everything else. Concretely:

- **Reading:** `weightUnit.fromKilograms(set.weight)`, called from inside a `Text`/formatting
  call site. Never inside a `Models/Extenstions/` computed property — `Workout+Derived.swift`'s
  `totalVolume` stays kg-denominated; whoever eventually displays it applies the conversion at
  the point of display, the same rule as everywhere else.
- **Writing:** a computed `Binding<Double?>` sits between the `TextField` and `set.weight`,
  converting the typed display-unit value to kg in its setter. The setter still assigns
  `set.weight` directly, so the existing `.onChange(of: set.weight) { try? workouts.updateSet(...) }`
  write path is untouched — there's no second way to write a weight, just a converting front door
  on the existing one.

If a future change needs weight anywhere else — an export, a PR chart, a personal-record query —
the rule doesn't change: fetch/compute in kg, convert only where it's about to be shown.

### 1.4 Reuse over invention

Two of the three Settings controls aren't new state, they're new *front ends* on state that
already existed:

- **Weekly Target** used to be `WeeklyConsistencySection.swift`'s hardcoded `private let goal = 5`.
  Settings didn't invent a goal — it made the existing hardcoded number editable, and
  `WeeklyConsistencySection` now reads the same `@AppStorage` key Settings writes.
- **Default Rest** used to be settable only from inside an active workout, via
  `RestTimerPickerSheet`'s `@AppStorage("restTimer.preferredDuration")`. Settings reuses that exact
  key and `RestTimerPreset`'s existing four presets and labels — it's a second place to set the
  same default, not a second default.

Only **Weight unit** is genuinely new state, and it's the one thing this feature was actually
asked to build. The other two controls exist because the mockup called for them and the state to
back them turned out to already be sitting in the codebase, one hardcoded literal away from being
a preference.

### 1.5 Built but inert: the Profile card

The mockup's top section — avatar, name, plan badge, Edit button — has nothing behind it. There's
no account or profile model anywhere in this app. Three ways to handle a UI piece with no data
yet: leave it out of the diff entirely, wrap it in `#if false`, or build it as a real, standalone,
previewable file that's just never added to `SettingsView`'s view hierarchy.

The third is what `ProfileCardView.swift` does, and it's worth knowing why the other two lose.
Leaving it out means redoing the layout work later from the mockup a second time. `#if false`
disables the compiler and Xcode's SwiftUI tooling for everything inside it — it bit-rots silently,
and the day someone wants it back, it may no longer even compile against whatever the rest of the
file has become. A separate file compiles today, previews today, and is a single
`ProfileCardView()` line away from being wired in — the same one-file-per-component granularity
this codebase already uses for `StatTile`, `WeeklyConsistencyCard`, and the rest of `Views/Components/`.

---

## Part 2 — The milestones

### M0 — The conversion utility

**Goal.** One pure, tested kg↔lb conversion type, with zero callers yet.

**Background.** Every other milestone in this doc consumes `WeightUnit`. Building and testing it
in isolation first means M1–M3 are all "wire an already-correct thing into a new place," never
"debug the math while also debugging the UI."

**What was built.** `Utilities/WeightUnit.swift`:

```swift
enum WeightUnit: String, CaseIterable, Identifiable {
    case kilograms
    case pounds

    static let storageKey = "measurementUnits.weight"

    var abbreviation: String { get }
    func fromKilograms(_ kilograms: Double) -> Double
    func toKilograms(_ value: Double) -> Double
    static func resolved(from rawValue: String) -> WeightUnit
}
```

Plus `DidWeightsTests/WeightUnitTests.swift`, covering: kilograms is the identity in both
directions; a known pounds value converts correctly both ways; a pounds round-trip stays within a
small epsilon of the original (the conversion factor isn't bit-exact); `resolved(from:)` falls
back to `.pounds` on empty or garbage input.

**Deliverable.** The enum and its test suite. Nothing else in the app references `WeightUnit` yet.

**Definition of done.** `⌘U` (or `xcodebuild ... test -only-testing:DidWeightsTests/WeightUnitTests`)
is green. The app builds and behaves identically to before — this milestone is inert by design.

**Traps.**
- **Rounding lives at display formatting, never inside the utility.** `fromKilograms`/`toKilograms`
  do plain, unrounded multiplication/division. Rounding here would quietly truncate the *stored*
  kg value the next time a converted display value got round-tripped back through a write.
- **The fallback default is `.pounds`, not `.kilograms`.** The app has only ever shown "lb"/"LBS" —
  see 1.1 and the M1 trap below for why getting this backwards is a real, silent bug, not a
  cosmetic one.

**Questions to answer.** Why does `resolved(from:)` exist as a named function instead of every
call site writing `WeightUnit(rawValue: raw) ?? .pounds` inline? (Same reasoning as
`ARCHITECTURE_MIGRATION.md`'s repeated point about a single source of truth: four inline copies
of that fallback can drift if one of them is ever edited without the others.)

---

### M1 — Settings screen shell

**Goal.** A third tab, a working screen, all three live controls wired to their `@AppStorage` keys.

**Background.** This is the only milestone that touches navigation (`ContentView`) and the only
one that introduces new files beyond M0's utility. Everything after this milestone is "make an
existing screen read what Settings now controls."

**What was built.**

`Views/SettingsView/SettingsView.swift` — `NavigationStack` → `List` styled like
`ExercisePickerView.swift`'s existing settings-adjacent pattern (`.insetGrouped`,
`Color.cardBg` rows, `Color(.neutral)` background). Three sections:

- **Measurement Units** — a segmented `Picker` over `WeightUnit.allCases`, bound through a
  computed `Binding<WeightUnit>` that reads/writes `@AppStorage(WeightUnit.storageKey)`.
- **Weekly Target** — a segmented `Picker` over `WeeklyConsistency.goalOptions` (`[3,4,5,6,7]`),
  bound directly to `@AppStorage(WeeklyConsistency.goalStorageKey)`.
- **Default Rest** — a segmented `Picker` over `RestTimerPreset.allCases`, reusing its existing
  `.label`s (`"30s"`/`"60s"`/`"90s"`/`"2m"`), bound through a computed `Binding<RestTimerPreset>`
  onto the existing `@AppStorage("restTimer.preferredDuration")`.

`Views/SettingsView/ProfileCardView.swift` — built per 1.5, not referenced from `SettingsView.body`.

`Models/Extenstions/WeeklyConsistency.swift` — additive constants only: `goalStorageKey`,
`defaultGoal = 5`, `goalOptions`. Placed here rather than in `Utilities/` so the key/default and
the day-state logic that already lived in this file stay next to each other.

`ContentView.swift` — one more `Tab("Settings", systemImage: "gearshape.fill") { SettingsView() }`.

**Deliverable.** The screen, reachable, all three controls functional. Profile visually absent.

**Definition of done.** Settings is the third tab. Changing any of the three controls persists
across a force-quit and relaunch (proves `@AppStorage`, not just `@State`, is doing the work).
No Profile row visible anywhere.

**Traps.**
- **`WeeklyConsistency.defaultGoal` must stay `5`** — the value `WeeklyConsistencySection` was
  already hardcoded to. A different default here would change the Home screen's weekly-goal
  display for existing app state the moment M2 lands, even though nobody touched Settings.
- **Default Rest's `@AppStorage` key and default must be the *existing* `"restTimer.preferredDuration"`
  / `RestTimerPreset.sixtySeconds`, not new ones.** Inventing a second key here would make
  Settings and the in-workout rest picker disagree until the user happened to touch both.
- **Each `Picker`'s selection binding is computed, not stored**, because `@AppStorage` only holds
  primitive types (`String` for the weight unit's raw value, `Double` for the rest duration) while
  the `Picker` wants to bind to `WeightUnit`/`RestTimerPreset` directly. A `Binding(get:set:)`
  wrapping the `@AppStorage` property is the bridge — don't duplicate the stored value into a
  second `@State`, which would let the two drift out of sync.

**Questions to answer.** Weekly Target and Default Rest didn't need new keys — they needed a
second UI on top of state that already existed. Weight unit did need new state. What's the
general rule for telling those two cases apart *before* writing any code?

---

### M2 — Weekly Target takes effect

**Goal.** `WeeklyConsistencySection` reads the Settings-controlled goal instead of a literal.

**Background.** The smallest possible milestone, deliberately: one hardcoded value becomes one
`@AppStorage`-backed value, and nothing else about the view changes.

**What was built.** In `Views/HomeView/WeeklyConsistencySection.swift`:

```swift
// before
private let goal = 5

// after
@AppStorage(WeeklyConsistency.goalStorageKey) private var goal = WeeklyConsistency.defaultGoal
```

`init(now:calendar:)` is untouched — `goal` needs no init-time computation, unlike `_workouts`'s
`Query`, so it can stay a plain property-wrapper declaration.

**Deliverable.** The one-line swap.

**Definition of done.** Changing Weekly Target in Settings changes the ring/goal shown on Home
immediately, with no relaunch required (this is `@AppStorage` inside a live SwiftUI view, not a
value read once).

**Traps.** None new — this milestone is exactly as small as it looks. If it grows beyond a
one-property change, something upstream (probably in M1) was designed wrong.

**Questions to answer.** `WeeklyConsistencySection` already had a custom `init`. Why doesn't
`@AppStorage` need to be assigned inside it, the way `_workouts = Query(...)` is?

---

### M3 — Weight unit takes effect everywhere

**Goal.** Every place a set's weight is read or typed goes through `WeightUnit`; the repository
stays completely unaware any of this exists.

**Background.** The payoff milestone, and the one where 1.3's rule gets tested against real
call sites: two reads (a header label, a history summary) and one write (a live `TextField`).

**What was built.**

`Views/ActiveWorkoutView/ActiveWorkoutView.swift`:
- `SetHeaderView`'s hardcoded `Text("LBS")` → `Text(weightUnit.abbreviation.uppercased())`, backed
  by its own `@AppStorage(WeightUnit.storageKey)`.
- `ExerciseSetRowView` gains a computed `displayWeight: Binding<Double?>`:

  ```swift
  private var displayWeight: Binding<Double?> {
      Binding(
          get: { set.weight.map(weightUnit.fromKilograms) },
          set: { set.weight = $0.map(weightUnit.toKilograms) }
      )
  }
  ```

  The weight `TextField` binds to `displayWeight` instead of `$set.weight`, with an explicit
  `.precision(.fractionLength(0...1))` on its `format:` (see Traps). The setter still assigns
  `set.weight` directly, so `.onChange(of: set.weight) { try? workouts.updateSet(...) }` — the
  existing write path into the repository — needed no change at all.

`Views/HistoryView/HistoryDetailView.swift`: `HistoryDetailContent.setSummary(_:)`'s hardcoded
`"... lb"` becomes `weightUnit.fromKilograms(weight)` formatted with `weightUnit.abbreviation`.

**Deliverable.** Both files, plus their own local `@AppStorage(WeightUnit.storageKey)` declarations
per 1.2. `WorkoutRepository`/`WorkoutRepo+workout-lifcycle.swift` — unchanged, confirmed by
inspection: `updateSet` still reads `set.reps = reps; set.weight = weight`.

**Definition of done.** Switching units in Settings while a workout is active immediately changes
the column header and converts an already-typed number rather than relabeling it. History detail
shows the same conversion. The full test suite (including the pre-existing `WorkoutRepositoryTests`)
is still green — this milestone should not have needed to touch a single repository test, because
it didn't touch the repository.

**Traps.**
- **The `TextField`'s `format:` needs an explicit fraction-length spec now.** Before this
  milestone, `format: .number` with no precision "worked" only because the typed value and the
  stored value were always identical — there was no conversion happening. `poundsPerKilogram`
  isn't bit-exact, so an unspecified precision on a converted value can surface floating-point
  noise (`134.99999999999997`) after a round trip.
- **`totalVolume` (`Workout+Derived.swift`) is kg-denominated and still has no display call site.**
  Nothing in this milestone changed that — it's flagged here so whoever eventually surfaces it
  applies `weightUnit.fromKilograms` to the *displayed total*, not inside the reps × weight
  reduction itself.
- **`Views/WorkoutGraphPreview.swift`** also hardcodes `"lb"`, but it's unreachable from any
  navigation path — self-referenced only by its own `#Preview`. Left untouched; not worth a
  milestone for dead code.

**Questions to answer.** `ExerciseSetRowView`'s write path could have been rebuilt as a fresh
`Binding` that calls `workouts.updateSet` directly in its setter, bypassing `.onChange` entirely.
Why does this implementation keep the existing `.onChange`-triggered write instead? What would
have been lost by rebuilding it?

---

## Part 3 — Reference

### Appendix A — The rules, condensed

| Situation | Do this |
|---|---|
| Displaying a stored weight | `weightUnit.fromKilograms(set.weight)`, converted at the `Text`/`TextField` call site |
| Accepting a typed weight | A computed `Binding<Double?>` between the field and `set.weight`, converting in its setter |
| A preference (unit, weekly goal, rest default) | `@AppStorage`, keyed and defaulted in exactly one place, read locally wherever it's needed |
| State that already exists as a hardcoded literal or an existing `@AppStorage` key | Reuse it — a second UI on the same key, never a second key |
| A UI piece with no data model behind it yet | A real, standalone, previewable file, left unreferenced — not `#if false`, not deleted |

**Smells, and what they mean**

| If you're writing… | Stop, because… |
|---|---|
| A `WeightUnit` parameter on a `WorkoutRepository` method | Conversion has leaked past the view boundary |
| `WeightUnit(rawValue:) ?? .pounds` inline, anywhere but inside `resolved(from:)` | You've created a second copy of the fallback rule that can drift from the first |
| Rounding inside `fromKilograms`/`toKilograms` | You're about to corrupt the canonical stored value, not just its display |
| A new `@AppStorage` key for weekly goal or rest duration | You've made Settings disagree with a view that already reads the real one |
| `#if false` around a real SwiftUI view | Silent bit-rot with no compiler check until someone flips it back on |

### Appendix B — Review checklist

- [ ] `WorkoutRepository`/`WorkoutRepo+workout-lifcycle.swift` diff is empty — `updateSet` never
      learned about units
- [ ] Every `@AppStorage(WeightUnit.storageKey)` declaration resolves its raw value through
      `WeightUnit.resolved(from:)`, never an inline `?? .pounds`
- [ ] `WeeklyConsistency.defaultGoal` is `5` and Default Rest's key/default match the pre-existing
      `RestTimerPreset` values — no silent behavior change for existing state
- [ ] Conversion math (`WeightUnit.swift`) has no rounding; formatting call sites do
- [ ] Full test suite green, `WeightUnitTests` included
- [ ] `ProfileCardView` compiles and previews, and is not referenced from `SettingsView.body`
