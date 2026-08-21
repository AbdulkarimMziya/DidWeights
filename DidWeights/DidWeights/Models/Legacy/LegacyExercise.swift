//
//  Exercise.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-06-06.
//

import Foundation
import SwiftData

@Model
class LegacyExercise: Identifiable, Hashable {
    
    @Attribute(.unique)
    var id = UUID()
    
    var name: String
    var muscleGroup: String
    
    init(name: String, muscleGroup: String) {
        self.name = name
        self.muscleGroup = muscleGroup
    }
}
