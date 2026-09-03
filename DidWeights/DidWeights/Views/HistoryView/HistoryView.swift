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
    // 1. Build an unseeded, in-memory model container
    let container = try! ModelContainer.inMemory(seeded: false)
    let context = container.mainContext
    
    // 2. Create master catalog Exercise objects and insert them
    let benchPress = Exercise(name: "Bench Press", muscleGroup: "Chest")
    let squat = Exercise(name: "Squat", muscleGroup: "Legs")
    context.insert(benchPress)
    context.insert(squat)
    
    let now = Date()
    let secondsInAMonth: TimeInterval = 30 * 24 * 60 * 60
    
    // 3 & 4. Build several completed Workout and ExerciseSet objects spanning different months
    
    // --- Workout 1: Current Month ---
    let workout1 = Workout(name: "Chest Day Heavy", startDate: now)
    workout1.endDate = now.addingTimeInterval(3600) // Completed 1 hour later
    context.insert(workout1)
    
    let w1Set1 = ExerciseSet(order: 0, workout: workout1, exercise: benchPress)
    w1Set1.reps = 10
    w1Set1.weight = 135.0
    w1Set1.isCompleted = true
    context.insert(w1Set1)
    
    // --- Workout 2: One Month Ago ---
    let oneMonthAgo = now.addingTimeInterval(-secondsInAMonth)
    let workout2 = Workout(name: "Leg Day Peak", startDate: oneMonthAgo)
    workout2.endDate = oneMonthAgo.addingTimeInterval(4500)
    context.insert(workout2)
    
    let w2Set1 = ExerciseSet(order: 0, workout: workout2, exercise: squat)
    w2Set1.reps = 5
    w2Set1.weight = 225.0
    w2Set1.isCompleted = true
    context.insert(w2Set1)
    
    // --- Workout 3: Two Months Ago ---
    let twoMonthsAgo = now.addingTimeInterval(-secondsInAMonth * 2)
    let workout3 = Workout(name: "Quick Maintenance", startDate: twoMonthsAgo)
    workout3.endDate = twoMonthsAgo.addingTimeInterval(2000)
    context.insert(workout3)
    
    let w3Set1 = ExerciseSet(order: 0, workout: workout3, exercise: benchPress)
    w3Set1.reps = 12
    w3Set1.weight = 115.0
    w3Set1.isCompleted = true
    context.insert(w3Set1)
    
    // 5. Return HistoryView attached directly to the active model container sandbox
    return HistoryView()
        .modelContainer(container)
}

