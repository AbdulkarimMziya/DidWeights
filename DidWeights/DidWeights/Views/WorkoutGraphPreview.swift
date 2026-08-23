//
//  WorkoutGraphPreview.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-08-22.
//

import SwiftUI
import SwiftData

struct WorkoutGraphPreview: View {
    
    @Query private var workouts: [Workout]
    
    var body: some View {
        List {
            ForEach(workouts) { workout in
                Section(workout.name) {
                    ForEach(workout.exerciseGroups) { exerciseGroup in
                        Section(exerciseGroup.exercise.name) {
                            ForEach(exerciseGroup.sets) { set in
                                HStack {
                                    
                                    Text("\(set.reps ?? 0) reps")
                                    Spacer()
                                    Text("\(set.weight ?? 0, specifier: "%.1f") lb")
                                }
                            }
                        }
                        
                    }
                }
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer.inMemory(seeded: true)
    return WorkoutGraphPreview()
        .modelContainer(container)
}
