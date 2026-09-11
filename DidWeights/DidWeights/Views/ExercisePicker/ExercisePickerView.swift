//
//  ExercisePickerView.swift
//  DidWeights
//
//  The shared "Add Exercise" screen. Search the catalog, tap one exercise to
//  pick it, or push the Create form. It never writes to the store — it resolves
//  exactly one Exercise and hands it to `onPick`; the caller decides what to do
//  with it (add sets to a workout, append to a plan).
//

import SwiftData
import SwiftUI

private enum PickerRoute: Hashable {
    case create(String?)
}

struct ExercisePickerView: View {
    // Shows the "Sets to add" stepper (active-workout context only).
    let showSetCount: Bool
    // Called once with the chosen exercise and the current set count, then the caller is expected to dismiss.
    let onPick: (Exercise, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var catalog: [Exercise]

    @State private var path = NavigationPath()
    @State private var searchText = ""
    @State private var setCount = 3

    private var filtered: [Exercise] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return catalog }
        return catalog.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Button {
                        path.append(PickerRoute.create(nil))
                    } label: {
                        Label("Create New Exercise", systemImage: "plus")
                            .primaryActionLabel()
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                if showSetCount {
                    Section {
                        Stepper("Sets to add: \(setCount)", value: $setCount, in: 1...10)
                    }
                    .listRowBackground(Color.cardBg)
                }

                Section("Your Exercises") {
                    if filtered.isEmpty {
                        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                            Text("No exercises yet, create your first one above.")
                                .font(.appCaption)
                                .foregroundStyle(Color.secondaryTxt)
                        } else {
                            Button {
                                path.append(PickerRoute.create(searchText))
                            } label: {
                                Label("Create \u{201C}\(searchText)\u{201D}", systemImage: "plus")
                                    .foregroundStyle(Color.accentText)
                            }
                        }
                    } else {
                        ForEach(filtered) { exercise in
                            Button {
                                onPick(exercise, setCount)
                                dismiss()
                            } label: {
                                exerciseRow(exercise)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listRowBackground(Color.cardBg)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBg)
            .tint(Color.accentText)
            .navigationTitle("Add Exercise")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search exercises"
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(for: PickerRoute.self) { route in
                switch route {
                case .create(let prefill):
                    CreateExerciseView(prefillName: prefill ?? "") { newExercise in
                        onPick(newExercise, setCount)
                        dismiss()
                    }
                }
            }
        }
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        HStack(spacing: Spacing.md) {
            ExerciseThumbnail(muscleGroup: exercise.muscleGroup, size: 36)

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

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.secondaryTxt.opacity(0.6))
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    let container = try! ModelContainer.inMemory(seeded: true)
    return ExercisePickerView(showSetCount: true) { exercise, count in
        print("picked \(exercise.name) x\(count)")
    }
    .modelContainer(container)
}
