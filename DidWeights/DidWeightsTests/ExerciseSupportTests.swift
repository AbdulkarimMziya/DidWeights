//
//  ExerciseSupportTests.swift
//  DidWeightsTests
//
//  Created by Abdulkarim Mziya on 2026-09-04.
//

import Foundation
import SwiftData
import Testing
@testable import DidWeights

// MARK: - ExerciseRepository

@MainActor
@Suite struct ExerciseRepositoryTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let sut: ExerciseRepository

    init() throws {
        let container = try ModelContainer.inMemory(seeded: false)
        let context = container.mainContext

        self.container = container
        self.context = context
        self.sut = ExerciseRepository(context: context)
    }

    @Test func findOrCreateInsertsNewExerciseWhenNoneExists() throws {
        let exercise = try sut.findOrCreate(name: "Bench Press")

        let allExercises = try context.fetch(FetchDescriptor<Exercise>())

        #expect(allExercises.count == 1)
        #expect(allExercises.first?.id == exercise.id)
        #expect(allExercises.first?.name == "Bench Press")
    }

    @Test func findOrCreateReturnsExistingExerciseOnExactMatch() throws {
        let first = try sut.findOrCreate(name: "Squat")
        let second = try sut.findOrCreate(name: "Squat")

        #expect(first.id == second.id)

        let allExercises = try context.fetch(FetchDescriptor<Exercise>())
        #expect(allExercises.count == 1)
    }

    @Test func findOrCreateIsCaseInsensitive() throws {
        let first = try sut.findOrCreate(name: "bench press")
        let second = try sut.findOrCreate(name: "Bench Press")

        #expect(first.id == second.id)

        let allExercises = try context.fetch(FetchDescriptor<Exercise>())
        #expect(allExercises.count == 1)
    }

    @Test func findOrCreateTrimsWhitespace() throws {
        let first = try sut.findOrCreate(name: "  Deadlift  ")
        let second = try sut.findOrCreate(name: "Deadlift")

        #expect(first.id == second.id)
        #expect(first.name == "Deadlift")

        let allExercises = try context.fetch(FetchDescriptor<Exercise>())
        #expect(allExercises.count == 1)
    }

    @Test func findOrCreateWithDifferentNamesInsertsSeparateExercises() throws {
        try sut.findOrCreate(name: "Bench Press")
        try sut.findOrCreate(name: "Squat")

        let allExercises = try context.fetch(FetchDescriptor<Exercise>())
        #expect(allExercises.count == 2)
    }

    @Test func renameUpdatesTheExerciseNameGlobally() throws {
        let exercise = try sut.findOrCreate(name: "Bench Press")

        try sut.rename(exercise, to: "Barbell Bench Press")

        #expect(exercise.name == "Barbell Bench Press")

        let allExercises = try context.fetch(FetchDescriptor<Exercise>())
        #expect(allExercises.count == 1)
        #expect(allExercises.first?.name == "Barbell Bench Press")
    }

    @Test func renameTrimsWhitespace() throws {
        let exercise = try sut.findOrCreate(name: "Squat")

        try sut.rename(exercise, to: "  Back Squat  ")

        #expect(exercise.name == "Back Squat")
    }

    @Test func deletingUnreferencedExerciseSucceeds() throws {
        let exercise = try sut.findOrCreate(name: "Bench Press")

        try sut.delete(exercise)
        try context.save()

        let allExercises = try context.fetch(FetchDescriptor<Exercise>())
        #expect(allExercises.isEmpty)
    }

    
}
