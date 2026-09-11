//
//  AddExerciseSheet.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-09-04.
//

import SwiftData
import SwiftUI

struct AddExerciseSheet: View {
    let workout: Workout
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var errorMessage: String?

    private var workouts: WorkoutRepository { WorkoutRepository(context: modelContext) }

    var body: some View {
        ExercisePickerView(showSetCount: true) { exercise, setCount in
            do {
                try workouts.addExercise(exercise, to: workout, setCount: setCount)
                dismiss()
            } catch {
                errorMessage = "Couldn't add exercise: \(error.localizedDescription)"
            }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
}

#Preview {
    let container = try! ModelContainer.inMemory(seeded: true)
    let context = container.mainContext
    let descriptor = FetchDescriptor<Workout>()
    let workout = (try? context.fetch(descriptor))?.first ?? Workout(name: "Preview")

    return AddExerciseSheet(workout: workout)
        .modelContainer(container)
}
