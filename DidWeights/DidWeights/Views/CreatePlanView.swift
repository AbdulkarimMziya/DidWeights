//
//  CreatePlanView.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-07-14.
//

import SwiftData
import SwiftUI

struct PlanExerciseDraft: Identifiable {
    let id = UUID()
    var exerciseID: UUID = UUID()
    var name: String = ""
    var setCount: Int = 3
}

struct CreatePlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let editingPlan: SavedWorkout?

    @State private var planName: String = ""
    @State private var exercises: [PlanExerciseDraft] = []

    init(editingPlan: SavedWorkout? = nil) {
        self.editingPlan = editingPlan
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan Name") {
                    TextField("e.g. Push Day", text: $planName)
                }

                Section("Exercises") {
                    ForEach($exercises) { $exercise in
                        HStack {
                            TextField("Exercise name", text: $exercise.name)
                            Spacer()
                            Stepper("\(exercise.setCount) sets", value: $exercise.setCount, in: 1...10)
                        }
                    }
                    .onDelete { exercises.remove(atOffsets: $0) }

                    Button("Add Exercise") {
                        exercises.append(PlanExerciseDraft())
                    }
                }
            }
            .navigationTitle(editingPlan == nil ?
                             planName.isEmpty ? "New Plan" : planName
                             : "Edit Plan"
            )
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { savePlan() }
                        .disabled(planName.isEmpty || exercises.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { loadExistingPlanIfNeeded() }
        }
    }

    private func loadExistingPlanIfNeeded() {
        guard let editingPlan, exercises.isEmpty else { return }
        planName = editingPlan.name

        if let template = try? PersistanceHelper.transformFromData(editingPlan.workoutData) {
            exercises = template.exercises.map { exercise in
                PlanExerciseDraft(
                    exerciseID: exercise.exerciseID,
                    name: exercise.exerciseName,
                    setCount: max(exercise.sets.count, 1)
                )
            }
        }
    }

    private func savePlan() {
        let loggedExercises = exercises.map { draft in
            LoggedExercise(
                exerciseID: draft.exerciseID,
                exerciseName: draft.name,
                sets: (0..<draft.setCount).map { _ in WorkoutSet(reps: nil, weight: nil) }
            )
        }
        let template = LoggedWorkout(startDate: Date(), exercises: loggedExercises)

        do {
            let data = try PersistanceHelper.transformToData(template)

            if let editingPlan {
                editingPlan.name = planName
                editingPlan.workoutData = data
            } else {
                let saved = SavedWorkout(name: planName, workoutData: data)
                modelContext.insert(saved)
            }
            dismiss()
        } catch {
            print("Failed to save plan: \(error)")
        }
    }
}

#Preview {
    CreatePlanView()
}
