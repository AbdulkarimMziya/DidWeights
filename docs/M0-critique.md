# M0 — Critique

## 1. Five concrete problems with the current persistence design

### Problem 1 — Unqueryable blob storage
`Workout`, `SavedWorkout`, and `Exercise` are `@Model` types, but the real
content — exercises, sets, reps, weights — lives inside `workoutData: Data`,
a JSON-encoded blob. SwiftData can query `id`, `name`, `startDate`, `endDate`,
but has no visibility into anything inside that blob. Concretely:
`HomeView.swift → WorkoutTemplateCard.exerciseCount` decodes the entire blob
just to read `.exercises.count`.

### Problem 2 — Domain logic embedded in a View
`ActiveWorkoutView.swift → handleFinishTapped()` decides which finish
confirmation alert to show by directly inspecting `workout.exercises` and
computing `hasUnfinishedSets`. This is a business rule ("what counts as a
workout worth confirming before finishing") living inside a `View`, not in
`WorkoutManager` or a repository — meaning it can't be tested without
instantiating the view.

### Problem 3 — Decode-per-render, not per-change
`HomeView.swift → WorkoutTemplateCard.exerciseCount` and
`WorkoutDetailView.swift → logged` are computed properties, not cached state.
SwiftUI re-evaluates them on every `body` re-render of their view, so each one
pays a full `Data → JSON → LoggedWorkout` decode cost repeatedly for the same
unchanged data — not once when the data changes, but once per render.

### Problem 4 — Two sources of truth for the active workout
`WorkoutManager.activeWorkout` is the in-memory `LoggedWorkout`, mirrored into
`UserDefaults` on every `didSet`. It is never backed by a SwiftData `Workout`
row until `finishWorkout` runs. Any code that queries SwiftData directly for
"the active workout" would be reading a second, independent representation
with no shared identity to the one `WorkoutManager` actually holds.

### Problem 5 — Decode failures lose their cause, twice
`PersistanceHelper.transformFromData` catches the real `DecodingError` thrown
by `JSONDecoder` — which carries specific information about what went wrong
(missing key, type mismatch, corrupted data, coding path) — and discards all
of it, re-throwing a bare `SerializationError.decodingFailed` with no context.
Every caller (`WorkoutDetailView.logged`, `WorkoutTemplateCard.exerciseCount`,
`CreatePlanView.loadExistingPlanIfNeeded`) then wraps that call in `try?`,
discarding even the reduced error entirely. A corrupted blob and an empty
collection become indistinguishable by the time either reaches the UI.

---

## 2. The 10× question

**Problem 1 at 500 workouts vs. 5:** `WorkoutTemplateCard.exerciseCount` runs
once per visible plan card, every render. With 5 saved plans this is a
negligible, unnoticed cost. At scale this isn't really about *plan* count
(users don't save hundreds of plans) — it's about `WorkoutDetailView.logged`
decoding a *single* workout's blob on every render of the history detail
screen. The mechanism doesn't get worse with more history rows sitting in
SwiftData (those are cheap columns), but any feature that tries to aggregate
across many `Workout` rows — "show me total volume this month" — would have
to decode every one of those 500 blobs in memory, sequentially, in Swift code,
because none of that content is indexed or queryable at the database level.

**Problem 4 at 500 workouts vs. 5:** the two-sources-of-truth problem doesn't
scale with data volume directly — it's a structural bug, not a performance
one. But more historical `Workout` rows means more accumulated *evidence* of
the bug if a future `@Query`-based active-workout view is added: every
finish/cancel cycle that hits the mismatch (§1.2's cascade) potentially
leaves behind another stray open row with `endDate == nil`. At 5 workouts a
stray row is a curiosity; at 500, distinguishing "genuinely still open" rows
from "orphaned by the bug" rows becomes a real data-integrity problem with no
clean way to tell them apart after the fact.

**Problem 5 at 500 workouts vs. 5:** with `try?` swallowing decode failures,
a single corrupted blob among 5 workouts is easy to notice and investigate by
hand. Among 500, a small percentage of silently-failing decodes (say, from a
future schema change that isn't backward compatible) would surface only as
scattered "Couldn't load workout details" screens with no aggregate way to
find out how many rows are actually affected, since nothing logs or surfaces
*which* rows failed or why — the failure is per-render and per-view, not
tracked anywhere centrally.

---

## 4. Schema sketch

```
Workout
├── id
├── startDate
├── endDate: Date?
└── workoutExercises: [WorkoutExercise]   — delete rule: cascade

WorkoutExercise
├── id
├── workoutId
├── order
├── exercise: Exercise                     — delete rule: deny
└── exerciseSets: [ExerciseSet]            — delete rule: cascade

Exercise
├── id
└── name

ExerciseSet
├── id
├── workoutExerciseId
├── order
├── weight
├── reps
└── isCompleted

WorkoutPresetPlan
├── id
├── name
└── presetExercises: [PresetExercise]      — delete rule: cascade

PresetExercise
├── id
├── order
├── setCount: Int
└── exercise: Exercise                     — delete rule: deny
```

**Relationships summary**

| From → To | Cardinality | Delete rule |
|---|---|---|
| `Workout → WorkoutExercise` | one-to-many | cascade |
| `WorkoutExercise → Exercise` | many-to-one | deny |
| `WorkoutExercise → ExerciseSet` | one-to-many | cascade |
| `WorkoutPresetPlan → PresetExercise` | one-to-many | cascade |
| `PresetExercise → Exercise` | many-to-one | deny |

