//
//  WorkoutTimerView.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-08-01.
//

import SwiftUI

struct WorkoutTimerView: View {
    let startDate: Date
    
    var body: some View {
        TimelineView(.periodic(from: startDate, by: 1)) { context in
            Text(elapsedString(from: startDate, to: context.date))
                    .monospacedDigit()
        }
    }
    
    private func elapsedString(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
    
}

#Preview {
    WorkoutTimerView(startDate: Date().addingTimeInterval(-125))
        .font(.title)
}
