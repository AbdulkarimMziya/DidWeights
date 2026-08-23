//
//  WorkoutPreset+Derived.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-08-21.
//

import Foundation

extension WorkoutPreset {
    var orderedExercises: [Exercise] {
        self.exerciseOrder.compactMap { id in
            exercises.first(where: {$0.id == id})
        }
    }
}
