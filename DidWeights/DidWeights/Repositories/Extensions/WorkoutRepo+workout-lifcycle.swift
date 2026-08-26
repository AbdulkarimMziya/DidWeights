//
//  WorkoutRepo+workout-lifcycle.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-08-25.
//

import Foundation
import SwiftData

extension WorkoutRepository {
    
    @discardableResult
    func addExercise(_ exercise: Exercise, to workout: Workout, setCount: Int) throws -> [ExerciseSet] {
        guard setCount > 0 else { return [] }
        
        let startingOrder = workout.orderedSets.count
        
        var createdSets = [ExerciseSet]()
        
        for i in 0..<setCount {
            let curOrder = startingOrder + i
            
            let exerciseSet = ExerciseSet(order: curOrder, workout: workout, exercise: exercise)
            
            context.insert(exerciseSet)
            createdSets.append(exerciseSet)
        }
        
        return createdSets
    }
    
    func removeExercise(_ exercise: Exercise, from workout: Workout) throws {
        let removedExerciseSets = workout.sets.filter { $0.exercise == exercise }
        
        for removedSet in removedExerciseSets {
            context.delete(removedSet)
        }
        
        for (index, remainingExerciseSet) in workout.orderedSets.enumerated() {
            remainingExerciseSet.order = index
        }
    }
    
    @discardableResult
    func addSet(to workout: Workout, exercise: Exercise) throws -> ExerciseSet {
        let startingOrder = workout.orderedSets.count
        
        let newSet = ExerciseSet(order: startingOrder, workout: workout, exercise: exercise)
        context.insert(newSet)
        
        return newSet
    }
    
    func removeSet(_ set: ExerciseSet) throws {
        guard let workout = set.workout else { return }
        
        context.delete(set)
            
        for (newIndex, remainingSet) in workout.orderedSets.enumerated() {
            remainingSet.order = newIndex
        }
    }
    
    func removeLastSet(of exercise: Exercise, in workout: Workout) throws {
        let exerciseSets = workout.orderedSets.filter { $0.exercise == exercise }
        
        guard let lastSet = exerciseSets.last else { return }
        
        try removeSet(lastSet)
    }
    
    func updateSet(_ set: ExerciseSet, reps: Int?, weight: Double?) throws {
        // 1. Write the values on every keystroke
        set.reps = reps
        set.weight = weight
        
        // 2. Enforce consistency: If it was completed but reps are now cleared or 0, un-complete it
        if set.isCompleted {
            if reps == nil || reps! <= 0 {
                set.isCompleted = false
                set.completedAt = nil
            }
        }
    }
    
    func toggleCompletion(of set: ExerciseSet) throws {
        if set.isCompleted {
            // going from completed -> not completed: always allowed
            set.isCompleted = false
            set.completedAt = nil
        } else {
            // going from not completed -> completed: needs valid reps
            guard let reps = set.reps, reps > 0 else {
                throw WorkoutRepositoryError.setNotCompletable
            }
            set.isCompleted = true
            set.completedAt = .now
        }
    }

}
