//
//  WorkoutManager.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-06-06.
//

import Foundation
import SwiftUI
import SwiftData

@Observable
class WorkoutManager {
    
    // MARK: State
    var activeWorkout: LoggedWorkout? {
        didSet {
            persistActiveWorkout()
        }
    }
    
    var isWorkoutActive: Bool = false
    
    private let activeWorkoutKey = "com.didweights.activeWorkoutDraft"
    
    init() {
        restoreActiveWorkout()
    }

    
    // MARK: Persistence for in-progress draft
    private func persistActiveWorkout() {
        guard let activeWorkout else {
            UserDefaults.standard.removeObject(forKey: activeWorkoutKey)
            return
        }
        
        do {
            let data = try PersistanceHelper.transformToData(activeWorkout)
            UserDefaults.standard.set(data, forKey: activeWorkoutKey)
        } catch {
            print("Failed to persist active workout: \(error)")
        }
    }

    private func restoreActiveWorkout() {
        guard let data = UserDefaults.standard.data(forKey: activeWorkoutKey) else { return }
        
        do {
            let restored = try PersistanceHelper.transformFromData(data)
            self.activeWorkout = restored
            self.isWorkoutActive = true
        } catch {
            print("Failed to restore active workout: \(error)")
            UserDefaults.standard.removeObject(forKey: activeWorkoutKey)
        }
    }
    
    // MARK: Session
    /**
     * func startWorkout()
     * func finishWorkout()
     * func cancelWorkout()
     * func sanitizeForSaving()
     **/
    
    // Start Workout
    func startWorkout() {
        guard activeWorkout == nil else { return }
        
        self.isWorkoutActive = true
        self.activeWorkout = LoggedWorkout(startDate: Date())
    }
    
    func startWorkout(from savedWorkout: SavedWorkout) {
        guard activeWorkout == nil else { return }

        do {
            let template = try PersistanceHelper.transformFromData(savedWorkout.workoutData)

            // Fresh session identity, but keep the exercise/set structure from the plan
            let newWorkout = LoggedWorkout(
                id: UUID(),
                name: savedWorkout.name,
                startDate: Date(),
                exercises: template.exercises.map { exercise in
                    LoggedExercise(
                        exerciseID: exercise.exerciseID,
                        exerciseName: exercise.exerciseName,
                        sets: exercise.sets.map { _ in WorkoutSet(reps: nil, weight: nil) }
                    )
                }
            )

            self.activeWorkout = newWorkout
            self.isWorkoutActive = true
        } catch {
            print("Failed to load workout plan: \(error)")
        }
    }
    
    // End Workout
    func finishWorkout(modelContext: ModelContext) {
        guard let activeWorkout else { return }
        
        let cleaned = sanitizedForSaving(activeWorkout)

        do {
            
            let data = try PersistanceHelper.transformToData(cleaned)
            
            let persistWorkout = Workout(
                name: cleaned.name,
                startDate: cleaned.startDate,
                endDate: Date(),
                workoutData: data
            )
            
            // Save in model Container
            modelContext.insert(persistWorkout)
            
            // Clear active Workout
            self.activeWorkout = nil
            self.isWorkoutActive = false
        } catch {
            print("Failed to save session record: \(error)")
        }
    }
    
    // MARK: Sanitization
    
    /// Strips genuinely blank sets (never touched: no reps, no weight, not completed)
    /// and any exercise left with zero sets after that cleanup, before persisting.
    private func sanitizedForSaving(_ workout: LoggedWorkout) -> LoggedWorkout {
        var cleaned = workout

        cleaned.exercises = workout.exercises.compactMap { exercise in
            let keptSets = exercise.sets.filter { set in
                guard let reps = set.reps, reps > 0 else { return false }
                return true
            }

            guard !keptSets.isEmpty else { return nil }

            var cleanedExercise = exercise
            cleanedExercise.sets = keptSets
            return cleanedExercise
        }

        return cleaned
    }
    
