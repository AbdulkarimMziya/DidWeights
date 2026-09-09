//
//  WorkoutNamingTests.swift
//  DidWeightsTests
//
//  Created by Abdulkarim Mziya on 2026-09-08.
//

import Foundation
import SwiftData
import Testing
@testable import DidWeights

@MainActor
@Suite struct WorkoutNamingTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let sut: WorkoutRepository

    // Pinned so the boundary-hour expectations don't depend on the region
    // the test machine happens to be configured for.
    private let calendar: Calendar

    init() throws {
        let container = try ModelContainer.inMemory(seeded: false)
        let context = container.mainContext

        self.container = container
        self.context = context
        self.sut = WorkoutRepository(context: context)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
    }

    private func date(atHour hour: Int) throws -> Date {
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 3,
            day: 14,
            hour: hour,
            minute: 30
        )

        return try #require(components.date)
    }

    /// The repository resolves names through `Calendar.current`, so tests that go
    /// through it have to build their start dates in that same calendar.
    private func localDate(atHour hour: Int) throws -> Date {
        let components = DateComponents(year: 2026, month: 3, day: 14, hour: hour, minute: 30)

        return try #require(Calendar.current.date(from: components))
    }

    @Test(arguments: [
        (0, "Early Morning Workout"),
        (5, "Early Morning Workout"),
        (6, "Morning Workout"),
        (11, "Morning Workout"),
        (12, "Afternoon Workout"),
        (17, "Afternoon Workout"),
        (18, "Evening Workout"),
        (23, "Evening Workout"),
    ])
    func contextualNameMatchesTimeOfDay(hour: Int, expectedName: String) throws {
        let startDate = try date(atHour: hour)

        #expect(Workout.contextualName(for: startDate, calendar: calendar) == expectedName)
    }

    @Test func startingEmptyWorkoutWithoutNameUsesContextualName() throws {
        let startDate = try localDate(atHour: 19)

        let workout = try sut.startEmptyWorkout(at: startDate)

        #expect(workout.name == "Evening Workout")
    }

    @Test func startingEmptyWorkoutWithExplicitNameOverridesContextualName() throws {
        let startDate = try localDate(atHour: 19)

        let workout = try sut.startEmptyWorkout(named: "Pull Day", at: startDate)

        #expect(workout.name == "Pull Day")
    }

    @Test func startingWorkoutFromPresetKeepsPresetName() throws {
        let squat = Exercise(name: "Barbell Squat")
        context.insert(squat)

        let preset = WorkoutPreset(name: "Leg Day", defaultSetCount: 2)
        context.insert(preset)

        preset.exercises = [squat]
        preset.exerciseOrder = [squat.id]

        let workout = try sut.startWorkout(from: preset, at: try localDate(atHour: 19))

        #expect(workout.name == "Leg Day")
    }
}
