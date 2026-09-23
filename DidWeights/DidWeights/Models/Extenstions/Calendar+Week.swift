//
//  Calendar+Week.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-09-21.
//
import Foundation

enum CalendarWeekError: Error {
    case weekIntervalUnavailable(Date)
}

extension Calendar {
    /// The Monday-start week containing `date`. The single place the week rule lives.
    func weekInterval(containing date: Date) throws -> DateInterval {
        var calendar = self
        calendar.firstWeekday = 2

        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            throw CalendarWeekError.weekIntervalUnavailable(date)
        }
        return interval
    }

    func weekDays(containing date: Date) throws -> [Date] {
        let interval = try weekInterval(containing: date)

        return try (0..<7).map { offset in
            guard let day = self.date(byAdding: .day, value: offset, to: interval.start) else {
                throw CalendarWeekError.weekIntervalUnavailable(date)
            }
            return day
        }
    }
}
