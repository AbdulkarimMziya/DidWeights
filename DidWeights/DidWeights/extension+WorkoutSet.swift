//
//  extension+WorkoutSet.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-06-15.
//

import Foundation

extension WorkoutSet {
    
    var canBeCompleted: Bool {
        (reps ?? 0) > 0 && (weight ?? 0) > 0
    }
}
