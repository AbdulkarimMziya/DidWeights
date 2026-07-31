//
//  ActiveWorkoutView.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-06-14.
//

import SwiftUI

enum FinishWorkoutAlert: Identifiable {
    case cancelEmptyWorkout
    case unfinishedSets
    case finishWorkout

    var id: Self { self }
}

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkoutManager.self) private var manager
    @Environment(\.modelContext) private var modelContext

    @State private var activeAlert: FinishWorkoutAlert?
    
    var body: some View {
        NavigationStack {
            Group {
                if let workout = manager.activeWorkout {
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            
                            WorkoutHeaderView(workout: workout)
                            
                            ExerciseListView(exercises: workout.exercises)
                            
                            ActionButtonView()
                        }
                        
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Finish") {
                                    // TODO: Finish action logic
                                    handleFinishTapped()
                                }
                                .fontWeight(.bold)
                                
                            }
                        }
                    }
                    
                } else {
                    ContentUnavailableView(
                        "No Active Workout",
                        systemImage: "dumbbell"
                    )
                }
            }
            .scrollBounceBehavior(.always)
        
            .navigationTitle("Workout Session")
            .padding(.horizontal)
            .alert(item: $activeAlert) { alert in

                switch alert {

                case .cancelEmptyWorkout:

                    return Alert(
                        title: Text("Cancel Workout?"),
                        message: Text("Are you sure you want to cancel this workout? All progress will be lost."),
                        primaryButton: .destructive(Text("Cancel Workout")) {
                            manager.cancelWorkout()
                            dismiss()
                        },
                        secondaryButton: .cancel(Text("Resume"))
                    )

                case .unfinishedSets:

                    // Your unfinished sets alert
                    return Alert (
                        title: Text("Finish Workout?"),
                        message: Text("There are sets in this workout that haven't been marked as completed."),
                        primaryButton: .default(Text("Finish Anyway"), action: {
                            manager.finishWorkout(modelContext: modelContext)
                            dismiss()
                        }),
                        secondaryButton: .cancel(Text("Resume"))
                    )

                case .finishWorkout:

                    // Your finish confirmation
                    return Alert(
                        title: Text("Finish Workout?"),
                        primaryButton: .default(Text("Finish"), action: {
                            manager.finishWorkout(modelContext: modelContext)
                            dismiss()
                        }),
                        secondaryButton: .cancel(Text("Cancel"))
                    )
                }
            }
        }
    }
    
    private func handleFinishTapped() {
        guard let workout = manager.activeWorkout else { return }

        if workout.exercises.isEmpty {
            activeAlert = .cancelEmptyWorkout
            return
        }

        let hasUnfinishedSets = workout.exercises.contains { exercise in
            exercise.sets.contains { !$0.isCompleted }
        }

        if hasUnfinishedSets {
            activeAlert = .unfinishedSets
        } else {
            activeAlert = .finishWorkout
        }
    }
    
}

struct ExerciseListView: View {
    var exercises: [LoggedExercise]

    var body: some View {
        VStack(spacing: 20) {
            ForEach(exercises) { exercise in
                ExerciseRowView(exercise: exercise)
            }
        }
    }
}


struct ExerciseRowView: View {
    let exercise: LoggedExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            ExerciseHeaderView(exercise: exercise)

            SetHeaderView()

            Divider()

            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                WorkoutSetRowView(
                    index: index,
                    exerciseID: exercise.id,
                    workSet: set
                )
            }

            ExerciseActionsView(
                exerciseID: exercise.id,
                setCount: exercise.sets.count
            )
        }
    }
}


struct ExerciseHeaderView: View {
    @Environment(WorkoutManager.self) private var manager

    let exercise: LoggedExercise
    
    private var exerciseNameBinding: Binding<String> {
        Binding {
            exercise.exerciseName
        } set: { newValue in
            manager.updateExerciseName(exerciseID: exercise.id, name: newValue)
        }

    }

    var body: some View {
        HStack {
            TextField("New Exercise", text: exerciseNameBinding)
                .padding(4)
                .frame(width: 200)
                .font(.headline)
                .lineLimit(2)
                

            Spacer()

            Menu {
                Button(role: .destructive) {
                    // Manager: Remove Exercise
                    manager.removeExercise(withID: exercise.id)
                    
                } label: {
                    Label("Remove Exercise", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 24)
                    .background(.secondary)
                    .clipShape(.capsule)
            }
        }
        
    }
}

struct ExerciseActionsView: View {
    @Environment(WorkoutManager.self) private var manager

