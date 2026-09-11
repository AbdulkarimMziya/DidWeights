//
//  CreateExerciseView.swift
//  DidWeights
//
//  The "Create Exercise" form — Name + optional muscle group. Pushed from
//  ExercisePickerView; on Save it resolves a catalog Exercise via
//  ExerciseRepository.findOrCreate and hands it back through `onCreate`.
//

import SwiftData
import SwiftUI

/// Muscle-group choices for the picker. `.none` maps to a nil stored value;
/// every other case stores its capitalised name on `Exercise.muscleGroup`.
private enum MuscleGroup: String, CaseIterable, Identifiable {
    case none, chest, back, legs, shoulders, arms, core, cardio, other

    var id: Self { self }

    var label: String { self == .none ? "None" : rawValue.capitalized }

    /// The value written to `Exercise.muscleGroup`.
    var storedValue: String? { self == .none ? nil : rawValue.capitalized }

    /// Best-effort reverse mapping from a stored string.
    init(stored: String?) {
        guard let stored, !stored.isEmpty else { self = .none; return }
        self = MuscleGroup.allCases.first { $0.rawValue.caseInsensitiveCompare(stored) == .orderedSame } ?? .other
    }
}

struct CreateExerciseView: View {
    @Environment(\.modelContext) private var modelContext

    private let onCreate: (Exercise) -> Void

    @State private var name: String
    @State private var muscle: MuscleGroup = .none
    @State private var errorMessage: String?

    private var exercises: ExerciseRepository { ExerciseRepository(context: modelContext) }

    init(prefillName: String = "", onCreate: @escaping (Exercise) -> Void) {
        _name = State(initialValue: prefillName)
        self.onCreate = onCreate
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("e.g. Bench Press", text: $name)
                    .autocorrectionDisabled()
            }
            .listRowBackground(Color.cardBg)

            Section("Muscle Group") {
                Picker("Muscle group", selection: $muscle) {
                    ForEach(MuscleGroup.allCases) { group in
                        Text(group.label).tag(group)
                    }
                }
                .pickerStyle(.menu)
            }
            .listRowBackground(Color.cardBg)
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBg)
        .tint(Color.accentText)
        .navigationTitle("New Exercise")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .fontWeight(.bold)
                    .disabled(trimmedName.isEmpty)
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

    private func save() {
        do {
            let exercise = try exercises.findOrCreate(name: trimmedName, muscleGroup: muscle.storedValue)
            onCreate(exercise)
        } catch {
            errorMessage = "Couldn't create this exercise: \(error.localizedDescription)"
        }
    }
}

#Preview {
    let container = try! ModelContainer.inMemory(seeded: false)
    return NavigationStack {
        CreateExerciseView(prefillName: "Face Pull") { _ in }
    }
    .modelContainer(container)
}
