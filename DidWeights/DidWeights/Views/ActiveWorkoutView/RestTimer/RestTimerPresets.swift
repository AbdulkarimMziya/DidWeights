//
//  RestTimerPresets.swift
//  DidWeights
//
//  Fixed rest durations for the quick-select pills.
//

import Foundation

enum RestTimerPreset: CaseIterable, Identifiable {
    case thirtySeconds
    case sixtySeconds
    case ninetySeconds
    case twoMinutes

    var id: Self { self }

    var duration: TimeInterval {
        switch self {
        case .thirtySeconds: 30
        case .sixtySeconds: 60
        case .ninetySeconds: 90
        case .twoMinutes: 120
        }
    }

    var label: String {
        switch self {
        case .thirtySeconds: "30s"
        case .sixtySeconds: "60s"
        case .ninetySeconds: "90s"
        case .twoMinutes: "2m"
        }
    }
}