    let exerciseID: UUID
    let setCount: Int

    var body: some View {
        HStack(spacing: 12) {

            if setCount > 0 {
                Button(role: .destructive) {
                    // Manager: Remove Last Set
                    manager.removeLastSet(from: exerciseID)

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
            }

            Button {
                // Manager: Add Set
                manager.addSet(to: exerciseID)
            } label: {
                Spacer()
                Label("Add Set", systemImage: "plus")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.vertical, 8)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        
    }
}




struct SetHeaderView: View {

    var body: some View {
        HStack {
            Text("Set")
                .frame(width: 35, alignment: .leading)

            Spacer()

            Text("Previous")
                .frame(width: 70, alignment: .center)

            Spacer()

            Text("lbs")
                .frame(width: 60)

            Spacer()

            Text("Reps")
                .frame(width: 50, alignment: .center)

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

struct WorkoutSetRowView: View {
    @Environment(WorkoutManager.self) private var manager
    
    let index: Int
    let exerciseID: UUID
    let workSet: WorkoutSet
    
    @FocusState private var isEditing: Bool
    
    private var weightBinding: Binding<Double?> {
        Binding(
            get: {
                workSet.weight
            },
            set: { newValue in
                manager.updateWeight(
                    exerciseID: exerciseID,
                    setID: workSet.id,
                    weight: newValue
                )
            }
        )
    }
    
    private var repsBinding: Binding<Int?> {
        Binding(
            get: {
                workSet.reps
            },
            set: { newValue in
                manager.updateReps(
                    exerciseID: exerciseID,
                    setID: workSet.id,
                    reps: newValue
                )
            }
        )
    }
    
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
            
            TextField("0", value: weightBinding, format: .number)
                .keyboardType(.decimalPad)
                .focused($isEditing)
                .multilineTextAlignment(.center)
                .frame(width: 55)
                .padding(.vertical, 4)
                .overlay(
                    Capsule()
                        .stroke(.blue)
                )
               
            
            Spacer()
            
            TextField("0", value: repsBinding, format: .number)
                .keyboardType(.numberPad)
                .focused($isEditing)
                .multilineTextAlignment(.center)
                .frame(width: 55)
                .padding(.vertical, 4)
                .overlay(
                    Capsule()
                        .stroke(.blue)
                )
            
            Spacer()
            
            Button {
                manager.toggleSetCompletion(exerciseID: exerciseID, setID: workSet.id)
            } label: {
                Image(systemName: workSet.isCompleted ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(workSet.isCompleted ? .green : .gray)
            }
            .frame(width: 24)
            .buttonStyle(.borderless)

        }
        .padding(.vertical, 4)
        .background(workSet.isCompleted ? .green.opacity(0.2) : .clear)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    isEditing = false
                }
            }
        }
      
    }
}

struct WorkoutHeaderView: View {
    let workout: LoggedWorkout

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
                Text("00:00")
                    .monospacedDigit()
            }
        }
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ActionButtonView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkoutManager.self) private var manager
    
    @State private var showCancelAlert = false
    
    var body: some View {
        VStack(spacing: 12) {
            Button {
                
                // Manager: Add Exercise
                manager.addExercise()
            } label: {
                Text("Add Exercise")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .clipShape(.buttonBorder)
            }
            
            Button(role: .destructive) {
                // TODO: Cancel action
                showCancelAlert = true
            } label: {
                Text("Cancel Workout")
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.15))
                    .clipShape(.buttonBorder)
            }
            .alert("Cancel Workout?", isPresented: $showCancelAlert) {
                Button("Cancel Workout", role: .destructive) {
                       manager.cancelWorkout()
                       dismiss()
                   }

                   Button("Resume", role: .cancel) { }
            } message: {
                Text("Are you sure you want to cancel this workout? All progress will be lost.")
            }
        }
    }
    
}

#Preview {
    // 1. Create a preview instance
    let mockManager = WorkoutManager()
    
    // 2. Start a mock session so the view has an active workout to display
    mockManager.startWorkout()
    
    // 3. (Optional) Populate with a sample exercise so it's not empty in your canvas
    let sampleExercise = LoggedExercise(exerciseID: UUID(), exerciseName: "Bench Press")
    
    mockManager.addExercise()
   

    return ActiveWorkoutView()
        .environment(mockManager) // 4. Inject it here
}
                

