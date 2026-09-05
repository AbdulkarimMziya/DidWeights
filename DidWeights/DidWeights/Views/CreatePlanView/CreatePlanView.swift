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
    var exercise: Exercise?
    var name: String = ""
}

struct CreatePlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let editingPlan: WorkoutPreset?

    @State private var planName: String = ""
    @State private var defaultSetCount: Int = 3
    @State private var exercises: [PlanExerciseDraft] = []
    @State private var errorMessage: String?

    private var presets: PresetRepository { PresetRepository(context: modelContext) }
    private var catalog: ExerciseRepository { ExerciseRepository(context: modelContext) }

    init(editingPlan: WorkoutPreset? = nil) {
        self.editingPlan = editingPlan
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan Name") {
                    TextField("e.g. Push Day", text: $planName)
                }
 
                Section("Default Sets") {
                    Stepper("\(defaultSetCount) sets per exercise", value: $defaultSetCount, in: 1...10)
                }

                Section("Exercises") {
                    ForEach($exercises) { $exercise in
                        TextField("Exercise name", text: $exercise.name)
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

    private func loadExistingPlanIfNeeded() {
        guard let editingPlan, exercises.isEmpty else { return }

        planName = editingPlan.name
        defaultSetCount = editingPlan.defaultSetCount

        exercises = editingPlan.orderedExercises.map { exercise in
            PlanExerciseDraft(exercise: exercise, name: exercise.name)
        }
    }

    private func savePlan() {
        do {
            // Resolve every draft's name to a real catalog Exercise now,
            // at the single point resolution is allowed to happen.
            let resolvedExercises = try exercises.map { draft in
                try catalog.findOrCreate(name: draft.name)
            }

            if let editingPlan {
                try presets.update(
                    editingPlan,
                    name: planName,
                    exercises: resolvedExercises,
                    defaultSetCount: defaultSetCount
                )
            } else {
                try presets.create(
                    name: planName,
                    exercises: resolvedExercises,
                    defaultSetCount: defaultSetCount
                )
            }

            dismiss()
        } catch {
            errorMessage = "Couldn't save this plan: \(error.localizedDescription)"
        }
    }
}

#Preview {
    let container = try! ModelContainer.inMemory(seeded: false)
    return CreatePlanView()
        .modelContainer(container)
}
