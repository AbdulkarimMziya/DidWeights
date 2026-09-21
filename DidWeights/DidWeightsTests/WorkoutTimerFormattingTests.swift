//
//  WorkoutTimerFormattingTests.swift
//  DidWeightsTests
//
//  Created by Abdulkarim Mziya on 2026-09-20.
//

import Foundation
import SwiftData
import Testing
@testable import DidWeights

@MainActor
@Suite struct WorkoutTimerFormattingTests {
    private let container: ModelContainer
    private let sut: WorkoutRepository

    init() throws {
        let container = try ModelContainer.inMemory(seeded: false)

        self.container = container
        self.sut = WorkoutRepository(context: container.mainContext)
    }

    @Test func zeroRendersAsDoubleZero() {
        #expect(WorkoutTimerView.elapsedString(from: 0) == "00:00")
    }

    @Test func subMinuteIntervalKeepsLeadingZeroMinutes() {
        #expect(WorkoutTimerView.elapsedString(from: 45) == "00:45")
    }

    @Test func exactMinuteRollsSecondsOver() {
        #expect(WorkoutTimerView.elapsedString(from: 60) == "01:00")
    }

    @Test func fractionalSecondsTruncateRatherThanRound() {
        #expect(WorkoutTimerView.elapsedString(from: 59.9) == "00:59")
    }

    @Test func justUnderAnHourStaysInMinutesAndSeconds() {
        #expect(WorkoutTimerView.elapsedString(from: 3_599) == "59:59")
    }

    @Test func oneHourSwitchesToHourMinuteSecond() {
        #expect(WorkoutTimerView.elapsedString(from: 3_600) == "1:00:00")
    }

    @Test func multiHourIntervalPadsMinutesAndSeconds() {
        // 2h 03m 07s
        #expect(WorkoutTimerView.elapsedString(from: 7_387) == "2:03:07")
    }

    @Test func negativeIntervalClampsToZero() {
        // A clock change can push `now` behind `startDate`; the readout should
        // sit at zero rather than render a negative duration.
        #expect(WorkoutTimerView.elapsedString(from: -30) == "00:00")
    }

    @Test func pausedWorkoutFreezesElapsedTime() throws {
        let start = Date(timeIntervalSinceNow: 0)
        let workout = try sut.startEmptyWorkout(named: "Push Day", at: start)

        try sut.pause(workout, at: start.addingTimeInterval(120))

        // Two observation points well past the pause must agree: the readout
        // is frozen, not merely slowed.
        let firstLook = workout.elapsed(asOf: start.addingTimeInterval(300))
        let secondLook = workout.elapsed(asOf: start.addingTimeInterval(900))

        #expect(abs(firstLook - 120) < 0.001)
        #expect(abs(secondLook - 120) < 0.001)
        #expect(WorkoutTimerView.elapsedString(from: secondLook) == "02:00")
    }
}
