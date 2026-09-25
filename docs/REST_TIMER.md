# Rest Timer — Scaffolding Notes & Implementation Guide

This doc has two jobs: (1) summarize what's already scaffolded and why it's built the way it is,
and (2) walk you through *how* to build each remaining piece yourself, with real code you can
adapt. Read Part 1 to understand what exists, then use Part 2 as a step-by-step guide as you
implement each roadmap item — each step names the exact files to touch and shows a working code
segment, not just a description.

---

## Part 1 — What's already built

### Summary

Five new files in `Views/ActiveWorkoutView/RestTimer/`, plus two small edits to
`ActiveWorkoutView.swift`:

| File | What it does |
|---|---|
| `RestTimerModel.swift` | `@Observable` class holding the countdown state — `idle` or `running(endDate:duration:)`. No SwiftData, no persistence. |
| `RestTimerPresets.swift` | `enum RestTimerPreset` — 4 fixed durations: 30s / 60s / 90s / 2m. |
| `RestTimerPresetPill.swift` | One tappable pill (label + selected/unselected styling). |
| `RestTimerPickerSheet.swift` | The sheet UI: pill row + custom minute/second wheel picker + Start button. |
| `RestTimerBar.swift` | The nav-bar countdown: progress capsule + `mm:ss`, only visible while running, tap to cancel. |

**How they connect**, top to bottom:

```
ActiveWorkoutContent
 ├─ @State restTimer = RestTimerModel()          ← the single source of truth
 ├─ @State showRestTimerPicker = false
 │
 ├─ toolbar: timer icon button  →  sets showRestTimerPicker = true
 ├─ toolbar: RestTimerBar(timer: restTimer)       ← reads restTimer.state every second
 └─ .sheet: RestTimerPickerSheet(timer: restTimer)
        └─ Start button  →  timer.start(duration:)  →  updates restTimer.state
                                                          → RestTimerBar picks it up automatically
```

