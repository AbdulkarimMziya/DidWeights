//
//  AddExerciseSheet.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-09-04.
//

import SwiftData
import SwiftUI

// Sets can't exist without an Exercise (M4's trap: an exercise with zero
// sets can't exist), so this has to let the user pick or name the exercise
// FIRST, before anything is created — unlike the old flow, which added an
// empty, unnamed row and let the user fill it in afterward.
//
// Kept as internal (not private) access level: ActiveWorkoutContent, in a
// separate file, constructs this directly inside its .sheet(isPresented:).
// A private declaration here would make it invisible to that call site.
struct AddExerciseSheet: View {
    let workout: Workout
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var catalog: [Exercise]

    @State private var newExerciseName = ""
    @State private var setCount = 3
    @State private var errorMessage: String?

    private var workouts: WorkoutRepository { WorkoutRepository(context: modelContext) }
    private var exercises: ExerciseRepository { ExerciseRepository(context: modelContext) }

    var body: some View {
        NavigationStack {
            Form {
                Section("New Exercise") {
                    TextField("Exercise name", text: $newExerciseName)
                    Stepper("\(setCount) sets", value: $setCount, in: 1...10)
                    Button("Add") {
                        addNew()
                    }
                    .disabled(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Section("Existing Exercises") {
                    ForEach(catalog) { exercise in
                        Button(exercise.name) {
                            addExisting(exercise)
                        }
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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

    private func addNew() {
        do {
            let exercise = try exercises.findOrCreate(name: newExerciseName)
            try workouts.addExercise(exercise, to: workout, setCount: setCount)
            dismiss()
        } catch {
            errorMessage = "Couldn't add exercise: \(error.localizedDescription)"
        }
    }

    private func addExisting(_ exercise: Exercise) {
        do {
            try workouts.addExercise(exercise, to: workout, setCount: setCount)
            dismiss()
        } catch {
            errorMessage = "Couldn't add exercise: \(error.localizedDescription)"
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
