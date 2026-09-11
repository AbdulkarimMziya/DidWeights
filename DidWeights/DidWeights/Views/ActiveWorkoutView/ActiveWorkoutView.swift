//
//  ActiveWorkoutView.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-06-14.
//

import SwiftData
import SwiftUI

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

    // Once real content has been shown, a subsequent empty query result means
    // the workout was just canceled or finished and dismiss() is already in
    // flight — not a genuine error. Render a blank background instead of the
    // "No Active Workout" error so it doesn't flash while the sheet slides
    // off screen.
    @State private var hasShownWorkout = false

    var body: some View {
        if activeWorkouts.count == 1 {
            ActiveWorkoutContent(workout: activeWorkouts[0])
                .onAppear { hasShownWorkout = true }
        } else if hasShownWorkout {
            Color.appBg.ignoresSafeArea()
        } else if activeWorkouts.isEmpty {
            ContentUnavailableView(
                "No Active Workout",
                systemImage: "exclamationmark.triangle",
                description: Text("Something went wrong starting this session.")
            )
        } else {
            ContentUnavailableView(
                "Multiple Active Workouts Detected",
                systemImage: "exclamationmark.triangle.fill",
                description: Text("This shouldn't be possible — please report this.")
            )
        }
    }
}

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
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
            .scrollContentBackground(.hidden)
            .background(Color.appBg)
            .scrollBounceBehavior(.always)
            .navigationTitle(workout.name)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") {
                        handleFinishTapped()
                    }
                    .fontWeight(.bold)
                    .tint(Color.accentText)
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
                    .listRowBackground(set.isCompleted ? Color.accentSoft : Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteSet(set)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }

            HStack(spacing: Spacing.md) {
                if !group.sets.isEmpty {
                    Button(role: .destructive) {
                        do {
                            try workouts.removeLastSet(of: group.exercise, in: workout)
                        } catch {
                            errorMessage = "Couldn't remove set: \(error.localizedDescription)"
                        }
                    } label: {
                        Label("Delete Set", systemImage: "trash")
                            .destructiveActionLabel(compact: true)
                    }
                    .buttonStyle(.borderless)
                }

                Button {
                    do {
                        try workouts.addSet(to: workout, exercise: group.exercise)
                    } catch {
                        errorMessage = "Couldn't add set: \(error.localizedDescription)"
                    }
                } label: {
                    Label("Add Set", systemImage: "plus")
                        .primaryActionLabel(compact: true)
                }
                .buttonStyle(.borderless)
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
        } header: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text(group.exercise.name)
                        .font(.appHeadline)
                        .foregroundStyle(Color.primaryHeadingTxt)
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
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.accentText)
                            .frame(width: 40, height: 26)
                            .background(Color.accentSoft, in: .capsule)
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
        HStack(spacing: 6) {
            Text("SET").frame(width: SetColumn.index)
            Text("PREVIOUS").frame(maxWidth: .infinity)
            Text("LBS").frame(width: SetColumn.weight)
            Text("REPS").frame(width: SetColumn.reps)
            Image(systemName: "checkmark")
                .frame(width: SetColumn.check)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Color.secondaryTxt)
        .padding(.vertical, 4)
    }
}

struct ExerciseSetRowView: View {
    @Bindable var set: ExerciseSet
    let index: Int
    @Environment(\.modelContext) private var modelContext
    @FocusState.Binding var focusedField: ActiveWorkoutContent.Field?

    private var workouts: WorkoutRepository { WorkoutRepository(context: modelContext) }

    var body: some View {
        HStack(spacing: 6) {
            Text("\(index + 1)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.primaryHeadingTxt)
                .frame(width: SetColumn.index)

            Text("—")
                .font(.appCaption)
                .foregroundStyle(Color.secondaryTxt)
                .frame(maxWidth: .infinity)

            // @Bindable gives a direct binding to the model - no manual
            TextField("0", value: $set.weight, format: .number)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .weight(set.id))
                .multilineTextAlignment(.center)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: SetColumn.weight)
                .padding(.vertical, 7)
                .background(fieldFill(.weight(set.id)), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.inputfieldBorder, lineWidth: 1)
                )
                .onChange(of: set.weight) {
                    try? workouts.updateSet(set, reps: set.reps, weight: set.weight)
                }

            TextField("0", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .reps(set.id))
                .multilineTextAlignment(.center)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: SetColumn.reps)
                .padding(.vertical, 7)
                .background(fieldFill(.reps(set.id)), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.inputfieldBorder, lineWidth: 1)
                )
                .onChange(of: set.reps) {
                    try? workouts.updateSet(set, reps: set.reps, weight: set.weight)
                }

            Button {
                try? workouts.toggleCompletion(of: set)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(set.isCompleted ? Color.primaryBtn : Color.clear)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            set.isCompleted ? Color.primaryBtn : Color.secondaryTxt.opacity(0.5),
                            lineWidth: 1.5
                        )
                    if set.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.primaryBtnTxt)
                    }
                }
                .frame(width: 26, height: 26)
            }
            .frame(width: SetColumn.check)
            .buttonStyle(.borderless)
        }
    }

    private func fieldFill(_ field: ActiveWorkoutContent.Field) -> Color {
        focusedField == field ? Color.accentSoft : Color.clear
    }
}

// MARK: - Header

struct WorkoutHeaderView: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: 2) {
                WorkoutTimerView(workout: workout)
                    .font(.appTimer)
                    .foregroundStyle(Color.primaryHeadingTxt)
                Text("Elapsed · \(workout.startDate.formatted(date: .abbreviated, time: .shortened))")
                    .font(.appCaption)
                    .foregroundStyle(Color.secondaryTxt)
            }

            HStack(spacing: Spacing.md) {
                StatTile(
                    systemImage: "dumbbell.fill",
                    value: "\(workout.exerciseGroups.count)",
                    label: "Exercises"
                )
                StatTile(
                    systemImage: "repeat",
                    value: "\(workout.totalReps)",
                    label: "Reps"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .appCard()
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
        VStack(spacing: Spacing.md) {
            Button {
                showAddExercise = true
            } label: {
                Text("Add Exercise").primaryActionLabel()
            }
            // .borderless so this row's two buttons are hit-tested
            // independently inside the List — otherwise every tap in the
            // row activates the first button and "Cancel Workout" opens
            // the Add Exercise sheet.
            .buttonStyle(.borderless)

            Button(role: .destructive) {
                showCancelAlert = true
            } label: {
                Text("Cancel Workout").plainDestructiveLabel()
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
