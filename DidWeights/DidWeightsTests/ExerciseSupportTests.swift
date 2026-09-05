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

// MARK: - ExerciseSet.isCompletable

@MainActor
@Suite struct ExerciseSetIsCompletableTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let workout: Workout
    private let exercise: Exercise

    init() throws {
        let container = try ModelContainer.inMemory(seeded: false)
        let context = container.mainContext

        let exercise = Exercise(name: "Bench Press")
        context.insert(exercise)

        let workout = Workout(name: "Push Day")
        context.insert(workout)

        self.container = container
        self.context = context
        self.workout = workout
        self.exercise = exercise
    }

    @Test func setWithPositiveRepsIsCompletable() throws {
        let set = ExerciseSet(order: 0, workout: workout, exercise: exercise)
        context.insert(set)

        set.reps = 10

        #expect(set.isCompletable == true)
    }

    @Test func setWithNilRepsIsNotCompletable() throws {
        let set = ExerciseSet(order: 0, workout: workout, exercise: exercise)
        context.insert(set)

        // reps is nil by default from ExerciseSet.init
        #expect(set.isCompletable == false)
    }

    @Test func setWithZeroRepsIsNotCompletable() throws {
        let set = ExerciseSet(order: 0, workout: workout, exercise: exercise)
        context.insert(set)

        set.reps = 0

        #expect(set.isCompletable == false)
    }

    @Test func setWithNegativeRepsIsNotCompletable() throws {
        let set = ExerciseSet(order: 0, workout: workout, exercise: exercise)
        context.insert(set)

        set.reps = -3

        #expect(set.isCompletable == false)
    }

    @Test func isCompletableIgnoresWeightEntirely() throws {
        // Proves bodyweight exercises (weight == nil) remain completable —
        // the exact case the old dead canBeCompleted extension got wrong.
        let set = ExerciseSet(order: 0, workout: workout, exercise: exercise)
        context.insert(set)

        set.reps = 10
        set.weight = nil

        #expect(set.isCompletable == true)
    }
}

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
