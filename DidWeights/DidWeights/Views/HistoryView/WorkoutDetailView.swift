//
//  WorkoutDetailView.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-07-30.
//

import SwiftData
import SwiftUI

struct WorkoutDetailView: View {
    private let workoutID: UUID
    @Query private var matches: [Workout]
    
    init(workoutID: UUID) {
        self.workoutID = workoutID
        _matches = Query(filter: #Predicate<Workout> { $0.id == workoutID })
    }
    
    var body: some View {
        if let workout = matches.first {
            WorkoutDetailContent(workout: workout)
        } else {
            ContentUnavailableView(
                "Workout Not Found",
                systemImage: "clock.arrow.circlepath"
            )
        }
    }
}

private struct WorkoutDetailContent: View {
    let workout: Workout

    var body: some View {
        List {
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
    workout.endDate = Date().addingTimeInterval(3600) // 1 hour workout duration
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
        WorkoutDetailView(workoutID: workout.id)
    }
    .modelContainer(container)
}

