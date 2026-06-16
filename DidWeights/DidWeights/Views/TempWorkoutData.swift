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

    
