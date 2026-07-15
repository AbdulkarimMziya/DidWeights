//
//  SavedWorkout.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-06-06.
//

import Foundation
import SwiftData

@Model
class SavedWorkout: Identifiable, Hashable {
    @Attribute(.unique)
    var id = UUID()
    
    var name: String
    var lastActive: Date?
    
    @Attribute(.externalStorage)
    var workoutData: Data
    
    init(id: UUID = UUID(), name: String, lastActive: Date? = nil, workoutData: Data) {
        self.id = id
        self.name = name
        self.lastActive = lastActive
        self.workoutData = workoutData
    }
}
