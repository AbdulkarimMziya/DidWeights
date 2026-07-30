//
//  HistoryView.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-07-29.
//

import SwiftData
import SwiftUI

struct MonthSection: Identifiable {
    let id: String
    let title: String
    let workouts: [Workout]
}

struct HistoryView: View {
    @Query(sort: \Workout.startDate, order: .reverse) private var pastWorkouts: [Workout]
    
    private var monthSections: [MonthSection] {
        var buckets: [String: [Workout]] = [:]        // empty dictionary
        let calendar = Calendar.current

        for workout in pastWorkouts {
            let year = calendar.component(.year, from: workout.startDate)
            let month = calendar.component(.month, from: workout.startDate)
            let key = "\(year)-\(month)"                // "2026-7"

            buckets[key, default: []].append(workout)   // add this workout to its bucket
        }

        // Now turn the dictionary into an array of MonthSection, sorted newest first
        var sections: [MonthSection] = []
        for (key, workouts) in buckets {
            let sortedWorkouts = workouts.sorted { $0.startDate > $1.startDate }
            let title = sortedWorkouts.first?.startDate.formatted(.dateTime.month(.wide).year()) ?? key
            sections.append(MonthSection(id: key, title: title, workouts: sortedWorkouts))
        }

        return sections.sorted { $0.id > $1.id }
    }
    
    
    var body: some View {
        NavigationStack{
            List {
                ForEach(monthSections) { section in
                    Section(section.title) {
                        ForEach(section.workouts) { workout in
                            Text(workout.startDate.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                }
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
