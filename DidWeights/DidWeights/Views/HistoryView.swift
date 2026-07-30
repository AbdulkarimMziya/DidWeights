//
//  HistoryView.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-07-29.
//

import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \Workout.startDate, order: .reverse) private var pastWorkouts: [Workout]
    
    var body: some View {
        NavigationStack{
            List(pastWorkouts) { workout in
                Text(workout.startDate.formatted())
            }
            .navigationTitle("History")
        }
    }
}

#Preview {
    // In-memory container so preview data never touches your real database
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Workout.self, SavedWorkout.self, Exercise.self,
        configurations: config
    )

    // Helper to build a quick LoggedWorkout blob
    func sampleWorkoutData(exerciseNames: [String]) -> Data {
        let exercises = exerciseNames.map { name in
            LoggedExercise(
                exerciseID: UUID(),
                exerciseName: name,
                sets: [
                    WorkoutSet(reps: 8, weight: 135, isCompleted: true),
                    WorkoutSet(reps: 8, weight: 135, isCompleted: true)
                ]
            )
        }
        let logged = LoggedWorkout(startDate: Date(), exercises: exercises)
        return (try? PersistanceHelper.transformToData(logged)) ?? Data()
    }

    // Seed a handful of workouts across different months
    let calendar = Calendar.current
    let now = Date()

    let sampleDates: [Date] = [
        now,
        calendar.date(byAdding: .day, value: -3, to: now)!,
        calendar.date(byAdding: .month, value: -1, to: now)!,
        calendar.date(byAdding: .month, value: -1, to: now)!.addingTimeInterval(-86400 * 5),
        calendar.date(byAdding: .month, value: -2, to: now)!
    ]

    for date in sampleDates {
        let workout = Workout(
            startDate: date,
            endDate: date.addingTimeInterval(45 * 60),
            workoutData: sampleWorkoutData(exerciseNames: ["Bench Press", "Squat"])
        )
        container.mainContext.insert(workout)
    }

    let mockManager = WorkoutManager()

    return HistoryView()
        .environment(mockManager)
        .modelContainer(container)
}
