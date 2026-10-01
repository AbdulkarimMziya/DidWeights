//
//  WeeklyConsistency.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-09-21.
//

import Foundation

struct DayState: Identifiable, Equatable {
    let date: Date
    let isToday: Bool
    let isCompleted: Bool
    let isFuture: Bool
    
    var id: Date {
        date
    }
}


struct WeeklyConsistency {

    // The weekly workout-days target is a device preference (Settings owns
    // the control), not workout data — @AppStorage, keyed here so Settings
    // and WeeklyConsistencySection can't disagree about the key or default.
    static let goalStorageKey = "weeklyTarget.goalDays"
    static let defaultGoal = 5
    static let goalOptions = [3, 4, 5, 6, 7]

    static func dayStates(finishedWorkoutDates: [Date], now: Date, calendar: Calendar) throws -> [DayState] {
        
        let days = try calendar.weekDays(containing: now)
        let today = calendar.startOfDay(for: now)
        
        return days.map { day in
            let isToday = calendar.isDate(day, inSameDayAs: now)
            
            let isCompleted = finishedWorkoutDates.contains {
                calendar.isDate($0, inSameDayAs: day)
            }
            
            let isFuture = day > today
            
            return DayState(
                date: day,
                isToday: isToday,
                isCompleted: isCompleted,
                isFuture: isFuture
            )
        }
    }
    
}


