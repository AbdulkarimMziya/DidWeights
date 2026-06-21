//
//  TempWorkoutData.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-06-14.
//

import Foundation

let tempWorkouts: LoggedWorkout =
    LoggedWorkout(
        startDate: Date(),
        exercises: [
            LoggedExercise(
                exerciseID: UUID(),
                exerciseName: "Bench Press",
                sets: [
                    WorkoutSet(reps: 10, weight: 135),
                    WorkoutSet(reps: 8, weight: 155),
                    WorkoutSet(reps: 6, weight: 175)
                ]
            ),
            LoggedExercise(
                exerciseID: UUID(),
                exerciseName: "Incline Dumbbell Press",
                sets: [
                    WorkoutSet(reps: 12, weight: 50),
                    WorkoutSet(reps: 10, weight: 55)
                ]
            )
        ]
    )



struct WorkoutTemplate: Identifiable {
    let id = UUID()
    var name: String
    var exerciseNames: [String] // Stores the names of the exercises in this plan
    var lastActive: Date?       // nil means it has never been played yet
    
    // Computed property to dynamically get the count
    var exerciseCount: Int {
        exerciseNames.count
    }
}
    
let sampleTemplates: [WorkoutTemplate] = [
    WorkoutTemplate(
        name: "Push Day",
        exerciseNames: ["Bench Press", "Incline Dumbbell Press", "Tricep Pushdowns"],
        lastActive: Date().addingTimeInterval(-86400 * 2) // 2 days ago
    ),
    WorkoutTemplate(
        name: "Pull Day",
        exerciseNames: ["Barbell Rows", "Pull-ups", "Bicep Curls"],
        lastActive: Date().addingTimeInterval(-86400 * 5) // 5 days ago
    ),
    WorkoutTemplate(
        name: "Leg Day",
        exerciseNames: ["Squats", "Romanian Deadlifts", "Calf Raises"],
        lastActive: nil // Never active
    )
]