    // Cancel Workout
    func cancelWorkout() {
        self.activeWorkout = nil
        self.isWorkoutActive = false
    }
    
    
    // MARK: Exercises
    /**
     * func addExercise()
     * func removeExercise()
     **/
    
    // Add Exercise
    func addExercise() {
        let newExercise = LoggedExercise(exerciseID: UUID(), exerciseName: "")
        self.activeWorkout?.exercises.append(newExercise)
    }
    
    // Remove Exercise
    func removeExercise(withID id: UUID) {
        guard let exIndex = exerciseIndex(for: id) else { return }
        
        self.activeWorkout?.exercises.remove(at: exIndex)
    }
    
    
    // MARK: Add,Remove,Update Set into Workout Exercises
    /**
     * func addSet()
     * func removeSet()
     * func removeLastSet()
     * func toggleSetCompletion()
     * func updateWeight()
     * func updateReps()
     * func updateExerciseName()
     **/
    // Add Set to each exercise
    func addSet(to exerciseID: UUID) {
        guard let exIndex = exerciseIndex(for: exerciseID) else { return }
        
        let workoutSet = WorkoutSet(reps: nil, weight: nil)
        self.activeWorkout?.exercises[exIndex].sets.append(workoutSet)
    }
    
    // Remove Set from Workout Exercises
    func removeSet(from exerciseID: UUID, setID: UUID) {
        guard let exIndex = exerciseIndex(for: exerciseID),
              let setIndex = setIndex(exerciseIndex: exIndex, setID: setID)
        else { return }
        
        self.activeWorkout?.exercises[exIndex].sets.remove(at: setIndex)
    }
    
    // Remove Last Set from Workout Exercises
    func removeLastSet(from exerciseID: UUID) {
        guard
            let exerciseIndex = exerciseIndex(for: exerciseID),
            !activeWorkout!.exercises[exerciseIndex].sets.isEmpty
        else { return }

        activeWorkout?.exercises[exerciseIndex].sets.removeLast()
    }
    
    // Toggle Completion for each set
    func toggleSetCompletion(exerciseID: UUID, setID: UUID ) {
        guard
            let exIndex = exerciseIndex(for: exerciseID),
            let setIndex = setIndex(exerciseIndex: exIndex, setID: setID)
        else { return }
        
        let set = activeWorkout!.exercises[exIndex].sets[setIndex]
        
        // Allow un-completing freely, but require valid reps to mark complete
        if !set.isCompleted {
            guard let reps = set.reps, reps > 0 else {
                print("Cannot complete a set with no reps entered.")
                return
            }
        }

        self.activeWorkout?.exercises[exIndex].sets[setIndex].isCompleted.toggle()
    }
    
    func updateWeight(exerciseID: UUID, setID: UUID, weight: Double?) {
        guard
            let exIndex = exerciseIndex(for: exerciseID),
            let setIndex = setIndex(exerciseIndex: exIndex, setID: setID)
        else { return }

        activeWorkout?.exercises[exIndex].sets[setIndex].weight = weight
    }
    
    func updateReps(exerciseID: UUID, setID: UUID, reps: Int?) {
        guard
            let exIndex = exerciseIndex(for: exerciseID),
            let setIndex = setIndex(exerciseIndex: exIndex, setID: setID)
        else { return }

        activeWorkout?.exercises[exIndex].sets[setIndex].reps = reps
    }
    
    func updateExerciseName(exerciseID: UUID, name: String) {
        guard
            let exIndex = exerciseIndex(for: exerciseID)
        else { return }
        
        activeWorkout?.exercises[exIndex].exerciseName = name
    }
    
    // Helper Functions
    private func exerciseIndex(for exerciseID: UUID) -> Int? {
       return self.activeWorkout?.exercises.firstIndex(where: {$0.id == exerciseID})
    }
    
    private func setIndex(exerciseIndex: Int, setID: UUID) -> Int? {
        return self.activeWorkout?.exercises[exerciseIndex].sets.firstIndex(where: {$0.id == setID})
    }
}
