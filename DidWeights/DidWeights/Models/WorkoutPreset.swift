//
//  WorkoutPreset.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-08-21.
//

import Foundation
import SwiftData

@Model
final class WorkoutPreset {
    var id: UUID
    var name: String
    var lastActive: Date?
    var defaultSetCount: Int

    var exercises: [Exercise]
    var exerciseOrder: [UUID]   // see Traps — this is not redundant

    init(name: String, defaultSetCount: Int = 3) {
        self.id = UUID()
        self.name = name
        self.lastActive = nil
        self.defaultSetCount = defaultSetCount
        self.exercises = []
        self.exerciseOrder = []
    }
}
