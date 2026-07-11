//
//  WorkoutSet.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-06-06.
//

import Foundation

struct WorkoutSet: Codable, Identifiable {
    var id = UUID()
    
    var reps: Int?
    var weight: Double?
    
    var isCompleted = false
    
}
