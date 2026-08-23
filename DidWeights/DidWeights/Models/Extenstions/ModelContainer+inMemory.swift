//
//  ModelContainer+inMemory.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-08-22.
//

import Foundation
import SwiftData

extension ModelContainer {
    static func inMemory(seeded: Bool = false) throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Workout.self, Exercise.self, ExerciseSet.self, WorkoutPreset.self,LegacyWorkout.self, LegacySavedWorkout.self, LegacyExercise.self,
            configurations: config
        )

        if seeded {
            let context = container.mainContext
            let benchPress = Exercise(name: "Bench Press")
            let squat = Exercise(name: "Squat")
            context.insert(benchPress)
            context.insert(squat)
            
            let pushDay = Workout(name: "Push Day", startDate: .now)
            context.insert(pushDay)
            
            let set1 = ExerciseSet(order: 0, workout: pushDay, exercise: benchPress)
            let set2 = ExerciseSet(order: 1, workout: pushDay, exercise: benchPress)
            let set3 = ExerciseSet(order: 2, workout: pushDay, exercise: squat)
            
            context.insert(set1)
            context.insert(set2)
            context.insert(set3)
        }

        return container
    }
}
