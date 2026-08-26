//
//  Exercise.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-08-21.
//

import Foundation
import SwiftData

@Model
final class Exercise: Hashable {
    var id: UUID
    var name: String
    var muscleGroup: String?
    var createdAt: Date

    @Relationship(deleteRule: .deny, inverse: \ExerciseSet.exercise)
    var sets: [ExerciseSet]

    init(name: String, muscleGroup: String? = nil) {
        self.id = UUID()
        self.name = name
        self.muscleGroup = muscleGroup
        self.createdAt = .now
        self.sets = []
    }
}
