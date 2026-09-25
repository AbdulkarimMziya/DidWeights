//
//  RestTimerModelTests.swift
//  DidWeightsTests
//
//  RestTimerModel only imports Foundation — no ModelContainer.inMemory
//  needed here, unlike every repository suite in this file's neighbors.
//

import Foundation
import Testing
@testable import DidWeights

@Suite struct RestTimerModelTests {
    @Test func remainingCountsDownFromDuration() {
        let model = RestTimerModel()
        let start = Date(timeIntervalSince1970: 0)

        model.start(duration: 90, now: start)

        #expect(model.remaining(asOf: start) == 90)
        #expect(model.remaining(asOf: start.addingTimeInterval(30)) == 60)
    }

    @Test func remainingClampsAtZeroPastExpiry() {
        let model = RestTimerModel()
        let start = Date(timeIntervalSince1970: 0)

        model.start(duration: 30, now: start)

        #expect(model.remaining(asOf: start.addingTimeInterval(45)) == 0)
    }

    @Test func progressDrainsFromOneToZero() {
        let model = RestTimerModel()
        let start = Date(timeIntervalSince1970: 0)

        model.start(duration: 60, now: start)

        #expect(model.progress(asOf: start) == 1)
        #expect(model.progress(asOf: start.addingTimeInterval(30)) == 0.5)
        #expect(model.progress(asOf: start.addingTimeInterval(60)) == 0)
    }

    @Test func cancelReturnsToIdle() {
        let model = RestTimerModel()
        model.start(duration: 60)

        model.cancel()

        #expect(model.isRunning == false)
        #expect(model.remaining() == 0)
    }

    @Test func lastUsedDurationRemembersMostRecentStart() {
        let model = RestTimerModel()

        model.start(duration: 90)
        #expect(model.lastUsedDuration == 90)

        model.start(duration: 30)
        #expect(model.lastUsedDuration == 30)
    }
}
