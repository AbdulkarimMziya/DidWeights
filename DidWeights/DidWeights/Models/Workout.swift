//
//  Workout.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-06-06.
//

import Foundation
import SwiftData

@Model
class Workout: Identifiable, Hashable {
    @Attribute(.unique)
    var id = UUID()
    var name: String = "Workout"
    var startDate: Date
    var endDate: Date?
    
    @Attribute(.externalStorage)
    var workoutData: Data
    
    init(name: String = "Workout", workoutData: Data) {
        self.id = UUID()
        self.name = name
        self.startDate = .now
        self.endDate = nil
        self.workoutData = workoutData
    }
}
