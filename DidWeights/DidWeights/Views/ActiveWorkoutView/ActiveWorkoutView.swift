//
//  ActiveWorkoutView.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-06-14.
//

import SwiftData
import SwiftUI

private enum ActivePalette {
    static let primaryButtonBackground = Color("PrimaryBtnBG")
    static let primaryButtonText = Color("PrimaryBtnText")
    static let pillBackground = Color("PillBackground")
}

enum FinishWorkoutAlert: Identifiable {
    case cancelEmptyWorkout
    case unfinishedSets
    case finishWorkout

    var id: Self { self }
}

/// Wrapper:  owns the query, decides which of three states to render.
struct ActiveWorkoutView: View {
    @Query(
        filter: #Predicate<Workout> { $0.endDate == nil },
        sort: \Workout.startDate, order: .reverse
    )
    private var activeWorkouts: [Workout]

    var body: some View {
        switch activeWorkouts.count {
        case 0:
            ContentUnavailableView(
                "No Active Workout",
                systemImage: "exclamationmark.triangle",
                description: Text("Something went wrong starting this session.")
            )
        case 1:
            ActiveWorkoutContent(workout: activeWorkouts[0])
        default:
            ContentUnavailableView(
                "Multiple Active Workouts Detected",
                systemImage: "exclamationmark.triangle.fill",
                description: Text("This shouldn't be possible — please report this.")
            )
        }
    }
}

/// Content: takes one live Workout, every mutation goes through
/// WorkoutRepository (and ExerciseRepository for catalog lookups).
struct ActiveWorkoutContent: View {
    @Bindable var workout: Workout
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var workouts: WorkoutRepository { WorkoutRepository(context: modelContext) }
    private var exercises: ExerciseRepository { ExerciseRepository(context: modelContext) }

    @State private var activeAlert: FinishWorkoutAlert?
    @State private var errorMessage: String?
    @State private var showAddExercise = false
    @FocusState private var focusedField: Field?

    // A Hashable enum instead of a bare UUID, so weight and reps fields on
    // the same set never share one focus identity (the old bug where
    // "next field" couldn't work because both fields used workSet.id).
    enum Field: Hashable {
        case reps(UUID)
        case weight(UUID)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    WorkoutHeaderView(workout: workout)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }

                ForEach(workout.exerciseGroups) { group in
                    ExerciseGroupView(
                        workout: workout,
                        group: group,
                        focusedField: $focusedField,
                        errorMessage: $errorMessage
                    )
                }

