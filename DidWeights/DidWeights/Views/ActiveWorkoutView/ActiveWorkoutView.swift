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
            Color(.neutral).ignoresSafeArea()
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
        let exerciseGroups = workout.exerciseGroups

        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: .twoX) {
                        WorkoutTitleView(name: workout.name)
                        WorkoutHeaderView(workout: workout, exerciseCount: exerciseGroups.count)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    // Side margins come from the inset-grouped list itself.
                    .listRowInsets(EdgeInsets(top: .oneX, leading: 0, bottom: .oneX, trailing: 0))
                }

                ForEach(exerciseGroups) { group in
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
            // Inset-grouped renders each exercise section as a rounded card,
            // like Home's cards, while keeping List's swipe-to-delete.
            .listStyle(.insetGrouped)
            .listSectionSpacing(.custom(.twoX))
            .scrollContentBackground(.hidden)
            .background(Color(.neutral))
            .scrollBounceBehavior(.always)
            .onTapGesture { focusedField = nil }
            // The workout name lives in the Home-style header at the top of
            // the list, so the bar itself stays empty apart from Finish.
            .navigationBarTitleDisplayMode(.inline)
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
                        primaryButton: .destructive(Text("Finish Anyway"), action: {
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
        // The whole section is one card: title row, column labels, set rows,
        // then the Add Set button.
        Section {
            VStack(alignment: .leading, spacing: .oneX) {
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
                        .tint(Color.red)
                    } label: {
                        // Same treatment as the options button on Home's plan cards.
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.accentText)
                            .frame(width: .fiveX, height: .threeX)
                            .background(Color(.tertiary), in: Capsule())
                    }
                }

                SetHeaderView()
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.cardBg)

            ForEach(Array(group.sets.enumerated()), id: \.element.id) { index, set in
                ExerciseSetRowView(set: set, index: index, focusedField: $focusedField)
                    // tertiary is translucent in dark mode, so it goes over the card
                    // surface instead of replacing it.
                    .listRowBackground(
                        ZStack {
                            Color.cardBg
                            if set.isCompleted { Color(.tertiary) }
                        }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteSet(set)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(Color.red)
                    }
            }

            HStack(spacing: .oneAndAHalfX) {
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
            .listRowBackground(Color.cardBg)
            .listRowInsets(EdgeInsets(top: .oneX, leading: .twoX, bottom: .oneAndAHalfX, trailing: .twoX))
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
        HStack(spacing: .halfX + .quarterX) {
            Text("SET").frame(width: SetColumn.index)
            Text("PREVIOUS").frame(maxWidth: .infinity)
            Text("LBS").frame(width: SetColumn.weight)
            Text("REPS").frame(width: SetColumn.reps)
            Image(systemName: "checkmark")
                .frame(width: SetColumn.check)
        }
        .font(.appMicro.weight(.semibold))
        .foregroundStyle(Color.secondaryTxt)
        .padding(.vertical, .halfX)
    }
}

struct ExerciseSetRowView: View {
    @Bindable var set: ExerciseSet
    let index: Int
    @Environment(\.modelContext) private var modelContext
    @FocusState.Binding var focusedField: ActiveWorkoutContent.Field?

    private var workouts: WorkoutRepository { WorkoutRepository(context: modelContext) }

    var body: some View {
        HStack(spacing: .halfX + .quarterX) {
            Text("\(index + 1)")
                .font(.appBody.weight(.bold))
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
                .font(.appBody.weight(.semibold))
                .frame(width: SetColumn.weight, height: .threeX)
                .background(fieldFill(.weight(set.id)), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .onChange(of: set.weight) {
                    try? workouts.updateSet(set, reps: set.reps, weight: set.weight)
                }

            TextField("0", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .reps(set.id))
                .multilineTextAlignment(.center)
                .font(.appBody.weight(.semibold))
                .frame(width: SetColumn.reps, height: .threeX)
                .background(fieldFill(.reps(set.id)), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .onChange(of: set.reps) {
                    try? workouts.updateSet(set, reps: set.reps, weight: set.weight)
                }

            Button {
                try? workouts.toggleCompletion(of: set)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: .oneX, style: .continuous)
                        .fill(set.isCompleted ? Color("Secondary") : Color.clear)
                    RoundedRectangle(cornerRadius: .oneX, style: .continuous)
                        .stroke(
                            set.isCompleted ? Color("Secondary") : Color.secondaryTxt.opacity(0.5),
                            lineWidth: 1.5
                        )
                    if set.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.primaryBtnTxt)
                    }
                }
                .frame(width: .threeX, height: .threeX)
            }
            .frame(width: SetColumn.check)
            .buttonStyle(.borderless)
        }
    }

    private func fieldFill(_ field: ActiveWorkoutContent.Field) -> Color {
        focusedField == field ? Color(.tertiary) : Color.clear
    }
}

// MARK: - Header

/// Home-style page title: small monospaced eyebrow over a large headline.
struct WorkoutTitleView: View {
    let name: String

    var body: some View {
        VStack(alignment: .leading, spacing: .halfX) {
            Text("CURRENT SESSION ACTIVE")
                .font(.appEyebrow)
                .tracking(0.8)
                .foregroundStyle(Color.metaText)

            Text(name)
                .font(.appDisplay)
                .foregroundStyle(Color.primaryHeadingTxt)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct WorkoutHeaderView: View {
    let workout: Workout
    let exerciseCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: .twoX) {
            VStack(alignment: .leading, spacing: .quarterX) {
                WorkoutTimerView(workout: workout)
                    .font(.appTimer)
                    .foregroundStyle(Color.primaryHeadingTxt)
                Text("Elapsed · \(workout.startDate.formatted(date: .abbreviated, time: .shortened))")
                    .font(.appCaption)
                    .foregroundStyle(Color.secondaryTxt)
            }

            HStack(spacing: .oneAndAHalfX) {
                StatTile(
                    systemImage: "dumbbell.fill",
                    value: "\(exerciseCount)",
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
        .padding(.twoX)
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
        VStack(spacing: .oneAndAHalfX) {
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
