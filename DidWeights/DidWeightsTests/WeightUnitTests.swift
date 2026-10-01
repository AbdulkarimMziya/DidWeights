//
//  WeightUnitTests.swift
//  DidWeightsTests
//

import Testing
@testable import DidWeights

@Suite struct WeightUnitTests {
    // MARK: - Kilograms is identity

    @Test func kilogramsFromKilogramsIsUnchanged() {
        #expect(WeightUnit.kilograms.fromKilograms(100) == 100)
    }

    @Test func kilogramsToKilogramsIsUnchanged() {
        #expect(WeightUnit.kilograms.toKilograms(100) == 100)
    }

    // MARK: - Pounds conversion

    @Test func fromKilogramsToPoundsMatchesKnownValue() {
        // 100 kg is ~220.462 lb.
        let pounds = WeightUnit.pounds.fromKilograms(100)
        #expect(abs(pounds - 220.462) < 0.001)
    }

    @Test func toKilogramsFromPoundsMatchesKnownValue() {
        // 220.462 lb is ~100 kg.
        let kilograms = WeightUnit.pounds.toKilograms(220.462)
        #expect(abs(kilograms - 100) < 0.001)
    }

    @Test func poundsRoundTripStaysWithinEpsilon() {
        let original = 135.0
        let roundTripped = WeightUnit.pounds.toKilograms(WeightUnit.pounds.fromKilograms(original))
        #expect(abs(roundTripped - original) < 0.0001)
    }

    @Test func kilogramsRoundTripIsExact() {
        let original = 62.5
        let roundTripped = WeightUnit.kilograms.toKilograms(WeightUnit.kilograms.fromKilograms(original))
        #expect(roundTripped == original)
    }

    // MARK: - resolved(from:)

    @Test func resolvedReadsAValidRawValue() {
        #expect(WeightUnit.resolved(from: "kilograms") == .kilograms)
        #expect(WeightUnit.resolved(from: "pounds") == .pounds)
    }

    @Test func resolvedFallsBackToPoundsForGarbageInput() {
        #expect(WeightUnit.resolved(from: "") == .pounds)
        #expect(WeightUnit.resolved(from: "lb") == .pounds)
        #expect(WeightUnit.resolved(from: "not a unit") == .pounds)
    }
}
