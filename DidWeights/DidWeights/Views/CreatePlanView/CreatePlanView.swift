//
//  CreatePlanView.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-07-14.
//

import SwiftData
import SwiftUI

struct CreatePlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let editingPlan: WorkoutPreset?

    @State private var planName: String = ""
    @State private var defaultSetCount: Int = 3
    @State private var planExercises: [Exercise] = []
    @State private var showPicker = false
    @State private var errorMessage: String?

    private var presets: PresetRepository { PresetRepository(context: modelContext) }

    init(editingPlan: WorkoutPreset? = nil) {
        self.editingPlan = editingPlan
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan Name") {
                    TextField("e.g. Push Day", text: $planName)
                }
                .listRowBackground(Color.cardBg)

                Section("Default Sets") {
                    Stepper("\(defaultSetCount) sets per exercise", value: $defaultSetCount, in: 1...10)
                }
                .listRowBackground(Color.cardBg)

                Section("Exercises") {
                    ForEach(planExercises) { exercise in
                        HStack(spacing: Spacing.md) {
                            ExerciseThumbnail(muscleGroup: exercise.muscleGroup, size: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .font(.appHeadline)
                                    .foregroundStyle(Color.primaryHeadingTxt)
                                if let group = exercise.muscleGroup, !group.isEmpty {
                                    Text(group)
                                        .font(.appCaption)
                                        .foregroundStyle(Color.secondaryTxt)
                                }
                            }
                        }
                    }
                    .onDelete { planExercises.remove(atOffsets: $0) }

                    Button("Add Exercise") { showPicker = true }
                }
                .listRowBackground(Color.cardBg)
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBg)
            .tint(Color.accentText)
            .navigationTitle(editingPlan == nil ?
                             planName.isEmpty ? "New Plan" : planName
                             : "Edit Plan"
            )
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { savePlan() }
                        .disabled(planName.isEmpty || planExercises.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { loadExistingPlanIfNeeded() }
            .sheet(isPresented: $showPicker) {
                ExercisePickerView(showSetCount: false) { exercise, _ in
                    if !planExercises.contains(where: { $0.id == exercise.id }) {
                        planExercises.append(exercise)
                    }
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

    private func loadExistingPlanIfNeeded() {
        guard let editingPlan, planExercises.isEmpty else { return }

        planName = editingPlan.name
        defaultSetCount = editingPlan.defaultSetCount

        // orderedExercises already gives back live Exercise objects, correctly
        // sequenced, straight from the schema.
        planExercises = editingPlan.orderedExercises
    }

    private func savePlan() {
        do {
            if let editingPlan {
                try presets.update(
                    editingPlan,
                    name: planName,
                    exercises: planExercises,
                    defaultSetCount: defaultSetCount
                )
            } else {
                try presets.create(
                    name: planName,
                    exercises: planExercises,
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
