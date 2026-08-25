//
//  WorkoutRepository.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-08-24.
//

import Foundation
import SwiftData

@MainActor
struct WorkoutRepository {
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }

    func activeWorkout() throws -> Workout? {
        var descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.endDate == nil }
        )
        descriptor.fetchLimit = 2
        
        
        let result = try context.fetch(descriptor)
            
        switch result.count {
        case 0:
            return nil
        case 1:
            return result.first
        case 2...:
            throw WorkoutRepositoryError.multipleActiveWorkouts
        default:
            break
        }
        
        return nil
    }
    
    @discardableResult
    func startEmptyWorkout(named name: String, at date: Date = .now) throws -> Workout {
        guard try self.activeWorkout() == nil else { throw WorkoutRepositoryError.workoutAlreadyActive }
        
        let newWorkout = Workout(name: name, startDate: date)
        context.insert(newWorkout)
        
        return newWorkout
    }
    
    @discardableResult
    func startWorkout(from preset: WorkoutPreset, at date: Date = .now) throws -> Workout {
        guard try self.activeWorkout() == nil else { throw WorkoutRepositoryError.workoutAlreadyActive }
        
        let newPresetWorkout = Workout(name: preset.name, startDate: date, preset: preset)
        context.insert(newPresetWorkout)
        
        var curOrder = 0
        for exercise in preset.orderedExercises {
            for _ in 0..<preset.defaultSetCount {
                // create one ExerciseSet here, using curOrder,
                // then increment curOrder
                let curExerciseSet = ExerciseSet(order: curOrder, workout: newPresetWorkout, exercise: exercise)
                context.insert(curExerciseSet)
                curOrder += 1
            }
        }
        
        return newPresetWorkout
    }
    
    func pause(_ workout: Workout, at date: Date = .now) throws {
        guard workout.isActive else { throw WorkoutRepositoryError.workoutNotActive }
        guard !workout.isPaused else { throw WorkoutRepositoryError.alreadyPaused }
        
        workout.pausedAt = date
    }
    
    func resume(_ workout: Workout, at date: Date = .now) throws {
        guard let pausedAt = workout.pausedAt else {
            throw WorkoutRepositoryError.notPaused
        }
        
        let pausedSpan = date.timeIntervalSince(pausedAt)
        workout.accumulatedPause += pausedSpan
        workout.pausedAt = nil
    }
    
    func finish(_ workout: Workout, at date: Date = .now) throws {
        guard workout.isActive else { throw WorkoutRepositoryError.workoutAlreadyFinished }
        
        if workout.isPaused {
            try self.resume(workout, at: date)
        }
        
        workout.endDate = date
        
        // no reps set, no weight set, not completed
        let untouchedSets = workout.sets.filter {
            $0.reps == nil && $0.weight == nil && $0.isCompleted == false
        }
        
        for set in untouchedSets {
            context.delete(set)
        }
        
        for (index, remainigSet) in workout.orderedSets.enumerated() {
            remainigSet.order = index
        }
        
        workout.preset?.lastActive = date
        
        try context.save()
    }
    
    func cancel(_ workout: Workout) throws {
        context.delete(workout)
    }
}
