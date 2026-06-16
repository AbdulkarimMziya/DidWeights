//
//  ActiveWorkoutView.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-06-14.
//

import SwiftUI

struct ActiveWorkoutView: View {
    @State private var testWorkout = tempWorkouts
    @State private var isWorkoutActive = true
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(spacing: 24) { // Explicit vertical spacing between major sections
                    
                    // MARK: - Workout Meta Header Card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .frame(width: 20)
                                .foregroundColor(.blue)
                            Text(testWorkout.startDate, style: .date)
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: "clock")
                                .frame(width: 20)
                                .foregroundColor(.green)
                            Text("00:00")
                                .monospacedDigit() // Prevents text layout jitter during updates
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    
                    // MARK: - Exercise List Stack
                    VStack(spacing: 20) {
                        ForEach($testWorkout.exercises) { $exercise in
                            ExerciseRowView(exercise: $exercise)
                        }
                        
                        Section {
                            ActionButtonView()
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 8)
                }
                .padding(.vertical)
            }
            .scrollBounceBehavior(.always)
            .navigationTitle("Workout Session")
            .preferredColorScheme(.light)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") {
                        // TODO: Finish action logic
                    }
                    .fontWeight(.bold)
                    
                }
            }
        }
    }
}


struct ExerciseRowView: View {
    // LoggedExercise
    @Binding var exercise: LoggedExercise
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(exercise.exerciseName)
                .font(.headline)
            
            // Grid Headers
            HStack {
                Text("Set").frame(width: 35, alignment: .leading)
                Spacer()
                Text("Previous").frame(width: 70, alignment: .center)
                Spacer()
                Text("lbs").frame(width: 60, alignment: .center)
                Spacer()
                Text("Reps").frame(width: 50, alignment: .center)
                Spacer()
                Image(systemName: "checkmark.square.fill")
                    .frame(width: 30, alignment: .trailing)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(4)
            
            
            Divider()
            
            // Loop nested sets here
            ForEach(Array($exercise.sets.enumerated()), id: \.element.id) { index, $workSet in
                
                HStack {
                    Text("\(index + 1)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .frame(width: 35, alignment: .center)
                    
                    Spacer()
                    
                    Text("—")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .center)
                    
                    Spacer()
                    
                    TextField(
                        "0",
                        value: Binding(
                            get: { workSet.weight ?? 0 },
                            set: { workSet.weight = $0 }
                        ),
                        format: .number
                    )
                    .padding(.vertical, 4)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
                    .frame(width: 50)
                    .multilineTextAlignment(.center)
                    .clipShape(.capsule)
                    .overlay(
                        Capsule()
                            .stroke(.blue, lineWidth: 1)
                    )
                    
                    Spacer()
                    
                    TextField(
                        "0",
                        value: Binding(
                            get: { workSet.reps ?? 0 },
                            set: { workSet.reps = $0 }
                        ),
                        format: .number
                    )
                    .padding(.vertical, 4)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
                    .frame(width: 50)
                    .multilineTextAlignment(.center)
                    .clipShape(.capsule)
                    .overlay(
                        Capsule()
                            .stroke(.blue, lineWidth: 1)
                    )
                    
                    Spacer()
                    
                    Button {
                        if workSet.canBeCompleted {
                            workSet.isCompleted.toggle()
                        }
                    } label: {
                        Image(systemName: workSet.isCompleted ? "checkmark.square.fill" :  "square")
                            .font(.title2)
                            .foregroundStyle(workSet.isCompleted ? .green : .gray)
                    }
                    .frame(width: 30, alignment: .trailing)
                    .buttonStyle(.borderless)
                    
                }
                .padding(.vertical, 8)
                // 1. Add extra horizontal padding inside the row item container
                .padding(.horizontal, 12)
                // 2. Expand the container boundary box to edge-to-edge max limits
                .frame(maxWidth: .infinity)
                // 3. Render color layer across the fully expanded bounding box width frame
                .background(workSet.isCompleted ? Color(.systemGreen).opacity(0.15) : Color.clear)
                // 4. Offset layout margins to match parent padding context
                .padding(.horizontal, -12)
                .onChange(of: workSet.canBeCompleted) { _ , canComplete in
                    if !canComplete {
                        workSet.isCompleted = false
                    }
                }
                
                
                
            }
            
            VStack {
                HStack(spacing: 12) {
                    // 1. DELETE BUTTON
                    Button(role: .destructive) {
                        // Action to handle deleting a set (e.g., removing the last set entry)
                        if !exercise.sets.isEmpty {
                            exercise.sets.removeLast()
                        }
                    } label: {
                        HStack {
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
                    
                    // 2. ADD BUTTON
                    Button {
                        exercise.sets.append(WorkoutSet())
                    } label: {
                        HStack {
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
                .padding(.top, 12)
            }
        }

        
    }
    
    func deleteSet(at index: Int) {
        exercise.sets.remove(at: index)
    }
}

struct ActionButtonView: View {
    var body: some View {
        VStack(spacing: 12) {
            Button {
                // TODO: Open add exercise flow
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
            } label: {
                Text("Cancel Workout")
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.15))
                    .clipShape(.buttonBorder)
            }
        }
    }
}

#Preview {
    ActiveWorkoutView()
}
