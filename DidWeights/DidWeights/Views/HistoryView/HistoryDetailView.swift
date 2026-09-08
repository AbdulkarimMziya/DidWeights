//
//  WorkoutDetailView.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-07-30.
//

import SwiftData
import SwiftUI

struct HistoryDetailView: View {
    private let workoutID: UUID
    @Query private var matches: [Workout]
    
    init(workoutID: UUID) {
        self.workoutID = workoutID
        _matches = Query(filter: #Predicate<Workout> { $0.id == workoutID })
    }
    
    var body: some View {
        if let workout = matches.first {
            HistoryDetailContent(workout: workout)
        } else {
            ContentUnavailableView(
                "Workout Not Found",
                systemImage: "clock.arrow.circlepath"
            )
        }
    }
}

private struct HistoryDetailContent: View {
    let workout: Workout

    var body: some View {
        List {
            Section {
                Text(summaryLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            ForEach(workout.exerciseGroups) { group in
                Section(group.exercise.name) {
                    ForEach(group.sets) { set in
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
        }
        .navigationTitle(workout.name)
    }

    // View-layer formatting only, same spirit as WorkoutTimerView.elapsedString.
    private var summaryLine: String {
        let count = workout.exerciseGroups.count
        let exercises = "\(count) \(count == 1 ? "exercise" : "exercises")"
        return "\(durationText) · \(exercises)"
    }

    // "1h 12min" / "1h" / "12min" from the finished workout's elapsed time.
    // Workout.elapsed() already subtracts accumulatedPause; for a completed
    // workout the `asOf:` default is irrelevant.
    private var durationText: String {
        let totalMinutes = max(0, Int(workout.elapsed()) / 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60

        switch (h, m) {
        case (0, _): return "\(m)min"
        case (_, 0): return "\(h)h"
        default:     return "\(h)h \(m)min"
        }
    }
}

#Preview {
    // 1. Build an unseeded, in-memory model container
    let container = try! ModelContainer.inMemory(seeded: false)
    let context = container.mainContext
    
    // 2. Create Exercise objects and insert them into the context
    let benchPress = Exercise(name: "Bench Press", muscleGroup: "Chest")
    let bicepCurl = Exercise(name: "Bicep Curl", muscleGroup: "Arms")
    context.insert(benchPress)
    context.insert(bicepCurl)
    
    // 3. Create a Workout with an endDate (so it registers as completed) and insert it
    let workout = Workout(name: "Upper Body Power" )
    workout.endDate = Date().addingTimeInterval(4320) // 1h 12min workout duration
    context.insert(workout)
    
    // 4. Create ExerciseSets pointing at the workout/exercises with realistic values and insert them
    let set1 = ExerciseSet(order: 0, workout: workout, exercise: benchPress)
    set1.reps = 8
    set1.weight = 135.0
    set1.isCompleted = true
    
    let set2 = ExerciseSet(order: 1, workout: workout, exercise: benchPress)
    set2.reps = 6
    set2.weight = 145.0
    set2.isCompleted = true
    
    let set3 = ExerciseSet(order: 2, workout: workout, exercise: bicepCurl)
    set3.reps = 12
    set3.weight = 30.0
    set3.isCompleted = true
    
    context.insert(set1)
    context.insert(set2)
    context.insert(set3)
    
    // 5. Return the view target wrapped with a NavigationStack and the active container modifier
    return NavigationStack {
        HistoryDetailView(workoutID: workout.id)
    }
    .modelContainer(container)
}

