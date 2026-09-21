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
    // Called once with the chosen exercise, then the caller is expected to dismiss.
    let onPick: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var catalog: [Exercise]

    @State private var path = NavigationPath()
    @State private var searchText = ""
    @FocusState private var searchFieldFocused: Bool

    private var filtered: [Exercise] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return catalog }
        return catalog.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
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
                                onPick(exercise)
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
            .onTapGesture { searchFieldFocused = false }
            .navigationTitle("Add Exercise")
            .safeAreaInset(edge: .bottom) {
                searchBar
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(Color.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        path.append(PickerRoute.create(nil))
                    } label: {
                        Image(systemName: "plus")
                    }
                    .tint(Color.accentText)
                    .accessibilityLabel("Create New Exercise")
                }
            }
            .navigationDestination(for: PickerRoute.self) { route in
                switch route {
                case .create(let prefill):
                    CreateExerciseView(prefillName: prefill ?? "") { newExercise in
                        onPick(newExercise)
                        dismiss()
                    }
                }
            }
        }
    }

    // Bottom-pinned search field — `.searchable` has no bottom placement,
    // so this is a hand-built stand-in, styled with the same rounded-rect
    // rhythm as the rest of the app.
    private var searchBar: some View {
        HStack(spacing: .oneX) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.secondaryTxt)
            TextField("Search exercises", text: $searchText)
                .focused($searchFieldFocused)
                .foregroundStyle(Color.primaryHeadingTxt)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.secondaryTxt)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, .oneAndAHalfX)
        .frame(height: 44)
        .background(Color.cardBg, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                .stroke(Color.inputfieldBorder, lineWidth: 1)
        )
        .padding(.horizontal, .twoX)
        .padding(.vertical, .oneX)
        .background(Color.appBg)
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        HStack(spacing: .oneAndAHalfX) {
            ExerciseThumbnail(muscleGroup: exercise.muscleGroup, size: 36)

            VStack(alignment: .leading, spacing: .quarterX) {
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
    return ExercisePickerView { exercise in
        print("picked \(exercise.name)")
    }
    .modelContainer(container)
}
