# DidWeights: Migrating to a Normalized SwiftData Model

**An assignment spec.**

---

## Contents

**[Part 0 — Before you start](#part-0--before-you-start)** · read this first, ground rules, scope

**[Part 1 — Background](#part-1--background)** — read before writing code
- [1.1 Why the blob has to go](#11-why-the-blob-has-to-go)
- [1.2 The second source of truth](#12-the-second-source-of-truth)
- [1.3 SwiftData in ten minutes](#13-swiftdata-in-ten-minutes)
- [1.4 The repository pattern](#14-the-repository-pattern)
- [1.5 The wrapper → content pattern](#15-the-wrapper--content-pattern)
- [1.6 Ordering, and where invariants live](#16-ordering-and-where-invariants-live)
- [1.7 The migration strategy: expand → migrate → contract](#17-the-migration-strategy-expand--migrate--contract)

**[Part 2 — The milestones](#part-2--the-milestones)** — one PR each

| | Milestone | Deliverable |
|---|---|---|
| M0 | Read the map, critique the territory | A written critique. No code. |
| M1 | Expand: quarantine the legacy schema | Renames only; zero behaviour change |
| M2 | The new schema | Four `@Model` entities, unused by the UI |
| M3 | `WorkoutRepository`, part 1: lifecycle | start / pause / resume / finish / cancel |
| M4 | `WorkoutRepository`, part 2: composition | exercises, sets, edits, completion |
| M5 | Prove it: the test target | Repository tested on an in-memory store |
| M6 | First read path: history | History + detail on `@Query`, no decoding |
| M7 | The active workout, end to end | The live session + exercise catalog, one source of truth |
| M8 | Presets | `PresetRepository`; `WorkoutManager` deleted |
| M9 | Contract: delete the legacy layer | A PR of almost pure deletions |
| M10 | Stretch | Optional. Pick one. |

**[Part 3 — Reference](#part-3--reference)**
- [Appendix A — The rules, condensed](#appendix-a--the-rules-condensed)
- [Appendix B — Naming against the standard library](#appendix-b--naming-against-the-standard-library)
- [Appendix C — What a real migration would have looked like](#appendix-c--what-a-real-migration-would-have-looked-like)
- [Appendix D — Review checklist](#appendix-d--review-checklist)

---

## Part 0 — Before you start

### Read this first

You built a working iOS app. It persists data, survives relaunch, has a real
navigation structure, custom theming, an active-session flow with a live timer, and a history
screen with month grouping. It ships. That is genuinely more than most people get to on a first
solo project, and none of what follows is a criticism of your ability.

What follows *is* a criticism of the **design**, and the distinction matters. The code you wrote
is the natural thing to write when you know Swift but haven't yet absorbed how SwiftData wants
to be used. It works at the scale you tested it. It will not survive the next three features you
want to build, and the reason it won't is interesting — interesting enough to be worth a
structured migration rather than a patch.

So the goal here is not "fix the bugs." The goal is that by the end you can look at a persistence
problem and know, without being told, where the data goes, who is allowed to write it, and how
the UI finds out it changed.

### How to use this document

- **Part 1 is background.** Read it before writing any code. It's the *why*. If you skip it, the
  milestones will feel like a list of arbitrary chores, because without the reasoning that's
  exactly what they are.
- **Part 2 is the work**, broken into milestones M0–M10.
- **Part 3 is reference material** you'll come back to mid-milestone.

### Ground rules

1. **One PR per milestone.** Not one PR for the migration. The whole point of the sequencing
   below is that it *can* be done in small pieces.
2. **The app builds and runs at the end of every milestone.** Not "builds" — *runs*. You can
   launch it and use it. Two milestones carry a deliberate, temporary regression while a read
   path and its write path sit on opposite sides of the migration: M6 leaves History empty until
   M7 fills it, and M7 disables starting from a plan until M8 restores it. Each one is named in
   its own Definition of done and closed out by the next milestone. That's the honest cost of
   doing this incrementally, and it's fine *because it's named*. What's not fine is a milestone
   that leaves the app broken by accident.
3. **Each PR description answers that milestone's "Questions to answer."** These aren't busywork.
   They're the part I'll actually read first, because they tell me whether the milestone taught
   you the thing it was supposed to teach you.
4. **You write all the code.** This document deliberately gives you type names, method
   signatures, and traps to avoid — and deliberately gives you no implementations. If you find
   yourself wanting a body filled in, that's the assignment working.
5. **Ask when stuck, but bring a hypothesis.** "This doesn't work" is a worse question than
   "I think `@Query` isn't refreshing because the predicate captures a computed property — am I
   right?" Even when the hypothesis is wrong, it's the faster conversation.

### Out of scope

Don't touch these. They're fine, and expanding scope is how migrations die:

- `SplashScreenView`, the `Color` palettes and `Color+Extension`, `Assets.xcassets`
- Visual design, spacing, animation
- Any new user-facing feature that isn't explicitly listed in a milestone

If you spot something cosmetic you want to change, write it down and do it after M9.

---

## Part 1 — Background

### 1.1 Why the blob has to go

Open `Models/SavedWorkout.swift` and `Models/Workout.swift`. Both have this:

```swift
@Attribute(.externalStorage)
var workoutData: Data
```

That `Data` is a JSON-encoded `LoggedWorkout`, which holds `[LoggedExercise]`, which holds
`[WorkoutSet]`. So the actual shape of your app's data — the exercises, the sets, the reps, the
weights — is an opaque byte array as far as the database is concerned.

You have three `@Model` types, but you are storing **one** meaningful thing per row and hiding
its structure. SwiftData is being used as a key-value store with extra steps. Here's the bill for
that, all of it from your current code:

**You can't ask questions.** "What did I bench last month?" "How many sets have I done this
week?" "Which exercises have I never trained?" Every one of those requires loading every row and
decoding every blob in memory, and none of them can ever be expressed as a `#Predicate`. The
database cannot see inside a `Data` column.

Look at what your three `@Query` declarations actually filter on. `HistoryView` and
`ActiveWorkoutView` both filter on `endDate`; `HomeView` sorts plans by `name`. Every one of them
uses a scalar you happened to leave *outside* the blob, because those are the only fields that
exist as far as the store is concerned. Not one query touches an exercise, a rep, or a weight —
and not one ever could.

**You decode on every render.** In `HomeView`:

```swift
private var exerciseCount: Int {
    (try? PersistanceHelper.transformFromData(plan.workoutData))?.exercises.count ?? 0
}
```

That's a full JSON decode of the entire plan, inside a computed property, on a card in a
`LazyVGrid` — so it runs every time SwiftUI evaluates that view, for every visible plan. To
produce an integer. `WorkoutDetailView.logged` does the same thing for the detail screen.

**Failures are invisible.** Look at what `try?` does in that snippet. If the decode fails, the
card says "0 exercises." Not "something went wrong" — *zero exercises*, indistinguishable from an
empty plan. `WorkoutDetailView` does the same thing, falling through to "Couldn't load workout
details" with no way to tell a corrupt blob from an empty workout.

`CreatePlanView.loadExistingPlanIfNeeded` is the worst of the three, though not quite in the way
it first looks: on a failed decode the editor opens with the plan's name and no exercises, and
`Save` is disabled while the list is empty — so it can't *immediately* destroy anything. But the
user sees a plan that appears to have lost its exercises, re-adds a couple, and hits Save. Now the
real exercises are gone, overwritten by a "fix" the user thought they were applying. Silent
failure plus a plausible recovery path is a more effective way to lose data than a straightforward
crash would be.

**Partial updates don't exist.** Changing one rep count means: mutate a struct nested three levels
deep, re-encode the *entire* workout to JSON, and write the whole blob. Every keystroke in a reps
field. Compare that to the alternative, where you change one integer on one row.

**Identity is fake.** `LoggedExercise` has *two* identifiers:

```swift
struct LoggedExercise: Codable, Identifiable {
    var id = UUID()
    var exerciseID: UUID
    ...
}
```

Every lookup in `WorkoutManager` (`exerciseIndex(for:)`, and therefore `addSet`, `removeSet`,
`toggleSetCompletion`, `updateWeight`, `updateReps`) matches on `id`. Nothing ever matches on
`exerciseID`. And when you add an exercise mid-workout:

```swift
func addExercise() {
    let newExercise = LoggedExercise(exerciseID: UUID(), exerciseName: "")
    ...
}
```

...you mint a brand-new random `exerciseID` that will never be seen again, for an exercise the
user hasn't even named yet. Meanwhile `Exercise` — a real `@Model`, registered in your container
in `DidWeightsApp` — is never inserted, never fetched, and never displayed. It exists in the
schema and nowhere else. Bench Press in Monday's workout and Bench Press in Thursday's
workout are two unrelated strings inside two unrelated blobs. There is no way to connect them,
which means there is no way to ever build progress tracking, and progress tracking is the entire
point of a lifting app.

**And you're paying for `.externalStorage` on all of it.** That attribute tells SwiftData to
write the value to a separate file on disk when it's large. It's designed for photos and video.
Your workouts are a few hundred bytes of JSON.

### 1.2 The second source of truth

That's the storage problem. There's a structural one layered on top of it, and it's the one
actually causing bugs today.

`WorkoutManager` holds the in-progress workout in memory:

```swift
var activeWorkout: LoggedWorkout? {
    didSet { persistActiveWorkout() }
}
```

...and mirrors it into `UserDefaults` on every single mutation, under
`"com.didweights.activeWorkoutDraft"`. Every keystroke in a reps field re-encodes the entire
workout to JSON and writes it to `UserDefaults`.

`UserDefaults` is for user *preferences*. Sort order, "hide completed", theme choice. It is a
property list read into memory at launch. It is not a database, it has no transactions, no
querying, no relationships, and no migration story. You have your app's most important live
state in it.

But the real problem isn't `UserDefaults` — it's that **the active workout now exists in two
places at once.** Look at `ActiveWorkoutView`:

```swift
@Query(filter: #Predicate<Workout> { workout in workout.endDate == nil }, ...)
var workouts: [Workout]

var body: some View {
    if let activeWorkout = workouts.first {
        ActiveWorkoutContent(workout: activeWorkout)...
    }
}
```

The wrapper queries SwiftData for the active workout. Then `ActiveWorkoutContent` does this:

```swift
if let workout = manager.activeWorkout {   // ...and reads the *other* one
```

It renders `manager.activeWorkout` — the in-memory `LoggedWorkout` — and uses the injected
SwiftData `Workout` for exactly one thing: stamping `endDate` in the finish alert.

Two representations of one concept, kept in sync by hand. That never holds. Here's what it has
already cost you — trace it yourself, it's worth doing, and start from a freshly installed app:

1. **`manager.startWorkout()` and `startWorkout(from:)` never insert a `Workout` row.** They
   build a `LoggedWorkout` in memory and write it to `UserDefaults`. Nothing reaches SwiftData.
   The only code in the entire app that inserts a `Workout` is `finishWorkout`.
2. So on a clean install, `ActiveWorkoutView`'s query for `endDate == nil` matches nothing. Its
   body is `if let activeWorkout = workouts.first { ... }` with no `else` — so the sheet presents
   **blank**. There is no Finish button to tap. The session you started exists, in
   `UserDefaults`, on a screen that renders nothing.
3. Now suppose one open row *does* exist — left behind by an earlier build, inserted by hand while
   debugging, or produced by step 5 below. `ActiveWorkoutContent` renders `manager.activeWorkout`
   while holding that unrelated row, and the Finish button appears.
4. `Workout.init` sets `endDate = nil`, and `WorkoutManager.finishWorkout(modelContext:)` inserts
   `Workout(name:workoutData:)` without touching it. **A workout you just finished is written to
   the database as an open one.**
5. `HistoryView` queries `endDate != nil`, so it isn't in history. `ActiveWorkoutView` queries
   `endDate == nil`, so it *is* in the active query. Each finish adds another open row.
6. The `.finishWorkout` alert then does `workout.endDate = .now` — on the row the query handed
   the view, which is not the workout that was just finished. So a finish closes some *earlier*
   row and opens a new one. History lags, and the workout you see in it isn't the one you did.
7. The `.unfinishedSets` alert calls `finishWorkout` and never stamps `endDate` at all, so it
   inserts an open row and closes nothing. Open rows accumulate; the ones the finish path skips
   over stay open indefinitely.

Now: **you did not write seven bugs.** You wrote one design with two sources of truth, and seven
symptoms fell out of it. That's the lesson, and it's why the fix is a migration and not a
patch. Chasing these individually would mean adding more synchronization between the two
representations, and every line of that is a line you're about to delete.

### 1.3 SwiftData in ten minutes

Enough to do this migration. Not exhaustive.

**`@Model`** turns a class into a persisted entity. It's a macro; it rewrites your stored
properties into observed, persisted ones. Two consequences that bite people: it must be a
`class`, not a `struct` (reference semantics are load-bearing — everyone editing "the same
workout" must hold the same object), and it's automatically `Observable`, so SwiftUI redraws
when a property changes without you doing anything.

**`ModelContainer`** is the database — schema plus the file on disk. You create it once, at the
top of the app. Yours is in `DidWeightsApp`:

```swift
.modelContainer(for: [Exercise.self, SavedWorkout.self, Workout.self])
```

A type that isn't in that list isn't in the schema, and using it throws at runtime.

**`ModelContext`** is your working scratchpad against the container. You `insert`, `delete`, and
mutate through it, and it batches changes and writes them. SwiftUI hands you the main one via
`@Environment(\.modelContext)`. **It autosaves** — for ordinary edits, mutating a model object is
enough and you never call `save()`. This surprises people coming from Core Data.

Be precise about what autosave is, though: it's a periodic flush triggered after changes and at
app lifecycle events, *not* an immediate commit. So it's the right default for incremental UI
edits and the wrong assumption when you need a persistence failure to surface at a particular
point in your code — with autosave you find out later, somewhere else, or not at all. For those
you call `try context.save()` deliberately, which gives you a synchronous commit and an error you
can catch. Note what it does *not* give you: rollback. See M3.

**`@Query`** is a live, observed fetch:

```swift
@Query(filter: ..., sort: \Workout.startDate, order: .reverse)
private var workouts: [Workout]
```

The critical property: it **re-runs automatically** when matching data changes. Insert a row that
matches the predicate and the view updates. You wrote no notification code, no refresh call, no
`objectWillChange`. This is why reads go through `@Query` and not through a repository — see 1.4.

Its limitation: `@Query` is a property wrapper on a `View`, so its parameters are fixed when the
view is initialized. You cannot easily change the predicate from within the same view's body.
That's what the wrapper → content pattern in 1.5 is for.

**`#Predicate`** is also a macro. It compiles your Swift expression into something the *store*
can evaluate. That means it can only contain expressions the predicate system knows how to
translate: comparisons, boolean logic, property access along relationships, and a defined set of
supported operations on strings and collections. It **cannot** contain your own functions or your
model's computed properties, because there is nothing on the store side to run them against. This
trips everyone at least once, and the error message is usually unhelpful. Optionals need care too
— `#Predicate` follows the store's nil semantics, not Swift's, so a force-unwrap inside a
predicate does not mean what it means in ordinary code.

**Relationships** are just properties whose type is another `@Model`:

```swift
var workout: Workout?          // to-one
var sets: [ExerciseSet] = []   // to-many
```

Two things to get right:

- **Inverses.** `@Relationship(inverse: \ExerciseSet.workout)` tells SwiftData that
  `workout.sets` and `set.workout` are two views of one relationship. Declare the inverse on
  exactly one side. Without it you get two independent relationships that silently disagree.
- **Delete rules.** `@Relationship(deleteRule: .cascade)` on `Workout.sets` means deleting a
  workout deletes its sets. The default is `.nullify`, which would leave orphaned sets pointing
  at nothing. Choosing the rule *is* the design decision — think about it per relationship rather
  than copying `.cascade` everywhere.

**Ordering.** A to-many relationship has **no guaranteed order**. `workout.sets` can come back in
any order and that order can change between launches. If order matters — and for sets it very
much does, "set 3" means something — you must store it explicitly and sort by it. This is 1.6.

**Threading.** Model objects belong to the context that fetched them, and the context SwiftUI
gives you is the container's `mainContext`, which is bound to the main actor. So everything in
this app stays on the main actor, and the `@MainActor` annotations you'll see in M3 are about
that binding — not about `ModelContext` being non-`Sendable`, which it isn't; it's declared
`@unchecked Sendable`. The practical rule is the same either way: don't hand a model object to a
background task without reading up on `ModelActor` first.

### 1.4 The repository pattern

A repository is an object that owns the writes for a slice of your domain, exposing operations
in the *language of the domain* rather than the language of the database.

Concretely, the difference between:

```swift
modelContext.insert(workout)              // database language
workout.endDate = .now
```

and:

```swift
try workouts.finish(workout)              // domain language
```

The second one has somewhere to put the rules. "You can't finish a workout that's already
finished." "Finishing drops sets that were never touched." "Finishing stamps the preset's
`lastActive`." In the first version those rules live in whichever view happened to need them —
which is exactly where they live in DidWeights today, spread across `ActiveWorkoutContent`,
`HomeView`, `CreatePlanView`, and `WorkoutManager`.

**What a repository is not:** it is *not* a `save()`/`delete()`/`fetchAll()` wrapper with one
class per model. That pattern is pure ceremony — it adds a layer, moves no logic, and every
method is one line. If a repository method is just forwarding to `modelContext`, ask what rule it
was supposed to be protecting. The value is entirely in the invariants it enforces and the
vocabulary it establishes.

**Why writes but not reads.** This is the part worth actually understanding, because "repository"
in most other ecosystems means both.

Suppose you wrote `func fetchActiveWorkout() -> Workout?` on the repository and a view called it
in `onAppear`. The object you get back is a real `@Model` instance, so it *is* observed — change
its `name` and views holding it redraw. That much is fine.

What isn't observed is **membership**. The fetch answered one question, once: "which workouts
match this predicate right now?" If a workout is inserted, deleted, or stops matching the
predicate, nothing tells your view to ask again. So a repository read is fine for a value you
consume immediately and throw away, and wrong for anything the UI displays over time — you'd end
up rebuilding SwiftUI's change-notification story by hand, which is precisely the mess
`WorkoutManager` is today.

`@Query` doesn't have that problem: it's *observed* at the collection level. It re-runs when
matching data changes — including inserts and deletes — and the view redraws automatically. So:

> **Reads go through `@Query`, because reads need to be live.
> Writes go through repositories, because writes need rules.**

That asymmetry is intentional. It looks lopsided if you've used repositories elsewhere. It's the
right shape here.

**Repositories are cheap.** No stored state beyond the context, so you construct one where you
need it rather than passing it around:

```swift
@Environment(\.modelContext) private var modelContext
private var workouts: WorkoutRepository { WorkoutRepository(context: modelContext) }
```

That's the baseline for this migration. There's a nicer injection story (a custom
`EnvironmentKey`) waiting in M10 — but do it the simple way first, so you can feel what problem
the nicer version solves.

### 1.5 The wrapper → content pattern

You want a screen for *one* workout, driven by live data. But `@Query` returns an array and its
predicate is fixed at view-init. So you split the screen in two:

```swift
struct ActiveWorkoutView: View {          // wrapper: owns the query, holds no UI
    @Query(filter: #Predicate<Workout> { $0.endDate == nil }) private var active: [Workout]

    var body: some View {
        if let workout = active.first {
            ActiveWorkoutContent(workout: workout)
        } else {
            ContentUnavailableView(...)
        }
    }
}

struct ActiveWorkoutContent: View {       // content: owns the UI, takes one live model
    @Bindable var workout: Workout
    ...
}
```

The wrapper's only job is turning "a query that might match nothing" into "definitely one
workout, or a defined empty state." The content view then gets a **live model object** — not a
snapshot. Mutate it and every view holding it updates.

`@Bindable` is what gives you `$workout.name` for a `TextField`. Note where you *don't* need it:
your `WorkoutSetRowView` currently builds manual `Binding(get:set:)` pairs that call back into
`WorkoutManager` to find an index and mutate through it. All of that machinery exists only
because the underlying data is a value type buried in an array. Once a set is a model object,
most of it evaporates.

You already half-built this pattern — `ActiveWorkoutView` → `ActiveWorkoutContent` is exactly the
right shape. It just hands the content view a `Workout` and then renders something else. M7 is
mostly about finishing the thought.

### 1.6 Ordering, and where invariants live

Two ideas that keep recurring in the milestones.

**Ordering must be explicit.** As noted, to-many relationships are unordered. For sets this is
not cosmetic — reps of `[10, 8, 6]` displayed as `[6, 10, 8]` is wrong data as far as the user is
concerned. So `ExerciseSet` carries an `order: Int`, and every read sorts by it. Which
immediately raises: who guarantees `order` is sane? If a view appends a set and picks its own
`order`, two views will eventually pick the same one. So the repository owns it: `addSet` decides
the order, `removeSet` decides whether to renumber.

That's the general shape of an invariant — a rule about your data that must hold no matter which
screen is driving. This app needs at least these:

| Invariant | Where it lives today | Where it belongs |
|---|---|---|
| At most one active workout | Nowhere. Nothing enforces it. | `WorkoutRepository` |
| A set can only be completed with reps > 0 | A `print` in `WorkoutManager.toggleSetCompletion` | `WorkoutRepository` |
| Finishing stamps `endDate` exactly once | Split across two alert branches, incorrectly | `WorkoutRepository` |
| Sets are contiguously ordered within an exercise | Implicit in array position | `WorkoutRepository` |
| Exercise names don't duplicate | Nowhere | `ExerciseRepository` |

Notice the pattern: every invariant currently either doesn't exist or lives in a view. That's the
actual argument for repositories, and it's more convincing than any diagram.

### 1.7 The migration strategy: expand → migrate → contract

The tempting way to do this is to rip out the old models, write the new ones, and fix everything
that breaks. Don't. You'd have a branch that doesn't compile for a week, a diff nobody can
review, and no way to tell which change broke what.

Instead, three phases:

- **Expand.** Rename the old models out of the way (`Workout` → `LegacyWorkout`), then add the
  new schema *alongside* them. Both exist. The app runs on the old one, unchanged.
- **Migrate.** Move one screen at a time onto the new schema. After each screen, the app runs.
- **Contract.** When nothing references the old models, delete them.

The rename in the expand phase is the trick that makes it work: the good names (`Workout`,
`Exercise`) get freed up for the new models, so old and new can coexist without a naming
collision, and you never have a moment where half the app refers to one `Workout` and half to
another.

This isn't a made-up teaching exercise. It's how you'd do it against a live database with real
users, where "just break it and fix it" isn't available. The only difference is scale.

**A note on the data itself.** We are *not* migrating existing on-device data. The new schema
replaces the old one and any workouts currently on your simulator are gone. That's acceptable
because the app isn't released and its only user is you. If it *were* released, deleting user
data would be unacceptable, and M9 would instead be a `VersionedSchema` + `SchemaMigrationPlan`
implementation — see Appendix C for what that would involve. Recognizing which situation you're
in is the skill; assuming you're always in the easy one is how people lose customer data.

---

## Part 2 — The milestones

Every milestone below uses the same template:

> **Goal** — one sentence.
> **Background** — the concept this milestone exists to teach.
> **What to build** — names and signatures. No bodies. That's your half.
> **Deliverable** — what's in the PR.
> **Definition of done** — how we both know it's finished.
> **Traps** — things that will cost you an afternoon if nobody warns you.
> **Questions to answer in the PR** — answer these in the description.

---

### M0 — Read the map, critique the territory

**Goal.** Understand what's wrong with the current design well enough to explain it to someone
else, before changing a line of it.

**Background.** The most common failure mode in a refactor is doing it because someone told you
to. You end up with a mechanical translation that reproduces the original design's problems in
new syntax, because you never internalized what the problems *were*. So: no code in this
milestone. Just make sure the diagnosis is yours and not mine.

**What to build.** Nothing. Write a short document.

**Deliverable.** A PR that adds `docs/M0-critique.md` and nothing else, containing:

1. **Five concrete problems** with the current persistence design. Each one must cite a real file
   and a real symbol — not "it's not scalable" but "`HomeView.WorkoutTemplateCard.exerciseCount`
   performs a full JSON decode inside a computed property." At least two must be problems Part 1
   *didn't* list. They exist; go find them.
2. **The 10× question.** For three of those problems, describe what breaks when the user has 500
   workouts instead of 5. Be specific about the mechanism.
3. **The bug trace.** Walk through §1.2 step by step *in the actual code* and confirm or correct
   it. Then answer both of these, reasoning from the source before you run anything: on a
   freshly installed app, what happens when you tap "Start a Workout" and the sheet appears? And
   if you seed exactly one open `Workout` row and then finish three workouts through the UI, how
   many rows exist afterward and what is each one's `endDate`? Verify both in the simulator. If
   your reasoning and the app disagree, the interesting part is why.
4. **Your schema sketch.** Draw the four new entities and their relationships — on paper, in
   ASCII, in a diagramming tool, doesn't matter. Mark every relationship with its cardinality and
   the delete rule you'd choose. You'll compare this against M2 afterward.

**Definition of done.** The critique is in `main` and we've talked through it.

**Traps.** Don't read ahead to M2 before doing the sketch. Getting it different from mine is
useful; getting it identical because you copied it is not.

**Questions to answer in the PR.**
- Which of the five problems would you fix first if you could only fix one, and why that one?
- `Workout` and `SavedWorkout` have nearly identical shapes (`id`, `name`, a date, a blob). Is
  that duplication a smell, or reasonable? Argue either side, but commit to one.
- Where does `Exercise` get used in the current app? What does the answer tell you?

---

### M1 — Expand: quarantine the legacy schema

**Goal.** Free up the good type names for the new schema without changing a single behaviour.

**Background.** This is the "expand" step from §1.7. It's mechanical and boring, and that's the
point — it should be a pure rename with a diff that any reviewer can verify at a glance. The
value is that it makes every *subsequent* milestone small. A PR that renames and a PR that
changes behaviour are both easy to review; a PR that does both at once is not.

Do the renames with Xcode's refactor tool (right-click → Refactor → Rename), not find-and-replace.
Learning your IDE's refactoring tools properly is worth more over a career than most individual
language features.

**What to build.**

Move to a new `Models/Legacy/` group and rename:

| Current | Becomes |
|---|---|
| `Workout` | `LegacyWorkout` |
| `SavedWorkout` | `LegacySavedWorkout` |
| `Exercise` | `LegacyExercise` |

Leave `LoggedWorkout`, `LoggedExercise`, `WorkoutSet`, and `PersistanceHelper` where they are —
they're going away wholesale in M9 and renaming them buys nothing.

Update the container registration in `DidWeightsApp` to match.

**Deliverable.** One PR containing only renames and file moves.

**Definition of done.**
- The app builds and runs.
- Behaviour is *exactly* what it was before, including the bugs. Specifically, reproduce both
  halves of §1.2: on a clean store, "Start a Workout" presents a blank sheet with no Finish
  button; with one open `Workout` row inserted by hand, the finish path closes the wrong row.
  If either symptom changed in this milestone, you changed behaviour, and that needs explaining.
- Every non-test symbol in the diff is a rename. No logic changes.

**Traps.**
- `@Query` declarations name their type twice — once in `#Predicate<Workout>` and once in the
  sort key path `\Workout.startDate`. Xcode's rename usually gets both; check `HistoryView` and
  `ActiveWorkoutView` by hand anyway.
- `HistoryView` has a `navigationDestination(for: Workout.self)` — a rename here changes routing
  behaviour if you miss it, and it fails silently at runtime rather than at compile time.
- `MonthSection.workouts: [Workout]` is a plain struct property; easy to overlook.
- Preview blocks construct these types too. Previews compile — a missed rename there is a build
  failure, not a runtime one, which is the good case.
- **Deleting the app from the simulator will be necessary.** Renaming an entity changes the
  schema, and SwiftData will refuse to open the old store. That's a preview of exactly the
  problem Appendix C is about — notice how little it takes to break a store.

**Questions to answer in the PR.**
- SwiftData persists an entity under a name. What actually happened to the on-disk store when you
  renamed `Workout`, and what would you have had to do if this app had real users?
- Why rename the legacy types rather than naming the *new* types `WorkoutV2` and skipping this
  milestone? (There's a real answer, and it's about which name is the one that lasts.)

---

### M2 — The new schema

**Goal.** Four normalized `@Model` entities that can express what the app actually needs, with
relationships the database can see through.

**Background.** Normalizing means every fact lives in exactly one place. "This set was 8 reps at
135 lb" is a row. "That set belongs to Tuesday's workout" is a relationship. "That set was Bench
Press" is another relationship, pointing at a *shared* `Exercise` row — which is what finally
makes Monday's bench press and Thursday's bench press the same thing.

**One deliberate simplification.** `CreatePlanView` currently lets each exercise in a plan carry
its own `setCount` (`PlanExerciseDraft.setCount`, a `Stepper` per row). The schema below replaces
that with a single `defaultSetCount` for the whole preset. That is a real, small feature
regression, chosen on purpose: presets become a plain ordered list of exercises, with no join
entity between preset and exercise, and the model stays easy to hold in your head. If per-exercise
set counts turn out to matter, the fix is a `PresetExercise` join model carrying
`exercise`, `order`, and `defaultSetCount` — which would also absorb the `exerciseOrder` array
discussed below. Worth understanding *why* we didn't start there: the join model is the more
capable design and the less obvious one, and reaching for it before you've felt the constraint is
how schemas get complicated. Flag it in your PR if you disagree.

The entities coexist with the legacy ones. Nothing in the UI uses them yet. Resist the urge to
wire anything up; a PR that adds a schema is reviewable, a PR that adds a schema *and* rewrites
three screens is not.

**What to build.**

`Models/Exercise.swift`

```swift
@Model
final class Exercise {
    var id: UUID
    var name: String
    var muscleGroup: String?
    var createdAt: Date

    @Relationship(deleteRule: /* you decide — see Traps */, inverse: \ExerciseSet.exercise)
    var sets: [ExerciseSet]

    init(name: String, muscleGroup: String? = nil)
}
```

`Models/ExerciseSet.swift`

```swift
@Model
final class ExerciseSet {
    var id: UUID
    var order: Int          // position within the *workout*, not within the exercise group;
                            // dense (0, 1, 2, … no gaps) and unique — see M4
    var reps: Int?
    var weight: Double?
    var isCompleted: Bool
    var completedAt: Date?

    var workout: Workout?
    var exercise: Exercise?

    init(order: Int, workout: Workout, exercise: Exercise)
}
```

`Models/Workout.swift`

```swift
@Model
final class Workout {
    var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date?          // nil ⇒ this is the active workout
    var pausedAt: Date?         // non-nil ⇒ currently paused
    var accumulatedPause: TimeInterval

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.workout)
    var sets: [ExerciseSet]

    var preset: WorkoutPreset?

    init(name: String, startDate: Date = .now, preset: WorkoutPreset? = nil)
}
```

`Models/WorkoutPreset.swift`

```swift
@Model
final class WorkoutPreset {
    var id: UUID
    var name: String
    var lastActive: Date?
    var defaultSetCount: Int

    var exercises: [Exercise]
    var exerciseOrder: [UUID]   // see Traps — this is not redundant

    init(name: String, defaultSetCount: Int = 3)
}
```

Plus derived accessors, in extensions, **computed and never stored**:

```swift
extension Workout {
    var isActive: Bool { get }
    var isPaused: Bool { get }
    func elapsed(asOf now: Date = .now) -> TimeInterval
    var orderedSets: [ExerciseSet] { get }
    var exerciseGroups: [ExerciseGroup] { get }
}

struct ExerciseGroup: Identifiable {
    let exercise: Exercise
    let sets: [ExerciseSet]
    var id: UUID { exercise.id }
}

extension WorkoutPreset {
    var orderedExercises: [Exercise] { get }
}
```

`exerciseGroups` is the one to think hardest about. There is no `LoggedExercise` in the new
schema — the grouping of sets under an exercise heading is *derived*: the sets of a workout,
grouped by their `exercise`, with the groups themselves ordered by where each exercise first
appears. Read that twice; it's the single biggest conceptual shift in this migration.

This is why `ExerciseSet.order` is defined **across the whole workout** rather than restarting at
zero for each exercise. If every group's sets were numbered from zero, every group would begin at
`order == 0` and there would be no information anywhere in the schema about which exercise came
first. The user-visible "Set 3" label is then just the set's index *within its group*, computed at
render time — a display concern, not a stored one. Getting this backwards is the most likely way
to end up with a screen whose exercises reshuffle themselves between launches.

Also add a test/preview helper:

```swift
extension ModelContainer {
    static func inMemory(seeded: Bool = false) throws -> ModelContainer
}
```

**Deliverable.** One PR: four new models, the derived extensions, the in-memory container helper,
container registration updated to include both legacy and new entities, and one `#Preview` that
builds a small workout graph in memory and renders it as a plain list — just enough to prove the
graph works.

**Definition of done.**
- App builds and runs; behaviour identical to M1.
- The preview shows a workout with two exercises and several sets, correctly grouped and ordered.
- No UI file outside that preview references the new types.

**Traps.**
- **`Set` is taken.** You'd naturally call this model `Set`, and you'd be shadowing `Swift.Set`
  everywhere in the module — every `Set<String>` would suddenly need `Swift.Set<String>`, and the
  compiler errors would be baffling. Hence `ExerciseSet`. This generalizes: check the stdlib
  before claiming a short, common noun. `Task`, `Result`, `Error`, `Never`, `Range`, `Duration`
  are all landmines.
- **`@Attribute(.unique)` on `id`.** Your legacy models all have it. It isn't free and it usually
  isn't what people think: it makes the field an upsert key, so inserting a second object with
  the same value *overwrites* the first instead of erroring. SwiftData already has its own
  identity. Decide deliberately whether you want it here; either answer is defensible, but say
  which and why in the PR.
- **The `Exercise.sets` delete rule.** `.cascade` means deleting "Bench Press" erases every bench
  press you've ever logged. `.nullify` leaves sets whose exercise is `nil` — every read has to
  handle that. `.deny` refuses the delete while sets exist. Pick one and defend it. This is the
  most consequential single line in the milestone.
- **Why `exerciseOrder` exists.** `exercises: [Exercise]` is a relationship, and per §1.3
  relationships are unordered — the array can come back shuffled. But a preset that reorders
  itself between launches is broken. Since we chose reference-only presets (no join entity),
  order needs its own home: an array of `UUID`s defining the sequence. `orderedExercises` reads
  both and hands back the right answer, so **no caller ever sees the pair** — that encapsulation
  is the entire justification for the slightly awkward representation. Whoever mutates
  `exercises` is responsible for keeping `exerciseOrder` in step; in M8 that becomes
  `PresetRepository`'s job, and nobody else's.
- **Relationship properties can't be `let`,** and non-optional to-one relationships fight you
  during initialization. Default to optional to-one (`var workout: Workout?`) and enforce
  non-nil-ness in the repository instead of the type system. Slightly unsatisfying; it's the
  pragmatic path with SwiftData today.
- **Computed properties cannot appear in `#Predicate`.** `isActive` is for view code only. A
  query must literally say `endDate == nil`. You *will* forget this at least once, in M6.

**Questions to answer in the PR.**
- Justify your `Exercise.sets` delete rule in two sentences.
- `Workout` stores `pausedAt` and `accumulatedPause` but not `elapsed`. Why is elapsed time
  computed rather than stored? What class of bug does that choice make impossible?
- If a workout has three exercises and you delete the middle one's last set, what does
  `exerciseGroups` return, and is that the behaviour a user would expect?
- Compare this schema to your M0 sketch. Where did you differ, and on the points where you
  differ, are you convinced?

---

### M3 — `WorkoutRepository`, part 1: lifecycle

**Goal.** One object that owns starting, pausing, resuming, finishing, and cancelling a workout —
and enforces that only one can be active.

**Background.** This is where §1.4 and §1.6 become concrete. Right now "start a workout" means
different things in `HomeView` (`manager.startWorkout()`), in the preset flow
(`manager.startWorkout(from:)`), and in the database (nothing — no row is ever inserted). After
this milestone there is exactly one definition, it lives in one file, and it's the only way to do
it.

Nothing calls this yet. Build it, test it in M5, adopt it in M7. Writing an API before its callers
exist is a useful discipline: it forces you to design from the domain rather than from whatever
the current view happens to need.

**What to build.**

`Repositories/WorkoutRepositoryError.swift`

```swift
enum WorkoutRepositoryError: Error, Equatable {
    case workoutAlreadyActive
    case multipleActiveWorkouts
    case workoutAlreadyFinished
    case workoutNotActive
    case alreadyPaused
    case notPaused
    case setNotCompletable
    case exerciseNotInWorkout
}
```

`Repositories/WorkoutRepository.swift`

```swift
@MainActor
struct WorkoutRepository {
    private let context: ModelContext

    init(context: ModelContext)

    /// Enforcement + testing only. Views read the active workout with `@Query`.
    /// Throws if more than one open workout exists — see Traps.
    func activeWorkout() throws -> Workout?

    @discardableResult
    func startEmptyWorkout(named name: String, at date: Date = .now) throws -> Workout

    @discardableResult
    func startWorkout(from preset: WorkoutPreset, at date: Date = .now) throws -> Workout

    func pause(_ workout: Workout, at date: Date = .now) throws
    func resume(_ workout: Workout, at date: Date = .now) throws
    func finish(_ workout: Workout, at date: Date = .now) throws
    func cancel(_ workout: Workout) throws
}
```

Every method that reads the clock takes the date as a defaulting parameter. Call sites stay clean
(`try workouts.finish(workout)`), and M5 can drive elapsed-time arithmetic to exact values without
sleeping. Taking time as an input rather than reaching for `.now` inside a function is one of the
cheapest testability habits there is; notice how much it costs here (nothing) versus how much it
would cost to retrofit later.

Behaviour you're implementing:

- `activeWorkout()` — a `FetchDescriptor<Workout>` with predicate `endDate == nil`. Fetch up to
  **two**, not one: if two come back, the single-active-workout invariant has already been
  violated and you want to know, not to silently pick whichever the store returned first.
- `startEmptyWorkout` / `startWorkout(from:)` — throw `.workoutAlreadyActive` if one exists.
  Starting from a preset creates the workout and then `defaultSetCount` empty sets for each of
  the preset's `orderedExercises`, ordered as the preset orders them.
- `pause` / `resume` — `pause` records `pausedAt`; `resume` folds the elapsed paused span into
  `accumulatedPause` and clears `pausedAt`. Guard the wrong-state cases.
- `finish` — resumes first if paused (so a workout doesn't bank time it wasn't running), stamps
  `endDate` **once**, deletes sets that were never touched (no reps, no weight, not completed —
  port the intent of `WorkoutManager.sanitizedForSaving`), **renumbers the survivors so `order`
  stays dense** (M2), and stamps `preset?.lastActive`. See the traps on these.
- `cancel` — deletes the workout entirely. Relies on the cascade rule from M2 to take the sets
  with it; verify that it actually does rather than assuming.

**Deliverable.** One PR: the error type, the repository, lifecycle methods only. No callers.

**Definition of done.** Builds; app behaviour unchanged; every method either performs its
operation or throws a specific error, with no silent no-ops.

**Traps.**
- **`guard ... else { return }` is how the current code handles every failure.** Look at
  `WorkoutManager` — nearly every method silently does nothing when its precondition fails, and
  `toggleSetCompletion` `print`s to a console no user will ever see. The repository must `throw`
  instead. Silent no-ops are the single hardest class of bug to diagnose, because the user's only
  evidence is "I tapped it and nothing happened."
- **`finish` must be idempotent-safe.** Calling it on an already-finished workout should throw
  `.workoutAlreadyFinished`, not re-stamp `endDate`. That's the guard the current code is missing.
- **`lastActive` currently means the wrong thing.** `WorkoutManager.startWorkout(from:)` sets
  `savedWorkout.lastActive = Date()` when a workout *starts*, and `WorkoutTemplateCard` renders it
  as `"Done: …"`. So a plan you started and abandoned reports as done. Put the stamp in `finish`
  and the field finally matches its label — a one-line fix that only became visible because you
  had to decide who owns the write. That's what "invariants need an owner" buys you in practice.
- **Deleting from a cascade relationship while iterating it** will bite you in `finish`. Collect
  the sets to remove first, then delete.
- **Pruning punches holes in `order`.** `finish` deletes untouched sets, and if one of those sat
  in the middle you've left a gap — 0, 1, 3, 4. Nothing breaks *today*, because reading sorts by
  `order` and sorting doesn't care about gaps. It breaks the moment anything reasons about
  position arithmetic, and it makes your M5 assertions inconsistent between "before finish" and
  "after finish". Renumber from zero after pruning, in the same method, so the invariant holds at
  every point a caller can observe.
- **This is where `save()` is legitimate.** Autosave is right for the incremental edits in M4 —
  a rep count changing as the user types. But `finish` is one logical operation: resume, stamp,
  prune sets, stamp the preset. Ending it with `try context.save()` gives you a **commit
  boundary** — a defined point where a persistence failure surfaces attributably, instead of at
  some later flush you can't trace back. Be precise about what that does and doesn't buy you: it
  is not a transaction. Your mutations are already applied to the context before the save runs,
  so a throw means "not persisted", not "nothing changed" — the in-memory objects are still
  modified, and if you need them rolled back you have to say so explicitly. Decide whether this
  app needs that, and say which methods you saved in and why.
- **`@MainActor` on the struct** is deliberate. The context you're handed is the container's
  `mainContext`, which is main-actor bound; annotating up front means the compiler helps you
  later instead of surprising you when you add concurrency.

**Questions to answer in the PR.**
- Why is `activeWorkout()` on the repository at all, given §1.4 says reads go through `@Query`?
  What would go wrong if `ActiveWorkoutView` called it instead of querying?
- `finish` deletes untouched sets. Is that right? Make the argument for *not* deleting them.
- What happens if `pause` is called on a workout that's already finished? Does your
  implementation handle it, and if not, does it need to?
- Why a `struct` rather than a `class`? What would change if it held state?
- Which methods did you call `save()` in, and what would you actually observe if you removed it?

---

### M4 — `WorkoutRepository`, part 2: composition

**Goal.** The rest of the write surface: adding and removing exercises and sets, editing them,
and completing them.

**Background.** M3 covered the workout's lifecycle. This is its *contents* — and it's where the
flat schema earns its keep and also where it costs you something. Compare each method here to its
`WorkoutManager` counterpart: the current versions all begin by hunting for an array index
(`exerciseIndex(for:)`, `setIndex(exerciseIndex:setID:)`), and several force-unwrap
`activeWorkout!` afterward. Once sets are model objects with real relationships, you pass the
object. All the index arithmetic — and every crash lurking in it — disappears.

**What to build.**

```swift
extension WorkoutRepository {
    @discardableResult
    func addExercise(_ exercise: Exercise, to workout: Workout, setCount: Int) throws -> [ExerciseSet]

    func removeExercise(_ exercise: Exercise, from workout: Workout) throws

    @discardableResult
    func addSet(to workout: Workout, exercise: Exercise) throws -> ExerciseSet

    func removeSet(_ set: ExerciseSet) throws
    func removeLastSet(of exercise: Exercise, in workout: Workout) throws

    func updateSet(_ set: ExerciseSet, reps: Int?, weight: Double?) throws
    func toggleCompletion(of set: ExerciseSet) throws
}
```

Behaviour:

- `addExercise` — creates `setCount` empty sets for that exercise, ordered after everything
  already in the workout.
- `removeExercise` — deletes every set of that exercise in that workout, then renumbers.
- `addSet` — appends one set to that exercise's group. It decides the `order`; nothing else may.
- `removeSet` / `removeLastSet` — delete and renumber.
- `updateSet` — writes reps and weight. Consider: if a set is already completed and the user
  clears its reps, is it still completed?
- `toggleCompletion` — un-completing is always allowed; completing requires reps > 0, else throw
  `.setNotCompletable`. Set `completedAt` alongside `isCompleted` and keep the two consistent.

**Deliverable.** One PR: the composition extension. Still no callers.

**Definition of done.** Every mutation `WorkoutManager` can perform has a repository equivalent
that is at least as strict, with the exception of `updateExerciseName` — that one becomes
`ExerciseRepository.rename` in M7, because in the new schema a name belongs to the catalog entry,
not to one workout's copy of it.

**Traps.**
- **An exercise with zero sets cannot exist.** This is the price of the flat schema. Today
  `manager.addExercise()` adds an empty, *unnamed* exercise row and the user names it and adds
  sets afterward. In the new model there's no row to add — an exercise is present in a workout
  only by virtue of having sets. So `addExercise(..., setCount: 0)` silently does nothing, and
  `removeLastSet` on a one-set exercise makes the exercise disappear from the screen. Decide
  what the right behaviour is (reject `setCount < 1`? refuse to remove the last set? let it
  vanish?) and note it in the PR. There is no free answer here; every option trades something.
- **This changes the "Add Exercise" UX** in M7. Today you get an empty row with a text field. In
  the new model you must pick or name the exercise *first*, because you can't create sets without
  one. That's a UI change falling out of a data-model change — worth noticing that the two are
  never as separable as people claim.
- **Renumbering.** `order` is workout-global (M2) and **dense**: 0, 1, 2, 3 with no gaps,
  renumbered after every insert or delete. Sparse ordering with gaps sounds cheaper, but adding a
  set to the *first* of three exercises has to place it inside that exercise's block and after
  its existing sets, which means shifting everything downstream regardless — and gaps eventually
  run out, at which point you need rebalancing logic nobody wants to own. At this scale, "renumber
  the workout's sets" is a few dozen integers. Take the simple one.
- **`order` values must be unique within a workout.** Two sets sharing an order makes group
  ordering ambiguous, and the bug will look like "the exercises swapped places sometimes." Your M5
  tests should assert uniqueness directly, and should cover the middle-insertion case above.
- **`updateSet` will be called on every keystroke.** Make sure it does no work proportional to
  the size of the workout.

**Questions to answer in the PR.**
- What did you decide about zero-set exercises, and what does the user see as a result?
- `toggleCompletion` throws when reps are missing. The current code `print`s and returns. What
  should the *UI* do with that thrown error in M7 — and is throwing even the right design here,
  versus disabling the button? (`extension+WorkoutSet.canBeCompleted` was reaching for the second
  answer; it's currently dead code — nothing calls it.)
- Which `WorkoutManager` method has no equivalent here, and why is its absence correct?

---

### M5 — Prove it: the test target

**Goal.** A test suite that exercises `WorkoutRepository` against a real SwiftData store, in
memory, with no UI.

**Background.** This is the milestone where the repository pattern pays for itself, and it's worth
being explicit about why.

Ask how you'd test the current code. "Finishing a workout stamps `endDate` exactly once" is a
rule that currently lives in an `.alert` closure inside `ActiveWorkoutContent`. To test it you'd
have to instantiate a SwiftUI view, inject an `@Observable` object that reads `UserDefaults` in
its initializer, simulate a tap, and inspect a database. Nobody does that, which is precisely why
that code has the bug in §1.2 — it was never testable, so it was never tested.

Now the same rule is `WorkoutRepository.finish(_:)`. Three lines of setup, call it, assert. The
logic became testable the moment it stopped living in a view. **That is the actual argument for
this architecture** — not layering, not purity. Testability, and the design pressure that
testability applies.

The in-memory container is what makes it fast: `ModelConfiguration(isStoredInMemoryOnly: true)`
gives you a real store with real predicates and real cascade rules, built and destroyed per test,
touching no disk. You already used this trick in the `HistoryView` preview — same idea, better
purpose.

**What to build.**

A new unit test target, `DidWeightsTests`. Use **Swift Testing** (`@Test` / `#expect`) rather than
XCTest — it's the current direction and the ergonomics are better.

`DidWeightsTests/WorkoutRepositoryTests.swift`

```swift
@MainActor
struct WorkoutRepositoryTests {
    private func makeSUT() throws -> (WorkoutRepository, ModelContext)
}
```

Cases you must cover:

*Lifecycle*
- Starting an empty workout inserts exactly one `Workout` with `endDate == nil`.
- Starting a second workout while one is active throws `.workoutAlreadyActive` — and leaves the
  original untouched. Assert both halves; "it threw" is only half the guarantee.
- Starting from a preset creates `defaultSetCount` sets per preset exercise, in the preset's
  order.
- `finish` stamps `endDate`, and the workout stops matching the active predicate and starts
  matching the history one. Assert via an actual fetch, not by reading the property — you're
  testing that the *query* behaves, since that's what the UI depends on.
- `finish` stamps `lastActive` on the originating preset, and *starting* one does not. This is
  the pre-existing "Done:" bug from M3's traps; pin it with a test so it can't come back.
- `finish` on an already-finished workout throws and does not move `endDate`.
- `finish` prunes untouched sets **and leaves the survivors densely ordered from zero**. Build a
  workout whose untouched set sits in the middle, so a missing renumber shows up as a gap.
- `cancel` removes the workout **and** its sets. Fetch `ExerciseSet` afterward and assert zero.
  This is your proof that the cascade rule from M2 is actually configured correctly.
- Pause arithmetic: start, pause, resume, and assert `elapsed(asOf:)` excludes the paused span.
  Inject the dates rather than sleeping — a test that sleeps is a test people delete.
- `pause` on a paused workout throws; `resume` on a running one throws.

*Composition*
- `addSet` assigns increasing `order` values, and no two sets in a workout ever share one. Assert
  uniqueness explicitly — this is the invariant that keeps `exerciseGroups` from reshuffling.
- `addSet` on the **first** of three exercises places the new set at the end of that exercise's
  block and shifts everything after it, leaving order dense and group order unchanged. This is
  the case that breaks naive "append with order = sets.count" implementations.
- `removeSet` leaves the remaining sets densely ordered from zero.
- Two workouts open at once (insert the second by hand, bypassing the repository) makes
  `activeWorkout()` throw `.multipleActiveWorkouts` rather than silently returning one of them.
- `toggleCompletion` on a set with `reps == nil` throws `.setNotCompletable` and leaves
  `isCompleted == false`.
- `toggleCompletion` on a set with valid reps completes it and sets `completedAt`; toggling again
  un-completes it.
- `removeExercise` deletes only that exercise's sets in that workout, and leaves an identical
  exercise's sets in a *different* workout alone. This one catches predicate mistakes nothing
  else will.

*Derived accessors*
- `exerciseGroups` groups correctly and orders groups by first appearance.
- `orderedSets` respects `order` even when the relationship array is shuffled. Construct the
  shuffled case deliberately; don't wait to encounter it.

**Deliverable.** One PR: test target plus the suite above, green.

**Definition of done.** `⌘U` passes. Every test builds its own container — no shared state
between tests, no ordering dependency. Then: deliberately break one repository invariant, watch a
test fail, and revert. A suite you've never seen fail is not evidence of anything.

**Traps.**
- **Adding a test target to an existing project** means checking the target membership of your
  model and repository files, and importing the app module (`@testable import DidWeights`).
  This is fiddly the first time and routine forever after.
- **`@MainActor` on the test type** — your repository is main-actor-isolated, so the tests must be
  too, or you'll fight the concurrency checker instead of writing tests.
- **Don't test SwiftData.** `#expect(workout.name == "Push Day")` right after setting it tests
  Apple's code. Test *your* rules: the guards, the ordering, the cascades, the derived values.
- **Don't reuse one container across tests.** Leaked state between tests produces failures that
  depend on run order, and those cost hours.
- **Assert the negative space.** For every "it throws" test, also assert nothing changed. Most
  real bugs are partial writes — the operation failed halfway and left the store inconsistent.

**Questions to answer in the PR.**
- Pick one test and describe the bug it would have caught in the *current* codebase.
- Which was harder to test, lifecycle or composition, and what does that tell you about which
  part of the API is better designed?
- What's still untested after this milestone, and how would you get at it?

---

### M6 — First read path: history

**Goal.** History and workout detail read the new schema through `@Query` and `#Predicate`, with
no decoding anywhere.

**Background.** First milestone that changes what the user sees. It's deliberately the *safest*
screen: read-only, no mutations, and it's the one where the payoff is most visible — the entire
`PersistanceHelper` round-trip vanishes and is replaced by relationship traversal.

It's also where the wrapper → content pattern from §1.5 earns its place, for a reason that isn't
obvious. `HistoryView` currently does `navigationDestination(for: Workout.self)` and hands the
model object straight to `WorkoutDetailView`. With SwiftData that's *nearly* fine — the object is
live, so edits propagate. But consider: the detail screen is open, and the workout gets deleted.
The detail view is now holding a deleted model object, and touching its properties is undefined
behaviour at best. Navigating by **identifier** and re-querying in a wrapper means deletion
resolves to "not found" and you show an empty state instead of crashing. That's the judgment call
the pattern encodes: pass the object when the lifetime is obviously contained, query by ID when
it isn't.

**What to build.**

`HistoryView` — `@Query` over the new `Workout`:

```swift
@Query(
    filter: #Predicate<Workout> { $0.endDate != nil },
    sort: \Workout.startDate,
    order: .reverse
)
private var pastWorkouts: [Workout]
```

Keep `MonthSection` and the grouping, retargeted at the new type. Add a per-row summary — set
count and total volume — now that it's a relationship traversal rather than a JSON decode:

```swift
extension Workout {
    var completedSetCount: Int { get }
    var totalVolume: Double { get }   // Σ reps × weight over completed sets
}
```

`WorkoutDetailView` — split into wrapper and content:

```swift
struct WorkoutDetailView: View {           // wrapper
    private let workoutID: UUID
    @Query private var matches: [Workout]

    init(workoutID: UUID)                  // build the @Query in here — see Traps
}

private struct WorkoutDetailContent: View { // content
    let workout: Workout
}
```

The content view renders `workout.exerciseGroups` — a section per exercise, a row per set — with
no decoding.

Route by ID: `navigationDestination(for: UUID.self)`, or a small `Hashable` route enum if you
prefer being explicit, which you should.

**Deliverable.** One PR: `HistoryView` and `WorkoutDetailView` on the new schema, with the
summary extensions.

**Definition of done.**
- Neither file imports or references `PersistanceHelper`, `LoggedWorkout`, or `LegacyWorkout`.
- **History will be empty, and that's the expected outcome of this milestone.** Every writer still
  writes legacy rows; nothing writes the new schema until M7. This is the temporary regression
  ground rule 2 allows — named, understood, and closed out one milestone later. Say so in the PR
  so a reviewer doesn't think you shipped a broken screen.
- Because you can't verify against live data, verify against a seeded in-memory preview: several
  workouts across at least two months, grouped and sorted correctly.
- Deleting a workout while its detail screen is open shows the empty state rather than crashing.
  Test this; it's the whole reason for the wrapper.

**Traps.**
- **Building a `@Query` from an init parameter** requires initializing the property wrapper
  explicitly in `init`: `_matches = Query(filter: #Predicate<Workout> { $0.id == workoutID }, ...)`.
  You can't reference `self` in a property initializer, so it has to happen in the body of the
  init. The underscore-prefixed form is unfamiliar the first time; it's just the wrapper's
  storage.
- **Capturing a value in a `#Predicate`** works, but the captured value must be a simple
  `Sendable` type — a local `let workoutID: UUID`, not `self.workoutID` and not a computed
  property. Bind it to a local first.
- **`#Predicate` and optionals.** `$0.endDate != nil` is fine. Anything more involved
  (`$0.endDate! > date`) is not — force-unwrapping inside a predicate doesn't mean what it means
  in Swift, because the predicate is translated, not executed. Restructure with explicit nil
  checks.
- **Don't put `isActive` in a predicate.** It's computed. §1.3 warned you; this is where it
  happens.
- **`totalVolume` over `reps × weight` with two optionals** — decide what a set with reps but no
  weight (bodyweight pull-ups, which your own preview data has) contributes. Zero is a defensible
  answer; so is excluding it. Silently producing `0` because `nil ?? 0` happened to be the easiest
  thing to type is not.
- **Sorting `MonthSection` by a `"2026-7"` string key** is a pre-existing bug you'll carry over if
  you're not careful: `"2026-7" > "2026-12"` lexicographically. Fix it while you're here — zero-pad
  the month or sort by a real `Date`. Good example of a bug that survives a rewrite because
  nobody re-read the line they were moving.

**Questions to answer in the PR.**
- `totalVolume` iterates every set of a workout. `HistoryView` renders many workouts. Is that a
  problem? At what number of workouts does it become one, and how would you find out rather than
  guess?
- Why can't `#Predicate` call a Swift function? Answer in terms of where the predicate actually
  runs.
- You now navigate by `UUID` instead of by `Workout`. What did that cost, and what did it buy?

---

### M7 — The active workout, end to end

**Goal.** The live session runs entirely on the new schema: `@Query` for reads,
`WorkoutRepository` for every write, no in-memory mirror, no `UserDefaults`.

**Background.** The big one. This is where the second source of truth from §1.2 dies and the
bugs die with it — not because you fixed them individually, but because you removed the condition
that produced them. Worth savouring: you will delete more code than you write.

Note the scope: "the active workout" means the whole path, not one file. `HomeView`'s **Start a
Workout** button is what puts a workout on screen, so it has to move in this milestone too — leave
it calling `manager.startWorkout()` and the new `@Query` will match nothing and you'll have
rebuilt §1.2's blank sheet with better types. Only `HomeView`'s *preset* handling waits for M8.
Deciding where a milestone's boundary actually falls is part of the exercise: it's the boundary of
a working feature, not the boundary of a file.

You also need somewhere to get an `Exercise` from, since sets can't exist without one — so
`ExerciseRepository` lands here rather than in M8. A write path that can't create its own operands
isn't a write path.

Two things to watch as you go. First, the manual `Binding(get:set:)` pairs in `WorkoutSetRowView`
that call `manager.updateWeight(exerciseID:setID:weight:)` — those exist only because a
`WorkoutSet` is a value type inside an array inside another array, so there's no way to hand a
view a reference to one. Once a set is a model object, `@Bindable` gives you `$set.weight` and the
whole apparatus goes away. Second, `ActiveWorkoutContent` currently takes a `Workout` and then
renders `manager.activeWorkout` instead. You already built the right structure; it just wasn't
wired to anything. Finish the thought.

**What to build.**

Wrapper:

```swift
struct ActiveWorkoutView: View {
    @Query(
        filter: #Predicate<Workout> { $0.endDate == nil },
        sort: \Workout.startDate, order: .reverse
    )
    private var activeWorkouts: [Workout]
}
```

Three cases, not two: none, exactly one, and more than one. `activeWorkouts.first` quietly
collapses the third into the second, which is precisely the habit that let §1.2's duplicate open
rows go unnoticed for so long. The invariant says the third case can't happen; the wrapper is
where you find out whether the invariant is true. Render something explicit — even a plain
diagnostic — rather than picking one at random.

Content, and its subviews, retargeted:

```swift
struct ActiveWorkoutContent: View {
    @Bindable var workout: Workout
    @Environment(\.modelContext) private var modelContext
    private var workouts: WorkoutRepository { WorkoutRepository(context: modelContext) }
}

struct ExerciseGroupView: View {    // was ExerciseRowView
    let group: ExerciseGroup
    let workout: Workout
}

struct ExerciseSetRowView: View {   // was WorkoutSetRowView
    @Bindable var set: ExerciseSet
    let index: Int
}
```

`WorkoutHeaderView` takes a `Workout`. `WorkoutTimerView` needs to change shape: it currently
takes a `startDate` and formats `context.date.timeIntervalSince(start)` inside a `TimelineView`.
Give it the workout (or a `(Date) -> TimeInterval` closure) so it can call `elapsed(asOf:)` with
`TimelineView`'s per-tick date — passing in a `TimeInterval` computed once by the parent would
freeze the clock, since the parent isn't re-evaluated every second. That's the first user-visible
benefit of the pause model, before there's even a pause button.

The exercise catalog, needed so sets have something to point at:

```swift
@MainActor
struct ExerciseRepository {
    private let context: ModelContext
    init(context: ModelContext)

    @discardableResult
    func findOrCreate(name: String, muscleGroup: String? = nil) throws -> Exercise

    func rename(_ exercise: Exercise, to name: String) throws
    func delete(_ exercise: Exercise) throws
}
```

And `HomeView`'s quick-start path — the button labelled "Start a Workout" / "Resume Workout" —
moves onto `WorkoutRepository`. Its label currently keys off `manager.activeWorkout == nil`; it
now keys off a `@Query` for `endDate == nil`, which is the same question asked of the one place
that actually knows.

**The preset grid's "Start Workout" action must be disabled in this milestone.** Not left
working — *disabled*. `WorkoutRepository.startWorkout(from:)` takes a `WorkoutPreset`, and no
`WorkoutPreset` rows exist until M8; the plans on screen are still `LegacySavedWorkout`. If you
leave that button calling `manager.startWorkout(from:)`, it writes a `UserDefaults` draft that the
new `ActiveWorkoutView` can't see, and you've faithfully rebuilt §1.2's blank sheet on top of the
new schema. Grey the action out with a short "coming back in the next change" note, name the
regression in your PR, and restore it in M8. The plans themselves keep *rendering* — that's a
`@Query` over `LegacySavedWorkout` feeding `WorkoutTemplateCard`, and it never needed the manager.

Sitting with that for a second is worthwhile: the reason preset-start can't come along is that
it depends on an entity two milestones away. Noticing that a slice you thought was independent
has a dependency you can't satisfy yet — and choosing to disable rather than bodge a bridge — is
most of what incremental migration actually consists of.

**Unwire `WorkoutManager` completely here, but don't delete the file.** `HomeView` and
`ActiveWorkoutView` are the only two views that read it, and this milestone migrates both — so
by the end of it every `@Environment(WorkoutManager.self)` should be gone, along with
`ContentView`'s `@State private var manager` and the `.environment(manager)` that injects it, and
the `WorkoutManager()` each of the `#Preview` blocks constructs. Leaving the construction in
`ContentView` "because M8 deletes the class anyway" would keep the object alive, and its
initializer is what restores the `UserDefaults` draft — the second source of truth would survive
the milestone that was supposed to end it. Unwire now; delete the file in M8.

**Write rule for this milestone: every mutation goes through the repository.** Including
reps and weight. You will notice that those two have no invariant attached and that
`@Bindable`'s `$set.reps` would work directly — that's a real observation and the right instinct.
We're routing everything through the repository here anyway, for two reasons: consistency while
the pattern is new, and because "which writes are allowed to bypass the repository" is a genuinely
subtle policy that's easier to decide once you've felt the cost of the strict version. Raise it in
your PR and we'll talk about where the line should sit. Do not quietly mix both.

**Deliverable.** One PR: `ActiveWorkoutView` and its subviews on the new schema,
`ExerciseRepository`, `HomeView`'s quick-start path, and `WorkoutManager` unwired from the entire
view tree — the class still compiles, but nothing constructs, injects, or reads it.

**Definition of done.**
- From `HomeView`: start an empty workout, add exercises and sets, enter reps and weight, complete
  sets, finish. **The workout appears in History with correct data** — which also retires M6's
  temporary blank-history regression. Confirm the whole flow before opening the PR; this is the
  first milestone where the app is genuinely better than it was.
- Starting from a plan is visibly disabled, and that regression is named in the PR. It comes back
  in M8.
- Cancel deletes the workout and its sets — verify by fetching, not just visually.
- Force-quit mid-workout and relaunch: the session is still there, because it's a database row
  now and nothing had to be "restored."
- Starting a second workout while one is active is impossible from the UI — the button says
  Resume. The repository would throw anyway; both layers should agree.
- Nothing in the active-workout path touches `UserDefaults`, `PersistanceHelper`, or
  `manager.activeWorkout`. `grep -r WorkoutManager` over the app source returns hits in
  `WorkoutManager.swift` and nowhere else.

**Traps.**
- **"Add Exercise" needs redesigning**, per M4's trap. You can't create a nameless exercise and
  fill it in later — sets need an `Exercise` to point at. Simplest version that preserves the
  feel: a sheet listing existing `Exercise` rows (a `@Query`) with a "create new" field at the
  top, resolving through `ExerciseRepository.findOrCreate`. Keep it plain.
- **The empty state matters more than you think.** `activeWorkouts.first == nil` is now the
  normal case — no active workout is the resting state of the app. Handle it deliberately rather
  than as an afterthought. The current code's missing `else` branch (§1.2, step 2) is what that
  looks like when you don't.
- **`@Bindable` on a model that gets deleted** while the view is on screen is the same hazard as
  M6. The wrapper protects you as long as the content view is genuinely driven by the query
  result. Don't stash the workout in `@State`.
- **Errors now exist.** `toggleCompletion` throws. `try?` here would recreate exactly the silent
  failures §1.1 complained about. Surface it in an alert, or prevent the state by disabling the
  button. Decide which and say why.
- **Don't port `canBeCompleted` as written.** It's the dead extension on `WorkoutSet`, and it
  requires `reps > 0 && weight > 0` — so under that rule a bodyweight pull-up can never be
  completed, and your own `WorkoutDetailView` preview data contains exactly that case. The
  repository's rule is reps only. If you want the disable-the-button approach, write a fresh
  `ExerciseSet` property that matches the repository, and don't let two different definitions of
  "completable" exist in the app.
- **Focus.** `WorkoutSetRowView` applies `.focused($focusedField, equals: workSet.id)` to *both*
  the weight and the reps field, so they share a focus identity and "next field" can't work. It's
  a pre-existing bug; fix it while you're in here, using a `Hashable` enum
  (`enum Field: Hashable { case reps(UUID), weight(UUID) }`) rather than a bare `UUID`.
- **`findOrCreate` needs a matching rule.** Is "bench press" the same exercise as "Bench Press"?
  As "Bench  Press" with two spaces? Trim and case-fold, and be aware that `#Predicate` string
  comparison is more limited than `String` comparison — you may need to store a normalized field
  alongside the display name and match on that. That's a legitimate technique, not a hack.
- **`findOrCreate` has a race in principle** (fetch, miss, insert). Single-threaded and
  main-actor-bound, you're fine. Know that you're relying on that, rather than not noticing it.
- **Don't construct a new repository inside a `ForEach` body.** It's cheap, not free, and the
  computed-property form on the view is clearer. M10 improves this.

**Questions to answer in the PR.**
- What's your name-matching rule for `findOrCreate`, and what pair of names does it wrongly
  consider different?
- Roughly how many lines did you delete versus add? Where did the deletions concentrate?
- Force-quit mid-workout now works with no restore code at all. Where did that behaviour come
  from?
- Make the case for letting `$set.reps` bind directly to the model instead of going through
  `updateSet`. Then make the case against. Which do you actually want, and what rule would you
  write down so the next person doesn't have to re-derive it?
- Which of the seven symptoms in §1.2 are now structurally impossible, as opposed to merely fixed?

---

### M8 — Presets

**Goal.** Plans become `WorkoutPreset`s over the `Exercise` catalog — and `WorkoutManager` is
deleted.

**Background.** The catalog you built in M7 is what the whole migration was for. Once "Bench
Press" is one row that many sets point at, every question you actually want to ask becomes a
query: every set you've ever done of it, your best weight, whether you've trained it this week.
None of that is in scope here, but all of it becomes *possible* here, and that's worth noticing —
good data models make features cheap, and the features you never build are usually the ones the
model made expensive.

This milestone is also where the last of the old architecture stops being load-bearing. When
`HomeView` and `CreatePlanView` are on repositories, the `WorkoutManager` file M7 left orphaned
gets deleted — a class you spent real effort on. That's a normal and healthy outcome, not wasted
work: it did its job, the job changed.

**What to build.**

`Repositories/PresetRepository.swift`

```swift
@MainActor
struct PresetRepository {
    private let context: ModelContext
    init(context: ModelContext)

    @discardableResult
    func create(name: String, exercises: [Exercise], defaultSetCount: Int) throws -> WorkoutPreset

    func update(
        _ preset: WorkoutPreset,
        name: String,
        exercises: [Exercise],
        defaultSetCount: Int
    ) throws

    func delete(_ preset: WorkoutPreset) throws
}
```

`PresetRepository` is the sole owner of the `exercises` / `exerciseOrder` invariant from M2. Every
method that touches one touches the other. Nothing outside this file sets either. Note there's no
`markUsed` — `lastActive` is stamped by `WorkoutRepository.finish` (M3), because it means "last
completed", and having two repositories able to write it is how the current "Done:"-label bug
happened in the first place.

Screens:

- **`HomeView`** — `@Query` over `WorkoutPreset` replaces the `SavedWorkout` query.
  `WorkoutTemplateCard.exerciseCount` becomes `preset.exercises.count`; delete the decode. Start
  from plan calls `WorkoutRepository.startWorkout(from:)`. Delete goes through `PresetRepository`,
  not `modelContext.delete`.
- **`CreatePlanView`** — `PlanExerciseDraft` keeps its role as local editor state, but drops its
  per-exercise `setCount` stepper in favour of one `defaultSetCount` for the plan (M2's deliberate
  simplification). On save, each draft name resolves through `ExerciseRepository.findOrCreate` and
  the preset is written by `PresetRepository`. No `modelContext` in this file.

Then delete `WorkoutManager.swift` and the `"com.didweights.activeWorkoutDraft"` key. M7 already
unwired every reference, so this should be a file deletion and nothing else — if it isn't, M7 was
incomplete and that's worth knowing.

**Deliverable.** One PR: `PresetRepository`, `HomeView` and `CreatePlanView` migrated,
`WorkoutManager` gone.

**Definition of done.**
- Create a plan, start a workout from it, finish it, see it in history, and see the plan's
  "Done:" date update — *on finish*, not on start.
- **Starting from a plan works again**, closing M7's named regression.
- Creating two plans that both use "Bench Press" produces **one** `Exercise` row. Verify by
  fetching, not by squinting at the UI.
- `grep -r UserDefaults` over the app source returns nothing.
- `grep -r "modelContext.insert\|modelContext.delete"` returns nothing outside `Repositories/`.
  That grep is the actual, enforceable statement of this architecture — the rest is commentary.

**Traps.**
- **`rename` is now global.** Renaming an `Exercise` changes it in every past workout, because
  there's only one row. That's usually what you want and occasionally horrifying. Note the
  consequence.
- **`delete` collides with your M2 delete-rule decision.** If you chose `.deny`, this method has
  to surface that refusal. If `.cascade`, it silently destroys history. This is where that choice
  becomes visible — go back and check you still agree with it.
- **Editing a plan's exercises is where `exerciseOrder` gets dangerous.** `update` has to rewrite
  both the relationship and the order array, consistently, including when the user removes an
  exercise that's still referenced in the array. Every path through that method needs the same
  discipline.
- **The `WorkoutManager` dependency spread further than you'd guess.** `ContentView`, `HomeView`,
  `ActiveWorkoutView` and `HistoryView` all construct or inject one today — including
  `HistoryView`, which never actually *reads* it, and whose `#Preview` builds a `WorkoutManager`
  purely out of habit. You'll have unpicked all of that in M6 and M7, so the deletion here should
  be quiet. Take a moment to look at how far a single shared object had reached before it went.
- **Order the work: `PresetRepository`, then `CreatePlanView`, then `HomeView`, then the
  deletion.** Deleting `WorkoutManager` first means a non-building tree for the rest of the
  milestone, which violates ground rule 2.

**Questions to answer in the PR.**
- Presets store `exercises` plus `exerciseOrder`. What breaks if some future code appends to
  `exercises` without touching `exerciseOrder`? How would you make that mistake harder — or is
  documenting it enough? Would a `PresetExercise` join model have been the better call after all?
- Now that `Exercise` is shared, name two features that became easy. Pick the one you'd build
  next and say what query it needs.
- What was `WorkoutManager` actually responsible for, and where did each of those
  responsibilities end up?
- `CreatePlanView` lost its per-exercise set counts. Did any user-visible value go with them?

---

### M9 — Contract: delete the legacy layer

**Goal.** Remove every trace of the blob architecture.

**Background.** The "contract" step from §1.7, and the one people skip. A migration that leaves
the old system in place hasn't reduced complexity — it's doubled it, and now every new engineer
has to figure out which of the two is real. Dead code is not free: it gets read, it gets copied,
it shows up in searches, and eventually somebody adds a feature to it.

You may feel reluctant to delete working code. Git has it. Delete it.

**What to build.** Nothing. Delete:

| File | Note |
|---|---|
| `Models/Legacy/LegacyWorkout.swift` | |
| `Models/Legacy/LegacySavedWorkout.swift` | |
| `Models/Legacy/LegacyExercise.swift` | |
| `Models/Codable/LoggedWorkout.swift` | |
| `Models/Codable/LoggedExercise.swift` | |
| `Models/Codable/WorkoutSet.swift` | |
| `extension+WorkoutSet.swift` | `canBeCompleted` — dead today; if M7 revived the idea, it belongs on `ExerciseSet` now |
| `Persistance/PersistanceHelper.swift` | takes `SerializationError` with it |
| `Views/TempWorkoutData.swift` | `tempWorkouts`, `WorkoutTemplate`, `sampleTemplates` — all three are referenced by nothing; verify with a search before deleting, and notice how long they've been sitting there |

Then strip the legacy types from `.modelContainer(for:)` in `DidWeightsApp`, and while you're in
that file, delete the stale comment block at the bottom (`/** Make a rootView ... */`) — it
describes a plan that M7 actually implemented, better than the note did.

**Deliverable.** One PR that is almost entirely deletions.

**Definition of done.** All of these return nothing across the app source:

```
workoutData        PersistanceHelper      LoggedWorkout      LoggedExercise
UserDefaults       Legacy                 .externalStorage   WorkoutManager
```

Full test suite green. Delete the app from the simulator, relaunch, and run a complete flow from
a clean store: create a plan → start from it → log sets → finish → history → detail.

**Traps.**
- **Delete the app from the simulator.** The container no longer declares the legacy entities and
  the old store won't open. Expect it, and note that a released app could not do this.
- **Previews are the usual stragglers.** `HistoryView` and `WorkoutDetailView` both have preview
  blocks that build `LoggedWorkout` graphs and encode them. Rewrite them against
  `ModelContainer.inMemory` from M2 — good previews are worth keeping, and these will finally be
  short.
- **Xcode "Remove Reference" vs. "Move to Trash."** The first leaves the file on disk and in the
  repo, contributing nothing but confusion. Check `git status` afterward.

**Questions to answer in the PR.**
- How many lines did the whole migration net, across M1–M9?
- Anything you were tempted to keep? What was the argument for keeping it, and why didn't it win?
- The store is now unopenable by the old build. List everything that would have needed to be true
  for this to be safe with real users on the App Store.

---

### M10 — Stretch

Not required. Pick one if you want to keep going — each is small, and each teaches something the
required milestones only gestured at.

**a) Repository injection via `EnvironmentKey`.** Every view currently does
`WorkoutRepository(context: modelContext)` in a computed property. It works, but the construction
is repeated and views can't be handed a different implementation. Define an environment key and
inject once:

```swift
extension EnvironmentValues {
    var workoutRepository: WorkoutRepository { get set }
}
```

Do this *now*, not in M3, so you can compare and articulate what it actually bought — that
comparison is the exercise, not the code.

**b) Per-exercise history.** A screen showing every set of a given exercise across all workouts,
newest first. It's one `@Query` with a predicate on the exercise relationship, and it's flatly
impossible in the old schema. Building it is the most direct way to feel what normalization was
for.

**c) Pause and resume in the UI.** `WorkoutRepository` has supported it since M3 and nothing calls
it. Wire up a button and make `WorkoutTimerView` honour `elapsed(asOf:)`.

**d) Derived stats.** Volume per workout, per week, per muscle group; a personal-record query per
exercise. Watch how much of this is a predicate and a `reduce` rather than new storage — and
resist the urge to add a `personalRecord` field to `Exercise`. Denormalizing is a decision you
make when you've measured a problem, not before.

**e) Set templates from history.** `SetHeaderView` declares a "Previous" column and every row in
`WorkoutSetRowView` fills it with a hardcoded `—`. Fill it in for real: the same set index from
the last time that exercise was performed. It's a
genuinely useful lifting-app feature, it's now a straightforward query, and it's the clearest
possible demonstration of the point: the feature didn't get easier because you got better at
SwiftUI. It got easier because the data model changed.

---

## Part 3 — Reference

### Appendix A — The rules, condensed

**Reads**

| Situation | Do this |
|---|---|
| A list of things | `@Query` with a `#Predicate` and a sort |
| One thing, lifetime obviously contained | Pass the model object |
| One thing, might be deleted underneath you | Wrapper → content: `@Query` by ID, content takes the model |
| A derived value (count, total, grouping) | Computed property in an extension on the model |
| A value used in a predicate | A stored property. Always. Computed properties can't be translated |

**Writes**

| Situation | Do this |
|---|---|
| Anything at all, during this migration | A repository method |
| It has a rule attached | A repository method, and the rule lives *in* it |
| It's a plain field with no rule | Still a repository method for now — see M7's open question |
| It failed | `throw`. Never `guard ... else { return }`, never `print` |

**Smells, and what they mean**

| If you're writing… | Stop, because… |
|---|---|
| `modelContext.insert` in a view | Writes belong in a repository |
| `try?` around a data operation | You're building a silent-failure path; §1.1 has three |
| `UserDefaults` for anything but a preference | It's not a database |
| `JSONEncoder` for something you'll query later | That's the blob, returning |
| An index lookup to find a model | You have the object; pass it |
| A repository method that's one `modelContext` call | Ask which rule it was protecting. If none, delete it |
| `guard ... else { return }` on a failed precondition | The user tapped a button and nothing happened |
| A stored field you could compute | Two sources of truth, in miniature |

### Appendix B — Naming against the standard library

`Set` is the obvious name for the set model and the wrong one. Swift resolves your module's types
before the standard library's, so a `@Model class Set` shadows `Swift.Set` throughout the module —
and the resulting errors point at the *use* sites, never at the declaration, so the cause is
genuinely hard to find. `ExerciseSet` is more precise anyway: it's a set *of an exercise*, which
is what the domain calls it.

The general rule: before claiming a short, common noun, check whether Swift already owns it.
`Task`, `Result`, `Error`, `Never`, `Range`, `Duration`, `Character`, `Mirror`, `Data`, `Measurement`
are all taken, and the last three are especially easy to collide with in a fitness app. Qualifying
the name (`ExerciseSet`, `WorkoutTask`) costs nothing and usually reads better, because a name
that needs qualifying is usually a name that was too vague.

### Appendix C — What a real migration would have looked like

We took a clean break: new schema, old data gone. That was a *choice justified by circumstances* —
one user, no release, nothing valuable in the store. Change any of those and it becomes
unacceptable, so it's worth knowing what the alternative involves.

SwiftData versions schemas explicitly. Each shape of your model graph is a `VersionedSchema`, and
this migration needs **three** of them — the reason why is the interesting part:

```swift
enum DidWeightsSchemaV1: VersionedSchema {          // what shipped: blob-era models
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [...] }
}

enum DidWeightsSchemaV2: VersionedSchema {          // the bridge: BOTH shapes at once
    static var versionIdentifier: Schema.Version { .init(2, 0, 0) }
    static var models: [any PersistentModel.Type] { [...] }
}

enum DidWeightsSchemaV3: VersionedSchema {          // the destination: normalized only
    static var versionIdentifier: Schema.Version { .init(3, 0, 0) }
    static var models: [any PersistentModel.Type] { [...] }
}
```

A `SchemaMigrationPlan` lists the versions and the stages between them:

```swift
enum DidWeightsMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [...] }
    static var stages: [MigrationStage] { [...] }
}
```

Two kinds of stage. **Lightweight** handles changes SwiftData can infer — adding an entity or an
optional property. **Custom** gives you `willMigrate` and `didMigrate` closures so your own code
can run, which this migration absolutely needs: nothing can infer "decode this JSON and fan it out
into three tables."

So why three schemas rather than a single V1 → V2 custom stage? Because `willMigrate` runs against
the *source* schema, where the normalized entities don't exist yet, and `didMigrate` runs against
the *destination* schema, where the blob-carrying entities are already gone. There is no single
moment at which you can both read the old shape and write the new one.

The bridge schema creates that moment. V1 → V2 is **lightweight**: it just adds the normalized
entities alongside the legacy ones, and no data moves. V2 → V3 is **custom**: its `willMigrate`
runs while both shapes exist, reads the still-present blobs, writes normalized rows — and the
destination V3 is what finally drops the legacy types. Three versions and two stages to move one
small app's data, which is the real lesson about what a shipped schema costs.

The rest of what makes it hard:

- **It runs once, on the user's device, unattended.** No console, no debugger, no retry. If it
  throws halfway, you may have left the store in a state no version of the app can open.
- **You keep the old model types compiled into the app** for as long as you support upgrading from
  that version. You can't decode `LoggedWorkout` if you deleted it.
- **You must handle data your current code can't produce.** Real stores contain rows written by
  every version you ever shipped, including the one with the bug.
- **Testing means fixtures**: a V1 store checked into the repo, migrated in a test, asserted
  against. Which means you need to have thought of that *before* you needed it.

The lesson isn't "always write a migration plan." It's: know which situation you're in, decide
deliberately, and write down why. Assuming you're always in the easy case is how people lose
customer data.

### Appendix D — Review checklist

What I'll be checking on each PR, so there are no surprises:

**Every milestone**
- [ ] The app builds *and runs*; the flow described in "Definition of done" actually works
- [ ] The diff is scoped to this milestone — no drive-by refactors, no cosmetic churn
- [ ] The PR description answers that milestone's questions
- [ ] No commented-out code, no `print` used as error handling, no new `try?`
- [ ] Comments explain *why*, not what. If a comment restates the code, the code should be clearer
- [ ] Tests still pass (from M5 onward)

**Milestones that touch data**
- [ ] No `modelContext.insert` / `.delete` outside `Repositories/`
- [ ] Every failure path `throw`s something specific; no silent `return`
- [ ] Every new `#Predicate` uses stored properties only
- [ ] Every read of an ordered relationship sorts explicitly
- [ ] Delete rules were chosen, not defaulted into

**The thing I care about most**

That you can explain the reasoning. A milestone implemented exactly as written but not understood
is worth less than one you pushed back on. If you think a decision in this document is wrong, say
so in the PR — some of them are judgment calls, at least one is arguable, and "the spec said so"
is not a defence either of us should accept.