Because `RestTimerModel` is `@Observable` and both `RestTimerBar` and `RestTimerPickerSheet` hold
a reference to the *same instance* (created once as `ActiveWorkoutContent`'s `@State`), calling
`timer.start(duration:)` inside the sheet is immediately visible in the toolbar bar — no manual
syncing needed. This is the core SwiftUI mechanic worth understanding before you extend anything
below: **one shared `@Observable` instance, read from multiple views.**

### Why it's built this way (short version — skip if you just want to build)

- **`endDate`-based countdown, not a decrementing counter.** `remaining(asOf:)` subtracts `now`
  from a stored `endDate`. This mirrors `Workout.elapsed(asOf:)` in `Workout+Derived.swift` and
  `WorkoutTimerView`'s `TimelineView` pattern. A repeating `Timer` that does `remaining -= 1`
  drifts and stops firing the instant the view disappears; date math against a fixed `endDate` is
  always correct on the next read, no matter how long the gap was.
- **No `ModelContext`, no Repository.** CLAUDE.md's rule is that Repositories own all persisted
  writes to the normalized SwiftData schema. A rest timer's countdown is never saved and has no
  relationship to `Workout`/`ExerciseSet` — it's ephemeral UI state, same category as
  `@State private var focusedField`.
- **Four presets, not six.** Fewer choices = faster tap between sets.
- **Wheel `Picker`, not a custom stepper.** Stock control, zero custom gesture code, same result.
- **`.principal` toolbar slot.** The only nav-bar space that was empty and is always visible
  regardless of scroll position.

---

## Part 2 — Building the rest, step by step

Each section below is independent — do them in any order, or skip ones you don't need yet.

### Step A: Auto-start the timer when a set is completed — ✅ Implemented

Implemented as designed below, with one confirmed decision: completing a set while a timer is
already running does **not** reset it (`!restTimer.isRunning` guard) — see
`ExerciseSetRowView`'s checkbox `Button` in `ActiveWorkoutView.swift`.

**Why this shape:** `toggleCompletion` flips completion *both directions* (checking and
unchecking a set), so you only want to start the timer on the `false → true` transition — never
on uncheck. The cleanest way to know both the before and after state is to check `isCompleted`
right before calling the repository method.

**Files to touch:**
- `RestTimerModel.swift` — remember the last duration used, so auto-start has something to start with.
- `ActiveWorkoutView.swift` — thread `restTimer` down to `ExerciseGroupView` → `ExerciseSetRowView`, and start it from the checkbox action.

1. Add a `lastUsedDuration` to the model:

```swift
// RestTimerModel.swift
@Observable
final class RestTimerModel {
    private(set) var state: RestTimerState = .idle
    private(set) var lastUsedDuration: TimeInterval = RestTimerPreset.sixtySeconds.duration

    func start(duration: TimeInterval, now: Date = .now) {
        lastUsedDuration = duration
        state = .running(endDate: now.addingTimeInterval(duration), duration: duration)
    }
    // ...cancel(), remaining(asOf:), progress(asOf:) unchanged
}
```

2. Pass `restTimer` down through the view hierarchy (it currently stops at `ActiveWorkoutContent`):

```swift
// ActiveWorkoutContent.body — pass restTimer into each exercise group
ForEach(exerciseGroups) { group in
    ExerciseGroupView(
        workout: workout,
        group: group,
        restTimer: restTimer,                // ← new
        focusedField: $focusedField,
        errorMessage: $errorMessage
    )
}
```

```swift
// ExerciseGroupView — accept it and forward to each row
struct ExerciseGroupView: View {
    let workout: Workout
    let group: ExerciseGroup
    let restTimer: RestTimerModel            // ← new
    @FocusState.Binding var focusedField: ActiveWorkoutContent.Field?
    @Binding var errorMessage: String?

    // ...inside the ForEach(group.sets):
    ExerciseSetRowView(set: set, index: index, restTimer: restTimer, focusedField: $focusedField)
}
```

3. Start the timer from the checkbox, only on the completing transition:

```swift
// ExerciseSetRowView
struct ExerciseSetRowView: View {
    @Bindable var set: ExerciseSet
    let index: Int
    let restTimer: RestTimerModel            // ← new
    @FocusState.Binding var focusedField: ActiveWorkoutContent.Field?

    // ...inside body, the checkbox Button:
    Button {
        let wasCompleted = set.isCompleted
        try? workouts.toggleCompletion(of: set)
        if !wasCompleted && set.isCompleted {
            restTimer.start(duration: restTimer.lastUsedDuration)
        }
    } label: {
        // unchanged
    }
}
```

That's the whole hook. Open decision for you: should this only fire if no timer is currently
running (so completing a second set mid-rest doesn't reset the clock), or should it always
restart? A one-line guard (`if !restTimer.isRunning { ... }`) covers the first option.

---

### Step B: Sound and haptic cues — ✅ Implemented

Implemented as designed below, with both haptics *and* a system sound firing on finish (plus the
10s pre-warning impact) — see `RestTimerBar.swift`.

**Why this shape:** `RestTimerBar` already detects the zero-crossing (`remaining <= 0`) to
auto-clear the bar — that's the same spot a completion cue belongs. A "10 seconds left" pre-warning
is a second, separate threshold check.

**Files to touch:** `RestTimerBar.swift` only.

```swift
// RestTimerBar.swift
import SwiftUI
import UIKit   // for UINotificationFeedbackGenerator

// ...inside the TimelineView content closure, alongside the existing onChange:

.onChange(of: remaining <= 0) { _, expired in
    if expired {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        timer.cancel()
    }
}
.onChange(of: Int(remaining)) { _, secondsLeft in
    if secondsLeft == 10 {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
```

For a sound instead of (or alongside) haptics, play a system sound with `AudioToolbox`:

```swift
import AudioToolbox

// a short, built-in "tock" — see Apple's System Sound IDs list for other options
AudioServicesPlaySystemSound(1057)
```

---

### Step C: Persist a preferred duration — ✅ Implemented

Implemented as designed below — see `RestTimerPickerSheet.swift`.

**Why this shape:** a "remember my last rest length" preference is a device setting, not workout
data — `@AppStorage` (backed by `UserDefaults`), not a new SwiftData model or Repository.

**Files to touch:** `RestTimerPickerSheet.swift` only.

```swift
// RestTimerPickerSheet.swift
struct RestTimerPickerSheet: View {
    let timer: RestTimerModel
    @Environment(\.dismiss) private var dismiss

    @AppStorage("restTimer.preferredDuration") private var preferredDuration: Double =
        RestTimerPreset.sixtySeconds.duration

    @State private var selectedPreset: RestTimerPreset?
    // ...

    init(timer: RestTimerModel) {
        self.timer = timer
    }

    var body: some View {
        // ...
        .onAppear {
            if selectedPreset == nil {
                selectedPreset = RestTimerPreset.allCases.first {
                    $0.duration == UserDefaults.standard.double(forKey: "restTimer.preferredDuration")
                } ?? .sixtySeconds
            }
        }
    }

    // In the Start button's action:
    Button {
        preferredDuration = resolvedDuration
        timer.start(duration: resolvedDuration)
        dismiss()
    } label: { /* unchanged */ }
}
```

(The `onAppear` dance is only needed because `selectedPreset`'s default is currently set at
declaration time, before `@AppStorage` has loaded — simplest fix is reading the stored value in
`onAppear` as shown.)

---

### Step D: Test `RestTimerModel` — ✅ Implemented

Implemented as designed below (plus one extra test for `lastUsedDuration`) — see
`DidWeightsTests/RestTimerModelTests.swift`. All tests pass; the full suite was also run to
confirm no regressions.

**Why this is easy:** the model only imports `Foundation` — no `ModelContainer.inMemory` needed,
unlike every repository test suite in this codebase. Swift Testing, per CLAUDE.md's conventions.

**Files to touch:** new file `DidWeightsTests/RestTimerModelTests.swift`.

```swift
import Testing
@testable import DidWeights
import Foundation

@Suite
struct RestTimerModelTests {
    @Test
    func remainingCountsDownFromDuration() {
        let model = RestTimerModel()
        let start = Date(timeIntervalSince1970: 0)

        model.start(duration: 90, now: start)

        #expect(model.remaining(asOf: start) == 90)
        #expect(model.remaining(asOf: start.addingTimeInterval(30)) == 60)
    }

    @Test
    func remainingClampsAtZeroPastExpiry() {
        let model = RestTimerModel()
        let start = Date(timeIntervalSince1970: 0)

        model.start(duration: 30, now: start)

        #expect(model.remaining(asOf: start.addingTimeInterval(45)) == 0)
    }

    @Test
    func progressDrainsFromOneToZero() {
        let model = RestTimerModel()
        let start = Date(timeIntervalSince1970: 0)

        model.start(duration: 60, now: start)

        #expect(model.progress(asOf: start) == 1)
        #expect(model.progress(asOf: start.addingTimeInterval(30)) == 0.5)
        #expect(model.progress(asOf: start.addingTimeInterval(60)) == 0)
    }

    @Test
    func cancelReturnsToIdle() {
        let model = RestTimerModel()
        model.start(duration: 60)

        model.cancel()

        #expect(model.isRunning == false)
        #expect(model.remaining() == 0)
    }
}
```

Run it once it exists with:
```sh
xcodebuild -scheme DidWeights -project DidWeights/DidWeights.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test -only-testing:DidWeightsTests/RestTimerModelTests
```

Once you build Step A's auto-start logic, this is also the place to pin down and test the open
question from that section — e.g. add a test asserting `start(duration:)` called while already
`.running` either replaces or is ignored, whichever you decide.
