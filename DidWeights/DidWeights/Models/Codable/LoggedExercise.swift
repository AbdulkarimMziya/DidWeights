//
//  LoggedExercise.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-06-06.
//

import Foundation

struct LoggedExercise: Codable, Identifiable {
    var id = UUID()
    var exerciseID: UUID
    var exerciseName: String
    
    var sets: [WorkoutSet] = []
}
