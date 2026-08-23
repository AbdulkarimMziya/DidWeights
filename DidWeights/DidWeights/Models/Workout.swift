//
//  Workout.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-08-21.
//

import Foundation
import SwiftData

@Model
final class Workout: Identifiable {
    var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date?          // nil ⇒ this is the active workout
    var pausedAt: Date?         // non-nil ⇒ currently paused
    var accumulatedPause: TimeInterval

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.workout)
    var sets: [ExerciseSet]

    var preset: WorkoutPreset?

    init(name: String, startDate: Date = .now, preset: WorkoutPreset? = nil) {
        self.id = UUID()
        self.name = name
        self.startDate = startDate
        self.endDate = nil
        self.pausedAt = nil
        self.accumulatedPause = 0
        self.sets = []
        self.preset = preset
    }
}
