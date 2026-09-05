//
//  WorkoutRepositoryError.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-08-24.
//

import Foundation

enum WorkoutRepositoryError: Error, Equatable {
    case workoutAlreadyActive
    case multipleActiveWorkouts
    case workoutAlreadyFinished
    case workoutNotActive
    case alreadyPaused
    case notPaused
    case setNotCompletable
    case exerciseNotInWorkout
}
