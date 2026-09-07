# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

DidWeights is a SwiftUI + SwiftData iOS app for logging weight-training workouts (home / start
screen, live workout session with a timer, workout history, reusable workout presets).

The repository is also a structured teaching exercise. `docs/ARCHITECTURE_MIGRATION.md` is the
assignment spec: it migrates the app from a JSON-blob persistence model to a normalized SwiftData
schema over milestones M0–M10, one PR per milestone. `docs/M0-critique.md` is the completed M0
deliverable. Milestones M0–M9 are merged (the legacy blob layer was deleted in `214f3ad`); the
current schema and repository layer are the destination state, not a work in progress. **Read the
relevant milestone section of `ARCHITECTURE_MIGRATION.md` before making persistence changes** — its
Appendix A ("The rules, condensed") and Appendix D (review checklist) are the conventions this
codebase is held to.

## Layout

The Xcode project lives in the `DidWeights/` subdirectory, not the repo root.

- `DidWeights/DidWeights/Models/` — the four `@Model` entities plus `Models/Extenstions/`
  (note the spelling) for derived/computed accessors.
- `DidWeights/DidWeights/Repositories/` — the only place data is written. One subdirectory per
  aggregate.
- `DidWeights/DidWeights/Views/` — one subdirectory per screen. Views read only.
- `DidWeights/DidWeightsTests/` — Swift Testing suites.
- `DidWeights/DidWeights/Utilities/`, `Assets.xcassets`, `SplashScreenView`, the `Color` palettes —
  out of scope for the migration; leave them alone unless the task is specifically about them.

## Build, run, test

Single scheme `DidWeights`; targets `DidWeights` (app) and `DidWeightsTests`. Swift 5 language
mode, app deployment target iOS 18.6. Tests use the **Swift Testing** framework (`import Testing`,
`@Suite`, `@Test`, `#expect` / `#expect(throws:)`), not XCTest.

```sh
# Build
xcodebuild -scheme DidWeights -project DidWeights/DidWeights.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run the whole test suite
xcodebuild -scheme DidWeights -project DidWeights/DidWeights.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run a single suite or a single test
xcodebuild ... test -only-testing:DidWeightsTests/WorkoutRepositoryTests
xcodebuild ... test -only-testing:DidWeightsTests/WorkoutRepositoryTests/finishPrunesUntouchedSetsAndRenumbersDensely
```

In Xcode, ⌘U runs the suite. There is no linter, package manifest, or CI configured.

## Architecture

### Schema (normalized, no blobs)

Four `@Model` classes registered in `DidWeightsApp` and in `ModelContainer.inMemory`:

- **`Workout`** — one training session. `endDate == nil` means it is *the* active workout.
  `sets: [ExerciseSet]` with `deleteRule: .cascade`. Optional `preset` back-reference. Pause is
  tracked as `pausedAt` + `accumulatedPause` (a `TimeInterval`), so `elapsed(asOf:)` can subtract
  paused time.
