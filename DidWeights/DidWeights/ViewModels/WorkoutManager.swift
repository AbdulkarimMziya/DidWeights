//
//  WorkoutManager.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-06-06.
//

import Foundation
import SwiftUI

@Observable
class WorkoutManager {
    
    var activeWorkout: LoggedWorkout?
    
    
    // MARK: Start Workout
    func startWorkout() {
        guard activeWorkout == nil else { return }
        self.activeWorkout = LoggedWorkout(startDate: Date())
    }
    
    
    // MARK: End Workout
    func finishWorkout() {
        // TODO: Save to swiftData
        
        // Clear active Workout
        self.activeWorkout = nil
    }
    
    
    // MARK: Add Exercise
    func addExercise(_ exercise: Exercise) {
        let loggedExercise = LoggedExercise(
            exerciseID: exercise.id,
            exerciseName: exercise.name
        )
        
        self.activeWorkout?.exercises.append(loggedExercise)
    }
    
    // MARK: Remove Exercise
    func removeExercise(withID id: UUID) {
        guard let exIndex = exerciseIndex(for: id) else { return }
        
        self.activeWorkout?.exercises.remove(at: exIndex)
    }
    
    
    // MARK: Add Set into Workout Exercises
    func addSet(to exerciseID: UUID) {
        guard let exIndex = exerciseIndex(for: exerciseID) else { return }
        
        let workoutSet = WorkoutSet(reps: nil, weight: nil)
        self.activeWorkout?.exercises[exIndex].sets.append(workoutSet)
    }
    
    // MARK: Remove Set from Workout Exercises
    func removeSet(from exerciseID: UUID, setID: UUID) {
        guard let exIndex = exerciseIndex(for: exerciseID),
              let setIndex = setIndex(exerciseIndex: exIndex, setID: setID)
        else { return }
        
        self.activeWorkout?.exercises[exIndex].sets.remove(at: setIndex)
    }
    
    // MARK: Update Set within Workout Exercises
    func updateSet(exerciseID: UUID, setID: UUID, reps: Int?, weight: Double?) {
        guard
            let exIndex = exerciseIndex(for: exerciseID),
            let setIndex = setIndex(exerciseIndex: exIndex, setID: setID)
        else { return }
        
        self.activeWorkout?.exercises[exIndex].sets[setIndex].reps = reps
        self.activeWorkout?.exercises[exIndex].sets[setIndex].weight = weight
    }
    
    // Helper Functions
    private func exerciseIndex(for exerciseID: UUID) -> Int? {
       return self.activeWorkout?.exercises.firstIndex(where: {$0.id == exerciseID})
    }
    
    private func setIndex(exerciseIndex: Int, setID: UUID) -> Int? {
        return self.activeWorkout?.exercises[exerciseIndex].sets.firstIndex(where: {$0.id == setID})
    }
}
