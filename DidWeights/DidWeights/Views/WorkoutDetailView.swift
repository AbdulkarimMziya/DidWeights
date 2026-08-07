//
//  WorkoutDetailView.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-07-30.
//

import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout
    
    private var logged: LoggedWorkout? {
        try? PersistanceHelper.transformFromData(workout.workoutData)
    }
    
    var body: some View {
        List {
            if let logged, !logged.exercises.isEmpty {
                ForEach(logged.exercises) { exercise in
                    Section(exercise.exerciseName) {
                        ForEach(exercise.sets) { set in
                            HStack {
                                if let reps = set.reps {
                                    Text("\(reps) reps")
                                }
                                Spacer()
                                if let weight = set.weight {
                                    Text("\(weight, specifier: "%.1f") lb(s)")
                                }
                            }
                        }
                    }
                }
            } else {
                Text("Couldn't load workout details")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(workout.name)
    }
}

#Preview {
    // Build a sample LoggedWorkout with a few exercises/sets
    let exercises = [
        LoggedExercise(
            exerciseID: UUID(),
            exerciseName: "Bench Press",
            sets: [
                WorkoutSet(reps: 8, weight: 135, isCompleted: true),
                WorkoutSet(reps: 8, weight: 135, isCompleted: true),
                WorkoutSet(reps: 6, weight: 145, isCompleted: true)
            ]
        ),
        LoggedExercise(
            exerciseID: UUID(),
            exerciseName: "Squat",
            sets: [
                WorkoutSet(reps: 5, weight: 185, isCompleted: true),
                WorkoutSet(reps: 5, weight: 185, isCompleted: true)
            ]
        ),
        LoggedExercise(
            exerciseID: UUID(),
            exerciseName: "Pull-Up",
            sets: [
                WorkoutSet(reps: 10, weight: nil, isCompleted: true),
                WorkoutSet(reps: 8, weight: nil, isCompleted: true)
            ]
        )
    ]

    let logged = LoggedWorkout(startDate: Date(), exercises: exercises)
    let data = (try? PersistanceHelper.transformToData(logged)) ?? Data()

    let workout = Workout(
        startDate: Date(),
        endDate: Date().addingTimeInterval(50 * 60),
        workoutData: data
    )

    return NavigationStack {
        WorkoutDetailView(workout: workout)
    }
}
