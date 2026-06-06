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
    
    @Attribute(.externalStorage)
    var workoutData: Data
    
    init(id: UUID = UUID(), name: String, workoutData: Data) {
        self.id = id
        self.name = name
        self.workoutData = workoutData
    }
}
