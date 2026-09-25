//
//  RestTimerModel.swift
//  DidWeights
//
//  Ephemeral, view-scoped countdown state — not a `@Model`, never persisted.
//  The countdown is a boundary `Date`, not a decrementing counter, mirroring
//  `Workout.elapsed(asOf:)` in `Workout+Derived.swift`.
//

import Foundation

enum RestTimerState: Equatable {
    case idle
    case running(endDate: Date, duration: TimeInterval)
}

@Observable
final class RestTimerModel {
    private(set) var state: RestTimerState = .idle

    /// Last duration started — the default for auto-start on set completion.
    private(set) var lastUsedDuration: TimeInterval = RestTimerPreset.sixtySeconds.duration

    var isRunning: Bool {
        if case .running = state { true } else { false }
    }

    func start(duration: TimeInterval, now: Date = .now) {
        lastUsedDuration = duration
        state = .running(endDate: now.addingTimeInterval(duration), duration: duration)
    }

    func cancel() {
        state = .idle
    }

    /// Seconds left, clamped to zero. Recomputed from `endDate` each call so
    /// a missed tick never compounds into drift.
    func remaining(asOf now: Date = .now) -> TimeInterval {
        guard case .running(let endDate, _) = state else { return 0 }
        return max(0, endDate.timeIntervalSince(now))
    }

    /// 1 → 0 as time runs out.
    func progress(asOf now: Date = .now) -> Double {
        guard case .running(_, let duration) = state, duration > 0 else { return 0 }
        return min(1, max(0, remaining(asOf: now) / duration))
    }
}
