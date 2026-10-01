//
//  WeightUnit.swift
//  DidWeights
//
//  The app's canonical weight storage unit is always kilograms — see
//  `ExerciseSet.weight`. This is the single place kg<->lb conversion happens,
//  so every view that displays or accepts a weight converts through here
//  rather than repeating the constant. Conversion is display-layer only:
//  it never touches the repository or the stored value.
//

import Foundation

enum WeightUnit: String, CaseIterable, Identifiable {
    case kilograms
    case pounds

    var id: String { rawValue }

    /// Shared `@AppStorage` key. Every read/write site uses this constant,
    /// never a repeated string literal, so a typo can't silently split the
    /// preference into two.
    static let storageKey = "measurementUnits.weight"

    // Not bit-exact (the real factor is 2.2046226218...), which is fine —
    // gym weights are never entered to a precision where that matters, and
    // display formatting rounds anyway. Keep the conversion pure, unrounded
    // math; round only at the point a value is formatted for display.
    private static let poundsPerKilogram: Double = 2.20462

    var abbreviation: String {
        switch self {
        case .kilograms: "kg"
        case .pounds: "lbs"
        }
    }

    /// Canonical storage unit (kg) -> this unit, for reading/displaying.
    func fromKilograms(_ kilograms: Double) -> Double {
        switch self {
        case .kilograms: kilograms
        case .pounds: kilograms * Self.poundsPerKilogram
        }
    }

    /// This unit (as typed/shown) -> canonical storage unit (kg), before the
    /// value is ever written to a model or passed to a repository.
    func toKilograms(_ value: Double) -> Double {
        switch self {
        case .kilograms: value
        case .pounds: value / Self.poundsPerKilogram
        }
    }

    /// Single fallback point for a raw `@AppStorage` string, so every call
    /// site resolves an invalid/missing value the same way. Defaults to
    /// `.pounds` — the app has only ever shown "lb"/"LBS", so that's the
    /// unit existing users already expect their typed numbers to mean.
    static func resolved(from rawValue: String) -> WeightUnit {
        WeightUnit(rawValue: rawValue) ?? .pounds
    }
}
