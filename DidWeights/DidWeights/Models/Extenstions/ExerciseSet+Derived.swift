//
//  ExerciseSet+Derived.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-09-04.
//


extension ExerciseSet {
    var isCompletable: Bool {
        (reps ?? 0) > 0
    }
}
