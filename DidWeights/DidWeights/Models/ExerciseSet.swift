//
//  ExerciseSet.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-08-21.
//

import Foundation
import SwiftData

@Model
final class ExerciseSet: Identifiable {
    var id: UUID
    var order: Int          // position within the *workout*, not within the exercise group;
                            // dense (0, 1, 2, … no gaps) and unique — see M4
    var reps: Int?
    var weight: Double?
    var isCompleted: Bool
    var completedAt: Date?

    var workout: Workout?
    var exercise: Exercise?

    init(order: Int, workout: Workout, exercise: Exercise) {
        self.id = UUID()
        self.order = order
        self.reps = nil
        self.weight = nil
        self.isCompleted = false
        self.completedAt = nil
        self.workout = workout
        self.exercise = exercise
    }
}
