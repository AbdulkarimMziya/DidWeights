//
//  RestTimerBar.swift
//  DidWeights
//
//  The nav-bar `.principal` countdown, visible only while a timer is
//  running. Tapping it cancels the timer.
//

import AudioToolbox
import SwiftUI
import UIKit

struct RestTimerBar: View {
    let timer: RestTimerModel

    var body: some View {
        if timer.isRunning {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = timer.remaining(asOf: context.date)
                let progress = timer.progress(asOf: context.date)

                Button {
                    timer.cancel()
                } label: {
                    HStack(spacing: .halfX) {
                        RestTimerProgressCapsule(progress: progress)
                            .frame(width: 60, height: 6)
                        Text(Self.remainingString(from: remaining))
                            .font(.appCaption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.primaryHeadingTxt)
                    }
                }
                .buttonStyle(.plain)
                // Auto-clears at zero and pairs a haptic + sound cue.
                .onChange(of: remaining <= 0) { _, expired in
                    if expired {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        AudioServicesPlaySystemSound(1057)
                        timer.cancel()
                    }
                }
                // A light pre-warning tap at 10 seconds left.
                .onChange(of: Int(remaining)) { _, secondsLeft in
                    if secondsLeft == 10 {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
            .accessibilityLabel("Rest timer, \(Self.remainingString(from: timer.remaining())) remaining. Tap to skip.")
        }
    }

    static func remainingString(from interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

/// Same proportional-width technique as HomeView's private ProgressBar.
private struct RestTimerProgressCapsule: View {
    let progress: Double

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color(.tertiary))
            GeometryReader { proxy in
                Capsule()
                    .fill(Color("Primary"))
                    .frame(width: proxy.size.width * progress)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    let model = RestTimerModel()
    model.start(duration: 90)
    return RestTimerBar(timer: model)
}