                Section {
                    ActionButtonView(
                        workout: workout,
                        showAddExercise: $showAddExercise
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollBounceBehavior(.always)
            .navigationTitle(workout.name)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") {
                        handleFinishTapped()
                    }
                    .fontWeight(.bold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .sheet(isPresented: $showAddExercise) {
                AddExerciseSheet(workout: workout)
            }
            .alert("Something went wrong", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert(item: $activeAlert) { alert in
                switch alert {
                case .cancelEmptyWorkout:
                    return Alert(
                        title: Text("Cancel Workout?"),
                        message: Text("Are you sure you want to cancel this workout? All progress will be lost."),
                        primaryButton: .destructive(Text("Cancel Workout")) {
                            performCancel()
                        },
                        secondaryButton: .cancel(Text("Resume"))
                    )
                case .unfinishedSets:
                    return Alert(
                        title: Text("Finish Workout?"),
                        message: Text("There are sets in this workout that haven't been marked as completed."),
                        primaryButton: .default(Text("Finish Anyway"), action: {
                            performFinish()
                        }),
                        secondaryButton: .cancel(Text("Resume"))
                    )
                case .finishWorkout:
                    return Alert(
                        title: Text("Finish Workout?"),
                        primaryButton: .default(Text("Finish"), action: {
                            performFinish()
                        }),
                        secondaryButton: .cancel(Text("Cancel"))
                    )
                }
            }
        }
    }

    // MARK: - Finish flow

    private func handleFinishTapped() {
        // No exercises at all: use exerciseGroups, since there's no
        // separate LoggedExercise array anymore — an exercise only
        // "exists" in a workout by virtue of having sets.
        if workout.exerciseGroups.isEmpty {
            activeAlert = .cancelEmptyWorkout
            return
        }

        // Any set not completed, checked directly against the flat
        // sets relationship — grouping isn't needed for this check.
        let hasUnfinishedSets = workout.sets.contains { !$0.isCompleted }

        activeAlert = hasUnfinishedSets ? .unfinishedSets : .finishWorkout
    }

    private func performFinish() {
        do {
            try workouts.finish(workout)
            dismiss()
        } catch {
            errorMessage = "Couldn't finish this workout: \(error.localizedDescription)"
        }
    }

    private func performCancel() {
        do {
            try workouts.cancel(workout)
            dismiss()
        } catch {
            errorMessage = "Couldn't cancel this workout: \(error.localizedDescription)"
        }
    }
}

// MARK: - Exercise list

/// One `List` section per exercise: the set rows (each swipe-to-delete),
/// followed by an "Add Set" / "Delete Set" button row. Header carries the
/// exercise name, the remove-exercise menu, and the column labels.
struct ExerciseGroupView: View {
    let workout: Workout
    let group: ExerciseGroup
    @Environment(\.modelContext) private var modelContext
    @FocusState.Binding var focusedField: ActiveWorkoutContent.Field?
    @Binding var errorMessage: String?

    private var workouts: WorkoutRepository { WorkoutRepository(context: modelContext) }

    var body: some View {
        Section {
            ForEach(Array(group.sets.enumerated()), id: \.element.id) { index, set in
                ExerciseSetRowView(set: set, index: index, focusedField: $focusedField)
                    .listRowBackground(set.isCompleted ? Color.green.opacity(0.2) : Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteSet(set)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }

            HStack(spacing: 12) {
                if !group.sets.isEmpty {
                    Button(role: .destructive) {
                        do {
                            try workouts.removeLastSet(of: group.exercise, in: workout)
                        } catch {
                            errorMessage = "Couldn't remove set: \(error.localizedDescription)"
                        }
                    } label: {
                        Spacer()
                        Label("Delete Set", systemImage: "trash")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .buttonStyle(.borderless)
                }

                Button {
                    do {
                        try workouts.addSet(to: workout, exercise: group.exercise)
                    } catch {
                        errorMessage = "Couldn't add set: \(error.localizedDescription)"
                    }
                } label: {
                    Spacer()
                    Label("Add Set", systemImage: "plus")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(ActivePalette.primaryButtonText)
                    Spacer()
                }
                .padding(.vertical, 8)
                .background(ActivePalette.primaryButtonBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .buttonStyle(.borderless)
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
        } header: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(group.exercise.name)
                        .font(.headline)
                    Spacer()
                    Menu {
                        Button(role: .destructive) {
                            do {
                                try workouts.removeExercise(group.exercise, from: workout)
                            } catch {
                                errorMessage = "Couldn't remove exercise: \(error.localizedDescription)"
                            }
                        } label: {
                            Label("Remove Exercise", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 28))
                            .foregroundStyle(ActivePalette.primaryButtonText)
                            .frame(width: 40, height: 24)
                            .background(ActivePalette.pillBackground)
                            .clipShape(.capsule)
                    }
                }

                SetHeaderView()
            }
        }
    }

    private func deleteSet(_ set: ExerciseSet) {
        do {
            try workouts.removeSet(set)
        } catch {
            errorMessage = "Couldn't remove set: \(error.localizedDescription)"
        }
    }
}

struct SetHeaderView: View {
    var body: some View {
        HStack {
            Text("Set").frame(width: 35, alignment: .leading)
            Spacer()
            Text("Previous").frame(width: 70, alignment: .center)
            Spacer()
            Text("lbs").frame(width: 60)
            Spacer()
            Text("Reps").frame(width: 50, alignment: .center)
            Spacer()
            Image(systemName: "checkmark.square.fill")
                .frame(width: 30, alignment: .trailing)
                .foregroundStyle(.secondary)
        }
        .padding(4)
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
    }
}

struct ExerciseSetRowView: View {
    @Bindable var set: ExerciseSet
    let index: Int
    @Environment(\.modelContext) private var modelContext
    @FocusState.Binding var focusedField: ActiveWorkoutContent.Field?

