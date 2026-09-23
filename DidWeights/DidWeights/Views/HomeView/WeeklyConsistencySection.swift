//
//  WeeklyConsistencySection.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-09-21.
//

import SwiftUI
import SwiftData

struct WeeklyConsistencySection: View {
    @Query private var workouts: [Workout]

    private let now: Date
    private let calendar: Calendar
    private let goal = 5

    // NOTE: `now` and the query range are fixed when this view is created,
    // so they go stale at midnight. Step 7 handles that.
    init(now: Date = .now, calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar

        // Can't fail for a Gregorian calendar, so a failure is a programmer error.
        let week: DateInterval

        do {
            week = try calendar.weekInterval(containing: now)
        } catch {
            preconditionFailure("Unable to determine the current week: \(error)")
        }

        let weekStart = week.start
        let weekEnd = week.end

        // Stored properties only: #Predicate can't call computed properties.
        _workouts = Query(
            filter: #Predicate<Workout> { workout in
                workout.endDate != nil
                    && workout.startDate >= weekStart
                    && workout.startDate < weekEnd
            },
            sort: \.startDate
        )
    }

    private var days: [DayState] {
        do {
            return try WeeklyConsistency.dayStates(
                // A workout counts toward the day it started.
                finishedWorkoutDates: workouts.map(\.startDate),
                now: now,
                calendar: calendar
            )
        } catch {
            preconditionFailure("Unable to build the week: \(error)")
        }
    }

    var body: some View {
        WeeklyConsistencyCard(
            days: days,
            goal: goal
        )
    }
}


#Preview {
    let container = try! ModelContainer.inMemory(seeded: false)

    // Finished workouts on the first and third days of the current week.
    let calendar = Calendar.current
    let monday = try! calendar.weekDays(containing: .now)[0]
    for offset in [0, 2] {
        let start = calendar.date(byAdding: .day, value: offset, to: monday)!
        let workout = Workout(name: "Preview", startDate: start)
        workout.endDate = start.addingTimeInterval(3600)
        container.mainContext.insert(workout)
    }

    return WeeklyConsistencySection()
        .modelContainer(container)
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(.neutral))
}
