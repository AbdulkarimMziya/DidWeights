//
//  Workout+ContextualName.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-09-08.
//

import Foundation

enum WorkoutTimeOfDay {
    case earlyMorning
    case morning
    case afternoon
    case evening

    init(hour: Int) {
        switch hour {
        case 6..<12:
            self = .morning
        case 12..<18:
            self = .afternoon
        case 18..<24:
            self = .evening
        default:
            self = .earlyMorning
        }
    }

    var workoutName: String {
        switch self {
        case .earlyMorning: "Early Morning Workout"
        case .morning: "Morning Workout"
        case .afternoon: "Afternoon Workout"
        case .evening: "Evening Workout"
        }
    }
}

extension Workout {
    static func contextualName(for date: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        return WorkoutTimeOfDay(hour: hour).workoutName
    }
}