    private var workouts: WorkoutRepository { WorkoutRepository(context: modelContext) }

    var body: some View {
        HStack {
            Text("\(index + 1)")
                .font(.subheadline)
                .fontWeight(.bold)
                .frame(width: 35, alignment: .center)

            Spacer()

            Text("—")
                .frame(width: 70, alignment: .center)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Spacer()

            // @Bindable gives a direct binding to the model - no manual
            TextField("0", value: $set.weight, format: .number)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .weight(set.id))
                .multilineTextAlignment(.center)
                .frame(width: 55)
                .padding(.vertical, 4)
                .overlay(Capsule().stroke(.blue))
                .onChange(of: set.weight) {
                    try? workouts.updateSet(set, reps: set.reps, weight: set.weight)
                }

            Spacer()

            TextField("0", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .reps(set.id))
                .multilineTextAlignment(.center)
                .frame(width: 55)
                .padding(.vertical, 4)
                .overlay(Capsule().stroke(.blue))
                .onChange(of: set.reps) {
                    try? workouts.updateSet(set, reps: set.reps, weight: set.weight)
                }

            Spacer()

            Button {
                try? workouts.toggleCompletion(of: set)
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(set.isCompleted ? .green : .gray)
            }
            .frame(width: 24)
            .buttonStyle(.borderless)
        }
    }
}

// MARK: - Header

struct WorkoutHeaderView: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .frame(width: 20)
                    .foregroundColor(.blue)
                Text(workout.startDate, style: .date)
            }
            HStack(spacing: 12) {
                Image(systemName: "clock")
                    .frame(width: 20)
                    .foregroundColor(.green)
                WorkoutTimerView(workout: workout)
            }
        }
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Bottom actions

struct ActionButtonView: View {
    let workout: Workout
    @Binding var showAddExercise: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showCancelAlert = false
    @State private var errorMessage: String?

    private var workouts: WorkoutRepository { WorkoutRepository(context: modelContext) }

    var body: some View {
        VStack(spacing: 12) {
            Button {
                showAddExercise = true
            } label: {
                Text("Add Exercise")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(ActivePalette.primaryButtonText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ActivePalette.primaryButtonBackground)
                    .clipShape(.buttonBorder)
            }
            // .borderless so this row's two buttons are hit-tested
            // independently inside the List — otherwise every tap in the
            // row activates the first button and "Cancel Workout" opens
            // the Add Exercise sheet.
            .buttonStyle(.borderless)

            Button(role: .destructive) {
                showCancelAlert = true
            } label: {
                Text("Cancel Workout")
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .clipShape(.buttonBorder)
            }
            .buttonStyle(.borderless)
        }
        .alert("Cancel Workout?", isPresented: $showCancelAlert) {
            Button("Cancel Workout", role: .destructive) {
                do {
                    try workouts.cancel(workout)
                    dismiss()
                } catch {
                    errorMessage = "Couldn't cancel this workout."
                }
            }
            Button("Resume", role: .cancel) {}
        } message: {
            Text("Are you sure you want to cancel this workout? All progress will be lost.")
        }
    }
}

#Preview {
    let container = try! ModelContainer.inMemory(seeded: true)
    let context = container.mainContext
    let descriptor = FetchDescriptor<Workout>()
    let workout = (try? context.fetch(descriptor))?.first ?? Workout(name: "Preview")

    return ActiveWorkoutContent(workout: workout)
        .modelContainer(container)
}
