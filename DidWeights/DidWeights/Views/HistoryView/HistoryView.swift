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
    let sortDate: Date
}

struct HistoryView: View {
    @Query(
        filter: #Predicate<Workout> { $0.endDate != nil },
        sort: \Workout.startDate,
        order: .reverse,
    )
    private var pastWorkouts: [Workout]
    
    private var monthSections: [MonthSection] {
        var buckets: [String: (date: Date, workouts: [Workout])] = [:]
        let calendar = Calendar.current
     
        for workout in pastWorkouts {
            let year = calendar.component(.year, from: workout.startDate)
            let month = calendar.component(.month, from: workout.startDate)
            let key = "\(year)-\(month)"
     
            var components = DateComponents()
            components.year = year
            components.month = month
            let sortDate = calendar.date(from: components) ?? .distantPast
     
            if var existing = buckets[key] {
                existing.workouts.append(workout)
                buckets[key] = existing
            } else {
                buckets[key] = (date: sortDate, workouts: [workout])
            }
        }
    
    var sections: [MonthSection] = []
        for (key, bucket) in buckets {
            let sortedWorkouts = bucket.workouts.sorted { $0.startDate > $1.startDate }
            let title = sortedWorkouts.first?.startDate.formatted(.dateTime.month(.wide).year()) ?? key
     
            sections.append(MonthSection(
                id: key,
                title: title,
                workouts: sortedWorkouts,
                sortDate: bucket.date
            ))
        }
     
        return sections.sorted { $0.sortDate > $1.sortDate }
    }
    
    
    var body: some View {
        NavigationStack {
            Group {
                if pastWorkouts.isEmpty {
                    ContentUnavailableView(
                        "No Workouts Yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Finish your first workout to see it here.")
                    )
                } else {
                    List {
                        ForEach(monthSections) { section in
                            Section(section.title) {
                                ForEach(section.workouts) { workout in
                                    NavigationLink(value: workout.id) {
                                        HStack{
                                            Text(workout.name)
                                                .fontWeight(.semibold)
                                            Spacer()
                                            Text(workout.startDate.formatted(date: .abbreviated, time: .omitted))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: UUID.self) { workoutID in
                WorkoutDetailView(workoutID: workoutID)
            }
        }
    }
}

#Preview {
    // In-memory container so preview data never touches your real database
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: LegacyWorkout.self, LegacySavedWorkout.self, LegacyExercise.self,
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
        let workout = LegacyWorkout(
            workoutData: sampleWorkoutData(exerciseNames: ["Bench Press", "Squat"])
        )
        container.mainContext.insert(workout)
    }

    let mockManager = WorkoutManager()

    return HistoryView()
        .environment(mockManager)
        .modelContainer(container)
}
