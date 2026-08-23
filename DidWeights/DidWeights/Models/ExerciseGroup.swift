//
//  ExerciseGroup.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-08-21.
//

import Foundation

struct ExerciseGroup: Identifiable {
    let exercise: Exercise
    let sets: [ExerciseSet]
    var id: UUID { exercise.id }
}