- **`Exercise`** — a catalog entry (e.g. "Bench Press"), shared across workouts and presets.
  `sets` has `deleteRule: .deny` (can't delete an exercise still referenced by a set);
  `presets` has `.nullify`.
- **`ExerciseSet`** — one set: `reps`, `weight` (both optional), `isCompleted`, `completedAt`.
  Belongs to one `Workout` and one `Exercise`. `order` is position **within the whole workout**,
  not within its exercise group.
- **`WorkoutPreset`** — a reusable plan. Holds both `exercises: [Exercise]` and
  `exerciseOrder: [UUID]`; see invariant below.

### Repositories are the only writers

All `modelContext.insert` / `.delete` / `.save` and all business rules live in
`Repositories/`. Views never mutate the store directly. Repositories are `@MainActor struct`s
constructed on demand from a `ModelContext` (e.g.
`private var workouts: WorkoutRepository { WorkoutRepository(context: modelContext) }` in a view).

- **`WorkoutRepository`** — lifecycle (`activeWorkout`, `startEmptyWorkout`, `startWorkout(from:)`,
  `pause`, `resume`, `finish`, `cancel`) plus, in `Extensions/WorkoutRepo+workout-lifcycle.swift`,
  composition (`addExercise`, `removeExercise`, `addSet`, `removeSet`, `removeLastSet`,
  `updateSet`, `toggleCompletion`).
- **`ExerciseRepository`** — `findOrCreate(name:)` (case- and whitespace-insensitive name match —
  "bench press" and "Bench Press" are the same exercise), `rename`, `delete`.
- **`PresetRepository`** — `create`, `update`, `delete`. Sole owner of the
  `exercises` / `exerciseOrder` pairing.

Failures **throw** a specific error (`WorkoutRepositoryError` cases). Never
`guard … else { return }` on a failed precondition, never `print` as error handling, never add
`try?` around a data operation. Views catch and surface the message in an `.alert`.

### Invariants to preserve

- **Exactly one active workout.** `startEmptyWorkout` / `startWorkout(from:)` throw
  `workoutAlreadyActive` if one exists; `activeWorkout()` throws `multipleActiveWorkouts` if it
  finds more than one (a corrupted state).
- **`ExerciseSet.order` is dense and unique** — `0, 1, 2, …` with no gaps, across the whole
  workout. Every method that adds or removes sets renumbers the survivors densely
  (`for (index, set) in survivors.enumerated() { set.order = index }`). `finish()` additionally
  prunes "untouched" sets (`reps == nil && weight == nil && !isCompleted`) before renumbering.
- **An exercise exists in a workout only by having sets.** There is no join entity.
  `Workout.exerciseGroups` derives the per-exercise grouping (and its order) from the sorted
  sets. `removeExercise` = delete all that exercise's sets in that workout.
- **`WorkoutPreset.exercises` and `exerciseOrder` always move together.** `exerciseOrder` is the
  source of truth for sequence; `orderedExercises` reads through it. Only `PresetRepository` may
  assign either property, and it always sets both (`preset.exerciseOrder = exercises.map(\.id)`).
- **Set completion requires `reps > 0`.** The single definition is `ExerciseSet.isCompletable`
  (in `ExerciseSet+Derived.swift`); `toggleCompletion` enforces it (throws `setNotCompletable`)
  and the UI reads the same property to disable the checkbox. Don't add a second rep-validity
  check anywhere.
- **`finish()` stamps `preset.lastActive`** with the finish date (shown on Home cards), not the
  start date.

### Reads: `@Query`, computed extensions, and the wrapper → content pattern

- Lists come from `@Query` with a `#Predicate` + explicit sort. **`#Predicate` may reference
  stored properties only** — computed properties can't be translated to the store.
- Derived values (counts, totals, groupings, `orderedSets`, `orderedExercises`) are computed
  properties in `Models/Extenstions/`. **Ordered relationships must be sorted explicitly on
  every read** — SwiftData relationship arrays have no inherent order.
- When a view needs a single model that could be deleted underneath it, use the
  **wrapper → content** split: a wrapper `View` owns the `@Query` (by predicate or id), resolves
  the 0 / 1 / many cases, and passes a concrete model object to a content `View`. See
  `ActiveWorkoutView` → `ActiveWorkoutContent` and `WorkoutDetailView` → `WorkoutDetailContent`.
  Building a `@Query` from an `init` parameter uses the `_matches = Query(...)` underscore form.

### Naming

Model types are qualified to avoid shadowing the standard library — `ExerciseSet`, not `Set`
(a `@Model class Set` would shadow `Swift.Set` module-wide with errors pointing at use sites).
Apply the same caution to `Task`, `Result`, `Data`, `Measurement`, etc.

## Tests

Each suite is `@MainActor @Suite struct` and builds its **own** in-memory store in `init()` via
`try ModelContainer.inMemory(seeded:)` (in `Models/Extenstions/`), keeping a strong reference to
the container for the test instance's lifetime (Swift Testing makes a fresh struct per `@Test`).
No shared state between tests. `seeded: true` inserts a small Bench Press / Squat / "Push Day"
fixture; most repository tests use `seeded: false` and build exactly what they need.
