//
//  WorkoutTimerView.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-08-01.
//

import SwiftData
import SwiftUI

struct WorkoutTimerView: View {
    let workout: Workout

    var body: some View {
        TimelineView(.periodic(from: workout.startDate, by: 1)) { context in
            Text(elapsedString(from: workout.elapsed(asOf: context.date)))
                .monospacedDigit()
        }
    }

    // Reshaped to take an already-computed TimeInterval instead of two
    // Dates — the subtraction now happens once, correctly, inside
    // Workout.elapsed(asOf:), which accounts for pausedAt/accumulatedPause.
    // This function's only job is formatting.
    private func elapsedString(from interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60

        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}

#Preview {
    let container = try! ModelContainer.inMemory(seeded: false)
    let workout = Workout(name: "Push Day", startDate: Date().addingTimeInterval(-125))
    container.mainContext.insert(workout)

    return WorkoutTimerView(workout: workout)
        .font(.title)
        .modelContainer(container)
}
