//
//  ExerciseRepository.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-09-04.
//


import Foundation
import SwiftData
 
@MainActor
struct ExerciseRepository {
    private let context: ModelContext
 
    init(context: ModelContext) {
        self.context = context
    }
 
    /// Case/whitespace-insensitive match on name. Two exercises named
    /// "bench press" and "Bench Press" are treated as the same exercise —
    /// this is the name-matching rule to defend in the M7 PR question.
    @discardableResult
    func findOrCreate(name: String, muscleGroup: String? = nil) throws -> Exercise {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
 
        let descriptor = FetchDescriptor<Exercise>()
        let allExercises = try context.fetch(descriptor)
 
        if let existing = allExercises.first(where: {
            $0.name.compare(normalized, options: .caseInsensitive) == .orderedSame
        }) {
            return existing
        }
 
        let newExercise = Exercise(name: normalized, muscleGroup: muscleGroup)
        context.insert(newExercise)
        return newExercise
    }
 
    func rename(_ exercise: Exercise, to name: String) throws {
        exercise.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
 
    func delete(_ exercise: Exercise) throws {
        // Exercise.sets has deleteRule: .deny (M2) — this will throw if any
        // ExerciseSet still references it, which is the correct behavior.
        context.delete(exercise)
    }
}
