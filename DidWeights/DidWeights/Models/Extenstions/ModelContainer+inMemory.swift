//
//  ModelContainer+inMemory.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-08-22.
//

import Foundation
import SwiftData

extension ModelContainer {
    @MainActor
    static func inMemory(seeded: Bool = false) throws -> ModelContainer {
        // 1. Explicitly encapsulate your models inside a strict schema boundary
        let schema = Schema([
            Workout.self,
            Exercise.self,
            ExerciseSet.self,
            WorkoutPreset.self,
            LegacyWorkout.self,
            LegacySavedWorkout.self,
            LegacyExercise.self
        ])
        
        // 2. Pair the schema directly to your in-memory configuration
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        
        do {
            // 3. Initialize using both schema and configuration
            let container = try ModelContainer(for: schema, configurations: [config])
            
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
                
                // 4. Save your seeded data so it's fully committed to memory before a fetch occurs
                try context.save()
            }
            
            return container
        } catch {
            fatalError("Could not configure the container: \(error.localizedDescription)")
        }
    }
}
