//
//  Workout+Derived.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-08-21.
//

import Foundation
import SwiftData

extension Workout {
    var isActive: Bool {
        self.endDate == nil
    }
    
    var isPaused: Bool {
        self.pausedAt != nil
    }
    
    func elapsed(asOf now: Date = .now) -> TimeInterval {
        if let endDate {
            return endDate.timeIntervalSince(startDate) - accumulatedPause
        } else if let pausedAt {
            return pausedAt.timeIntervalSince(startDate) - accumulatedPause
        } else {
            return now.timeIntervalSince(startDate) - accumulatedPause
        }
    }
    
    var orderedSets: [ExerciseSet] {
        // Return array ordered by order
        self.sets.sorted { $0.order < $1.order }
    }

    var exerciseGroups: [ExerciseGroup] {
        // Step 1: group the already-globally-sorted sets by exercise.
        // Using orderedSets instead of self.sets means each bucket
        // comes out already sorted by `order` — no extra sort needed inside.
        let grouped = Dictionary(grouping: orderedSets) { $0.exercise }

        // Step 2: turn the dictionary into an array of ExerciseGroup,
        // dropping any entry whose key was nil (no exercise attached).
        let groups = grouped.compactMap { (exercise, sets) -> ExerciseGroup? in
            guard let exercise else { return nil }
            return ExerciseGroup(exercise: exercise, sets: sets)
        }

        // Step 3: the dictionary had no guaranteed order — sort the
        // groups themselves by the earliest `order` value in each one.
        return groups.sorted { lhs, rhs in
            (lhs.sets.first?.order ?? 0) < (rhs.sets.first?.order ?? 0)
        }
    }
    
    var completedSetCount: Int {
        let completedSets = self.sets.filter { $0.isCompleted == true}
        return completedSets.count
    }
    
    var totalVolume: Double {
        self.sets
            .filter { $0.isCompleted == true}
            .compactMap { set -> Double? in
                guard let reps = set.reps, let weight = set.weight else { return nil }
                return Double(reps) * weight
            }
            .reduce(0.0, +)
    }


}
