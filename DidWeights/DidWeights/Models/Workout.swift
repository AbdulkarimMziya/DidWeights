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
    
    var startDate: Date
    var endDate: Date
    
    @Attribute(.externalStorage)
    var workoutData: Data
    
    init(id: UUID = UUID(), startDate: Date, endDate: Date, workoutData: Data) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.workoutData = workoutData
    }
}
