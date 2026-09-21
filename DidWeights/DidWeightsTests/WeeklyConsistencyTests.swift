//
//  WeeklyConsistencyTests.swift
//  DidWeightsTests
//
//  Created by Abdulkarim Mziya on 2026-09-21.
//

import Foundation
import Testing
@testable import DidWeights

@Suite struct WeeklyConsistencyTests {
    // Pinned so results don't depend on the region the test machine is set to.
    private let calendar: Calendar

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
    }

    // Reference week: Monday 21 Sep 2026 through Sunday 27 Sep 2026.
    // Sunday 20 Sep belongs to the week before.
    private func date(
        _ day: Int,
        month: Int = 9,
        hour: Int = 12,
        minute: Int = 0,
        calendar: Calendar? = nil
    ) throws -> Date {
        let calendar = calendar ?? self.calendar
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
        return try #require(components.date)
    }

    // MARK: - weekDays(containing:)

    @Test func returnsExactlySevenDays() throws {
        let days = try calendar.weekDays(containing: date(23))

        #expect(days.count == 7)
    }

    @Test func midWeekDateGivesMondayThroughSunday() throws {
        let days = try calendar.weekDays(containing: date(23))

        #expect(days.first == (try date(21, hour: 0)))
        #expect(days.last == (try date(27, hour: 0)))
    }

    @Test func daysAreConsecutive() throws {
        let days = try calendar.weekDays(containing: date(23))

        for (previous, next) in zip(days, days.dropFirst()) {
            let expected = try #require(calendar.date(byAdding: .day, value: 1, to: previous))
            #expect(next == expected)
        }
    }

    @Test func mondayMidnightStartsItsOwnWeek() throws {
        let days = try calendar.weekDays(containing: date(21, hour: 0))

        #expect(days.first == (try date(21, hour: 0)))
    }

    @Test func sundayLateEveningStaysInThatWeek() throws {
        let days = try calendar.weekDays(containing: date(27, hour: 23, minute: 59))

        #expect(days.first == (try date(21, hour: 0)))
        #expect(days.last == (try date(27, hour: 0)))
    }

    @Test func sundayBelongsToThePreviousMondaysWeek() throws {
        // Sunday 20 Sep is the last day of the week that started Monday 14 Sep.
        let days = try calendar.weekDays(containing: date(20))

        #expect(days.first == (try date(14, hour: 0)))
        #expect(days.last == (try date(20, hour: 0)))
    }

    @Test func everyDayIsAtMidnight() throws {
        let days = try calendar.weekDays(containing: date(23, hour: 17, minute: 45))

        for day in days {
            #expect(calendar.startOfDay(for: day) == day)
        }
    }

    @Test func weekStartsOnMondayEvenIfCalendarStartsOnSunday() throws {
        var sundayFirst = calendar
        sundayFirst.firstWeekday = 1

        let days = try sundayFirst.weekDays(containing: date(23))

        #expect(days.first == (try date(21, hour: 0)))
    }

    @Test func daylightSavingWeekStillHasSevenMidnightAlignedDays() throws {
        // US daylight saving started Sunday 8 Mar 2026, so that week has a 23-hour day.
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = try #require(TimeZone(identifier: "America/New_York"))

        let days = try newYork.weekDays(containing: date(4, month: 3, calendar: newYork))

        #expect(days.count == 7)
        #expect(days.first == (try date(2, month: 3, hour: 0, calendar: newYork)))
        #expect(days.last == (try date(8, month: 3, hour: 0, calendar: newYork)))
        for day in days {
            #expect(newYork.startOfDay(for: day) == day)
        }
    }

    // MARK: - dayStates(finishedWorkoutDates:now:calendar:)

    @Test func emptyWeekHasNoCompletedDaysAndOneToday() throws {
        let states = try WeeklyConsistency.dayStates(
            finishedWorkoutDates: [],
            now: date(23),
            calendar: calendar
        )

        #expect(states.count == 7)
        #expect(states.allSatisfy { !$0.isCompleted })
        #expect(states.filter(\.isToday).count == 1)
    }

    @Test func statesAreInMondayFirstOrder() throws {
        let states = try WeeklyConsistency.dayStates(
            finishedWorkoutDates: [],
            now: date(23),
            calendar: calendar
        )

        #expect(states.map(\.date) == states.map(\.date).sorted())
        #expect(states.first?.date == (try date(21, hour: 0)))
        #expect(states.last?.date == (try date(27, hour: 0)))
    }

    @Test func onlyDaysWithAWorkoutAreCompleted() throws {
        // Monday, Tuesday and Wednesday, with today being Thursday.
        let workouts = try [date(21), date(22), date(23)]

        let states = try WeeklyConsistency.dayStates(
            finishedWorkoutDates: workouts,
            now: date(24),
            calendar: calendar
        )

        #expect(states.map(\.isCompleted) == [true, true, true, false, false, false, false])
    }

    @Test func twoWorkoutsOnTheSameDayCountOnce() throws {
        let workouts = try [date(22, hour: 7), date(22, hour: 18)]

        let states = try WeeklyConsistency.dayStates(
            finishedWorkoutDates: workouts,
            now: date(24),
            calendar: calendar
        )

        #expect(states.filter(\.isCompleted).count == 1)
    }

    @Test func sundayNightAndMondayMorningAreDifferentDays() throws {
        // Sunday 20 Sep 23:59 is last week. Monday 21 Sep 00:01 is this week.
        let workouts = try [date(20, hour: 23, minute: 59), date(21, hour: 0, minute: 1)]

        let states = try WeeklyConsistency.dayStates(
            finishedWorkoutDates: workouts,
            now: date(23),
            calendar: calendar
        )

        #expect(states.filter(\.isCompleted).count == 1)
        #expect(states.first?.isCompleted == true)
    }

    @Test func workoutsFromOtherWeeksAreIgnored() throws {
        let workouts = try [date(20), date(28)]

        let states = try WeeklyConsistency.dayStates(
            finishedWorkoutDates: workouts,
            now: date(23),
            calendar: calendar
        )

        #expect(states.allSatisfy { !$0.isCompleted })
    }

    @Test func futureFlagOnlyMarksDaysAfterToday() throws {
        // Wednesday: Mon-Wed are not future, Thu-Sun are.
        let states = try WeeklyConsistency.dayStates(
            finishedWorkoutDates: [],
            now: date(23),
            calendar: calendar
        )

        #expect(states.map(\.isFuture) == [false, false, false, true, true, true, true])
    }

    @Test func todayIsNeverFutureEvenLateInTheDay() throws {
        let states = try WeeklyConsistency.dayStates(
            finishedWorkoutDates: [],
            now: date(23, hour: 23, minute: 59),
            calendar: calendar
        )

        let today = try #require(states.first { $0.isToday })
        #expect(today.isFuture == false)
        #expect(today.date == (try date(23, hour: 0)))
    }

    @Test func todayCanBeBothTodayAndCompleted() throws {
        let states = try WeeklyConsistency.dayStates(
            finishedWorkoutDates: [date(23, hour: 8)],
            now: date(23, hour: 20),
            calendar: calendar
        )

        let today = try #require(states.first { $0.isToday })
        #expect(today.isCompleted)
        #expect(today.isFuture == false)
    }

    @Test func missedPastDayIsDistinguishableFromUpcoming() throws {
        // Tuesday was missed; Friday is still to come. Both are not completed.
        let states = try WeeklyConsistency.dayStates(
            finishedWorkoutDates: [date(21)],
            now: date(23),
            calendar: calendar
        )

        let tuesday = states[1]
        let friday = states[4]
        #expect(!tuesday.isCompleted && !tuesday.isFuture && !tuesday.isToday)
        #expect(!friday.isCompleted && friday.isFuture && !friday.isToday)
    }
}
