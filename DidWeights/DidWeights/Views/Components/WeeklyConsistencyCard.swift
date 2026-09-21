//
//  WeeklyConsistencyCard.swift
//  DidWeights
//
//  "This week's consistency" card: a completed-count pill and a row of seven
//  day circles. Purely presentational: every value comes in from the caller.
//

import SwiftUI

struct WeeklyConsistencyCard: View {
    let days: [DayState]
    let goal: Int

    private var completed: Int {
        days.filter(\.isCompleted).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .twoX) {
            header

            HStack(spacing: 0) {
                ForEach(days) { day in
                    DayColumn(day: day)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.twoX)
        .appCard()
    }

    private var header: some View {
        HStack(spacing: .oneX) {
            Text("THIS WEEK'S CONSISTENCY")
                .font(.appEyebrow)
                .tracking(0.8)
                .foregroundStyle(Color.metaText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: .oneX)

            Text("\(completed) of \(goal) completed")
                .font(.appCaption.weight(.semibold))
                .foregroundStyle(Color.accentText)
                .lineLimit(1)
                .padding(.horizontal, .oneAndAHalfX)
                .padding(.vertical, .halfX + .quarterX)
                .background(Color.accentSoft, in: Capsule())
        }
    }
}

// MARK: - Day column

private struct DayColumn: View {
    let day: DayState

    var body: some View {
        VStack(spacing: .oneAndAHalfX) {
            Text(day.date.formatted(.dateTime.weekday(.narrow)))
                .font(.appMicro.weight(day.isToday ? .bold : .medium))
                .foregroundStyle(day.isToday ? Color.primaryHeadingTxt : Color.metaText)

            DayCircle(day: day)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide)))
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        var parts: [String] = []
        if day.isToday { parts.append("Today") }
        if day.isCompleted {
            parts.append("Completed")
        } else if day.isFuture {
            parts.append("Upcoming")
        } else if !day.isToday {
            parts.append("Missed")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Day circle

private struct DayCircle: View {
    let day: DayState

    private let size: CGFloat = .fourX

    var body: some View {
        ZStack {
            if day.isToday {
                // Halo behind today, whether or not it's done yet.
                Circle()
                    .fill(Color.accentSoft)
                    .frame(width: size + .oneX, height: size + .oneX)
            }

            if day.isCompleted {
                Circle().fill(Color.primary)
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.checkmarkIcon)
            } else if day.isToday {
                Circle().fill(Color.cardBg)
                Circle().strokeBorder(Color.primary, lineWidth: .quarterX)
                Circle()
                    .fill(Color.primary)
                    .frame(width: .halfX + .quarterX, height: .halfX + .quarterX)
            } else if day.isFuture {
                Circle().fill(Color.tileBG)
                Circle()
                    .fill(Color.metaText.opacity(0.6))
                    .frame(width: .halfX + .quarterX, height: .halfX + .quarterX)
            } else {
                // Missed past day. Not in the mock, so this look is a placeholder.
                Circle().fill(Color.tileBG)
                Capsule()
                    .fill(Color.metaText.opacity(0.6))
                    .frame(width: .oneAndAHalfX, height: .quarterX)
            }
        }
        .frame(width: size, height: size)
        // Reserve room for today's halo so all columns stay aligned.
        .padding(.halfX)
    }
}

// MARK: - Previews

private extension Array where Element == DayState {
    /// A week for previews only. `todayIndex` 0 = Monday.
    static func previewWeek(completed: Set<Int>, todayIndex: Int) -> [DayState] {
        let dates = try! Calendar.current.weekDays(containing: .now)
        return dates.enumerated().map { index, date in
            DayState(
                date: date,
                isToday: index == todayIndex,
                isCompleted: completed.contains(index),
                isFuture: index > todayIndex
            )
        }
    }
}

#Preview("Mid-week") {
    WeeklyConsistencyCard(
        days: .previewWeek(completed: [0, 1, 2], todayIndex: 3),
        goal: 5
    )
    .padding()
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Color.appBg)
}

#Preview("Today done, one missed") {
    WeeklyConsistencyCard(
        days: .previewWeek(completed: [0, 2, 3], todayIndex: 3),
        goal: 5
    )
    .padding()
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Color.appBg)
}

#Preview("Dark") {
    WeeklyConsistencyCard(
        days: .previewWeek(completed: [0, 1, 2], todayIndex: 3),
        goal: 5
    )
    .padding()
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Color.appBg)
    .preferredColorScheme(.dark)
}
