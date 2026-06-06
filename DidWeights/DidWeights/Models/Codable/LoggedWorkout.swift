//
//  LoggedWorkout.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-06-06.
//

import Foundation

struct LoggedWorkout: Codable, Identifiable {
    var id = UUID()
    
    var startDate: Date
    
    var exercises: [LoggedExercise] = []
}
